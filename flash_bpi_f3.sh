#!/bin/bash
#
# Flash script for BananaPi BPI-F3 (Spacemit K1) - Android
#
# Place all required files in the same directory as this script, then run it.
#
# Usage:
#   ./flash_bpi_f3.sh                Flash all via fastboot (bootloader + android)
#   ./flash_bpi_f3.sh --bootloader   Flash bootloader only
#   ./flash_bpi_f3.sh --android      Flash Android images only
#   ./flash_bpi_f3.sh --dfu          Full DFU flash (board in BROM mode)
#   ./flash_bpi_f3.sh --wipe         Include userdata wipe (combines with any mode)
#
# For fastboot modes, start "fastboot usb 0" on the U-Boot console first.
# For DFU mode, the board must be in BROM DFU mode (USB 361c:1001).
#
set -euo pipefail

# ============================================================================
# Configuration — all files relative to script directory
# ============================================================================
IMG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bootloader dir for the selected board (overridden by --board). The Android
# images (boot/super/vendor_boot/vbmeta) are shared: vendor_boot carries a
# multi-DTB dtb.img (both k1-bananapi-f3 and k1-musepi-pro) and U-Boot selects
# the matching one at boot — so only the bootloader location is per-board.
BL="${IMG}"

# Target board (set in main): bananapi (boots eMMC) | musepi-pro (boots SPI-NOR).
# On the MusePi Pro the bootloader must live in SPI-NOR (the K1 boot strap is
# NOR there); Android still goes to eMMC.
BOARD="bananapi"

# Fastboot binary
FASTBOOT=$(command -v fastboot 2>/dev/null || true)

# ============================================================================
# Colors
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { err "$*"; exit 1; }

# ============================================================================
# Check fastboot
# ============================================================================
require_fastboot() {
    [ -n "${FASTBOOT}" ] && [ -x "${FASTBOOT}" ] || die "fastboot not found in PATH"
}

# ============================================================================
# Wait for fastboot device
# ============================================================================
wait_for_device() {
    local timeout="${1:-30}"
    local description="${2:-fastboot device}"
    local elapsed=0

    info "Waiting for ${description} (${timeout}s)..."
    while [ ${elapsed} -lt ${timeout} ]; do
        if ${FASTBOOT} devices 2>/dev/null | grep -q -E "fastboot|Fastboot|DFU|dfu|download"; then
            ok "Device detected"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    die "Timeout waiting for ${description}"
}

# ============================================================================
# Check required files
# ============================================================================
check_files() {
    local missing=false
    for f in "$@"; do
        if [ ! -f "${IMG}/${f}" ]; then
            err "Missing: ${IMG}/${f}"
            missing=true
        fi
    done
    if [ "${missing}" = true ]; then
        die "Required files missing. Place them next to this script."
    fi
}

# ============================================================================
# DFU staging: BROM -> FSBL -> U-Boot
# ============================================================================
dfu_stage() {
    info "Step 1: Staging FSBL into BROM..."
    wait_for_device 10 "DFU device (361c:1001)"
    ${FASTBOOT} stage "${BL}/factory/FSBL.bin"
    ${FASTBOOT} continue
    info "BROM executing FSBL..."
    sleep 5

    info "Step 2: Staging U-Boot into SPL..."
    wait_for_device 30 "SPL fastboot"
    ${FASTBOOT} stage "${BL}/u-boot.itb"
    ${FASTBOOT} continue
    info "SPL executing U-Boot..."
    sleep 5

    info "Step 3: Connecting to U-Boot fastboot..."
    wait_for_device 30 "U-Boot fastboot"
}

# ============================================================================
# Flash bootloader partitions
# ============================================================================
flash_bootloader() {
    info "Flashing bootloader partitions (${BL})..."
    [ -f "${BL}/factory/bootinfo_emmc.bin" ] && ${FASTBOOT} flash bootinfo "${BL}/factory/bootinfo_emmc.bin"
    ${FASTBOOT} flash fsbl "${BL}/factory/FSBL.bin"
    ${FASTBOOT} flash env "${BL}/env.bin"
    ${FASTBOOT} flash opensbi "${BL}/fw_dynamic.itb"
    ${FASTBOOT} flash uboot "${BL}/u-boot.itb"
    ok "Bootloader flashed"
}

# ============================================================================
# Flash bootloader to SPI-NOR (MUSE-Pi-Pro boots from NOR, not eMMC)
# Writes the MTD layout (partition_nor.json) then the bootloader blobs.
# Android is flashed to eMMC separately. Must run while only the NOR MTD
# table is active (before the eMMC Android GPT) so partition names resolve
# unambiguously to NOR.
# ============================================================================
flash_bootloader_nor() {
    info "Flashing bootloader to SPI-NOR (${BL})..."
    # "flash mtd" (not "gpt") sets the K1 fastboot routing to the MTD/NOR
    # device (flash() toggles on the literal "mtd"/"gpt" arg). It parses the
    # mtd table; the subsequent named partitions then resolve to NOR.
    ${FASTBOOT} flash mtd "${BL}/partition_nor.json"
    ${FASTBOOT} flash bootinfo "${BL}/factory/bootinfo_spinor.bin"
    ${FASTBOOT} flash fsbl "${BL}/factory/FSBL.bin"
    ${FASTBOOT} flash env "${BL}/env.bin"
    ${FASTBOOT} flash opensbi "${BL}/fw_dynamic.itb"
    ${FASTBOOT} flash uboot "${BL}/u-boot.itb"
    ok "Bootloader flashed to SPI-NOR"
}

# ============================================================================
# Flash Android boot partitions (both slots a and b)
# ============================================================================
flash_android_boot() {
    info "Flashing Android boot images (slots a + b)..."

    # Flash all vbmeta images (required for AVB)
    local vbmeta_images="vbmeta vbmeta_vendor_dlkm vbmeta_system_dlkm"
    for vbmeta in ${vbmeta_images}; do
        if [ -f "${IMG}/${vbmeta}.img" ]; then
            info "Flashing ${vbmeta}..."
            for slot in a b; do
                if [ "${DISABLE_AVB}" = "true" ]; then
                    ${FASTBOOT} --disable-verity --disable-verification flash "${vbmeta}_${slot}" "${IMG}/${vbmeta}.img"
                else
                    ${FASTBOOT} flash "${vbmeta}_${slot}" "${IMG}/${vbmeta}.img"
                fi
            done
        else
            warn "${vbmeta}.img not found"
        fi
    done
    ok "vbmeta images flashed"

    for slot in a b; do
        if [ -f "${IMG}/boot.img" ]; then
            ${FASTBOOT} flash "boot_${slot}" "${IMG}/boot.img"
        fi
        if [ -f "${IMG}/init_boot.img" ]; then
            ${FASTBOOT} flash "init_boot_${slot}" "${IMG}/init_boot.img"
        fi
        if [ -f "${IMG}/vendor_boot.img" ]; then
            ${FASTBOOT} flash "vendor_boot_${slot}" "${IMG}/vendor_boot.img"
        fi
        if [ -f "${IMG}/dtbo.img" ]; then
            ${FASTBOOT} flash "dtbo_${slot}" "${IMG}/dtbo.img"
        fi
    done
    # Reset A/B metadata and set slot a as active
    ${FASTBOOT} erase misc
    ${FASTBOOT} set_active a 2>/dev/null || warn "set_active not supported, slot may need manual selection"
    ok "Boot images flashed (both slots)"
}

# ============================================================================
# Flash super partition
# ============================================================================
flash_super() {
    info "Flashing super (system+vendor)... this takes a while"
    ${FASTBOOT} flash super "${IMG}/super.img"
    ok "Super flashed"
}

# ============================================================================
# Flash userdata
# ============================================================================
flash_userdata() {
    info "Flashing userdata..."
    ${FASTBOOT} flash userdata "${IMG}/userdata.img"
    # The K1 U-Boot fastboot 'format' can't resolve some partitions on certain
    # boards ("incorrect device type / cannot find partition") even though
    # 'flash' works via its mmc fallback. metadata/persist are formatted by
    # Android (vold/init) on first boot anyway, so don't let this abort the flash.
    info "Formatting metadata (f2fs)..."
    ${FASTBOOT} format:f2fs metadata || warn "metadata format unsupported by U-Boot fastboot; Android will format it on first boot"
    info "Formatting persist (ext4)..."
    ${FASTBOOT} format:ext4 persist || warn "persist format unsupported by U-Boot fastboot; Android will format it on first boot"
    ok "Userdata flashed (metadata/persist deferred to first boot if format is unsupported)"
}

# ============================================================================
# Mode: full — flash everything via fastboot (default)
# ============================================================================
mode_all() {
    local wipe="$1"

    require_fastboot
    check_files factory/FSBL.bin fw_dynamic.itb u-boot.itb env.bin boot.img super.img vbmeta.img

    echo ""
    echo -e "${BOLD}=== Full fastboot flash ===${NC}"
    echo -e " Run ${YELLOW}fastboot usb 0${NC} on U-Boot console first"
    echo ""

    wait_for_device 30 "U-Boot fastboot (run 'fastboot usb 0' on board)"
    if [ "${BOARD}" = "musepi-pro" ]; then
        flash_bootloader_nor
    else
        flash_bootloader
    fi
    flash_android_boot
    flash_super

    if [ "${wipe}" = "false" ]; then
        info "Skipping userdata (use --wipe for clean install)"
    fi
    # Always flash userdata during development
    flash_userdata

    echo ""
    ok "Flash complete! Rebooting..."
    ${FASTBOOT} reboot 2>/dev/null || warn "Auto-reboot failed, power cycle manually"
}

# ============================================================================
# Mode: --bootloader
# ============================================================================
mode_bootloader() {
    local wipe="$1"

    require_fastboot
    check_files factory/FSBL.bin fw_dynamic.itb u-boot.itb env.bin

    echo ""
    echo -e "${BOLD}=== Bootloader flash (fastboot) ===${NC}"
    echo -e " Run ${YELLOW}fastboot usb 0${NC} on U-Boot console first"
    echo ""

    wait_for_device 15 "U-Boot fastboot (run 'fastboot usb 0' on board)"
    if [ "${BOARD}" = "musepi-pro" ]; then
        flash_bootloader_nor
    else
        flash_bootloader
    fi

    echo ""
    ok "Done! Reboot the board to use new bootloader."
    ${FASTBOOT} reboot 2>/dev/null || warn "Auto-reboot failed, power cycle manually"
}

# ============================================================================
# Mode: --android
# ============================================================================
mode_android() {
    local wipe="$1"

    require_fastboot
    check_files boot.img

    echo ""
    echo -e "${BOLD}=== Android flash (fastboot) ===${NC}"
    echo -e " Run ${YELLOW}fastboot usb 0${NC} on U-Boot console first"
    echo ""

    wait_for_device 15 "U-Boot fastboot (run 'fastboot usb 0' on board)"
    flash_android_boot

    if [ -f "${IMG}/super.img" ]; then
        flash_super
    else
        warn "super.img not found, skipping"
    fi

    # Always flash userdata during development
    flash_userdata

    echo ""
    ok "Done! Rebooting..."
    ${FASTBOOT} reboot 2>/dev/null || warn "Auto-reboot failed, power cycle manually"
}

# ============================================================================
# Mode: --dfu (full DFU from BROM)
# ============================================================================
mode_dfu() {
    local wipe="$1"

    require_fastboot
    check_files u-boot.itb fw_dynamic.itb env.bin factory/FSBL.bin \
                boot.img super.img partition_android.json vbmeta.img

    echo ""
    echo -e "${BOLD}=== Full DFU flash ===${NC}"
    echo -e " Board must be in ${YELLOW}DFU mode${NC} (USB ID 361c:1001)"
    echo ""

    # DFU staging: BROM -> FSBL -> U-Boot
    dfu_stage

    # Bootloader + partition tables (boot media differs per board)
    if [ "${BOARD}" = "musepi-pro" ]; then
        # Pro boots from SPI-NOR: bootloader -> NOR first, then Android -> eMMC
        flash_bootloader_nor
        info "Writing Android GPT (eMMC)..."
        ${FASTBOOT} flash gpt "${BL}/partition_android.json"
        ok "Android GPT written"
    else
        info "Writing GPT partition table..."
        ${FASTBOOT} flash gpt "${BL}/partition_android.json"
        ok "GPT written"
        flash_bootloader
    fi
    flash_android_boot
    flash_super

    # Always flash userdata during development
    flash_userdata

    echo ""
    ok "Flash complete! Rebooting..."
    ${FASTBOOT} reboot || warn "Reboot failed, power cycle manually"
}

# ============================================================================
# Main
# ============================================================================
usage() {
    cat <<'EOF'
Usage: flash_bpi_f3.sh [MODE] [OPTIONS]

All image files must be in the same directory as this script.
For fastboot modes, run "fastboot usb 0" on the U-Boot console first.

Modes:
  (default)       Flash bootloader + Android via fastboot
  --bootloader    Flash bootloader only via fastboot
  --android       Flash Android images only via fastboot
  --dfu           Full DFU flash (board in BROM mode, first-time setup)

Options:
  --board <name>  Target board: bananapi (default) | musepi-pro
  --wipe          Also flash userdata (clean install)
  --no-avb        Disable AVB verification (for bringup/development)
  --help          Show this help

Examples:
  ./flash_bpi_f3.sh                       # Flash everything (BananaPi F3)
  ./flash_bpi_f3.sh --board musepi-pro    # Flash everything (MusePi Pro)
  ./flash_bpi_f3.sh --android             # Flash only Android images
  ./flash_bpi_f3.sh --dfu --wipe          # First-time DFU setup with clean userdata
EOF
}

main() {
    local mode="all"
    local do_wipe=false
    local board="bananapi"
    DISABLE_AVB=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --bootloader)    mode="bootloader"; shift ;;
            --android)       mode="android"; shift ;;
            --dfu)           mode="dfu"; shift ;;
            --wipe)          do_wipe=true; shift ;;
            --no-avb)        DISABLE_AVB=true; shift ;;
            --board)         board="$2"; shift 2 ;;
            --help|-h)       usage; exit 0 ;;
            *) die "Unknown option: $1 (see --help)" ;;
        esac
    done

    # Select the per-board bootloader dir (Android images are shared: the
    # multi-DTB vendor_boot lets U-Boot pick the right board DTB at runtime).
    case "${board}" in
        bananapi|bpi-f3|k1) BL="${IMG}"; BOARD="bananapi" ;;
        musepi-pro|musepi)
            BL="${IMG}/musepi-pro"; BOARD="musepi-pro"
            [ -f "${BL}/u-boot.itb" ] || die "MusePi Pro bootloader not found at ${BL}. Build it first: in the bootloaders/ tree run './build-bootloaders/release_android.sh --aosp=<aosp>' (no --config), then rebuild AOSP." ;;
        *) die "Unknown board: ${board} (use: bananapi | musepi-pro)" ;;
    esac

    echo ""
    echo "============================================"
    echo " SpacemiT K1 (RISC-V) - Android Flash Tool"
    echo " Board: ${board}"
    echo "============================================"
    echo " Android images: ${IMG}"
    echo " Bootloader:     ${BL}"
    echo ""

    case "${mode}" in
        bootloader) mode_bootloader "${do_wipe}" ;;
        android)    mode_android "${do_wipe}" ;;
        dfu)        mode_dfu "${do_wipe}" ;;
        all)        mode_all "${do_wipe}" ;;
    esac
}

main "$@"
