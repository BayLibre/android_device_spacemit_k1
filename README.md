# SpacemiT K1 (RISC-V) — Android device support

This directory is the AOSP device config for the **SpacemiT K1** SoC (8× X60,
`rv64gcv`, riscv64). It supports **two boards** built from the same `k1` device:

| Board | `model` / `compatible` | Bootloader media | Android media |
|---|---|---|---|
| **BananaPi BPI-F3** (Sinovoip) | `Banana Pi BPI-F3` / `bananapi,bpi-f3`, `spacemit,k1` | eMMC | eMMC |
| **MusePi Pro** (SpacemiT) | `SpacemiT MusePi Pro` / `spacemit,musepi-pro`, `spacemit,k1` | **SPI-NOR** | eMMC |

Both boards run the same Android build and the same kernel `Image`; only the
**bootloader location** and the **device tree** differ. The shared Android
images (`boot`/`vendor_boot`/`super`/`vbmeta`) carry a **multi-DTB `dtb.img`**
with both board DTBs, and U-Boot picks the right one at boot via the `adtb_idx`
env var (see below).

## One device, two products

The device is `k1`; the lunch products live in `bananapi_f3/`:

- `aosp_bananapi_f3` / `aosp_bananapi_f3_tablet`

There is **no separate MusePi Pro product**. The MusePi Pro boots the same
`aosp_bananapi_f3*` images — the board is distinguished at boot by U-Boot's
`product_name`, which selects the DTB (see below), not by a build variant.
(`PRODUCT_MODEL` therefore still reads "BananaPi F3"; this is expected.)

## Device tree: parity + small deltas

Both DTBs are built by the kernel (`devices/spacemit/spacemit_soc/BUILD.bazel`,
target `spacemit_k1x`) from sources in
`common/arch/riscv/boot/dts/spacemit/`:

- `k1-bananapi-f3.dtb`
- `k1-musepi-pro.dtb`

`k1-musepi-pro.dts` is **full BananaPi-F3 parity** — identical eMMC, dual
Ethernet (RTL8211F RGMII), SpacemiT P1 PMIC, PCIe, GPU (PowerVR Rogue), HDMI
pipeline, CPU DVFS OPP table, microSD and thermal zones — with only these
board-specific **deltas**:

- `model` = `SpacemiT MusePi Pro`, `compatible` = `spacemit,musepi-pro`,
  `spacemit,k1` (vs `bananapi,bpi-f3`).
- **USB3 hub GPIO map**: hub reset on `GPIO 123` (BananaPi: `GPIO 124`), plus a
  dedicated hub 5V rail regulator on `GPIO 127` and a `USB30_VBUS` regulator on
  `GPIO 79`.

Everything else is shared, so kernel/driver work done for the BananaPi F3
applies to the MusePi Pro unchanged.

## How board selection works (multi-DTB + `adtb_idx`)

The build packs **both** DTBs into a single multi-DTB image, and U-Boot picks
one by index at boot:

- `build/tasks/dtimages.mk` runs `mkdtimg create` over
  `k1-bananapi-f3.dtb` (index 0) + `k1-musepi-pro.dtb` (index 1) → `dtb.img`.
- `BOARD_INCLUDE_DTB_IN_BOOTIMG` embeds `dtb.img` in `vendor_boot`.
- At boot, the U-Boot board file (`board/spacemit/k1-x/k1x.c`) sets the env var
  **`adtb_idx`** from `product_name`: `k1-x_MUSE-Pi-Pro` → `1`, otherwise `0`.
  It is set on every boot, so it survives a reflashed env.
- `bootmeth_android` (`boot/image-fdt.c`) reads `${adtb_idx}` and hands the
  kernel that DTB from `dtb.img`.

This is why a single set of Android images boots both boards.

## Bootloader staging (per-board)

Android is identical for both boards; only the bootloader blobs and their target
media differ. `Android.mk` stages the prebuilt bootloaders produced by the
bootloaders tree (`release_android.sh`):

- **BananaPi F3** — `vendor/spacemit/k1/bootloader/` → `PRODUCT_OUT/`
  (FSBL, OpenSBI `fw_dynamic`, U-Boot `u-boot.itb`, `env.bin`,
  `partition_android.json`, `bootinfo_emmc.bin`). Bootloader lives in **eMMC**.
- **MusePi Pro** — `vendor/spacemit/musepi-pro/bootloader/` →
  `PRODUCT_OUT/musepi-pro/`. Same generic K1 U-Boot, but with
  `bootinfo_spinor.bin` and a **`partition_nor.json`** MTD layout, because the
  Pro's K1 boot strap reads the bootloader from **SPI-NOR**.

If `vendor/spacemit/musepi-pro/bootloader/u-boot-release.itb` is absent the
MusePi Pro staging rules are skipped (the BananaPi build is unaffected).

## Flashing

Use `flash_bpi_f3.sh` (copied to `PRODUCT_OUT` alongside the images). Run
`fastboot usb 0` on the U-Boot console first; for first-time setup, use `--dfu`
with the board in BROM DFU mode.

```sh
# BananaPi F3 (default) — bootloader to eMMC, Android to eMMC
./flash_bpi_f3.sh                       # bootloader + Android
./flash_bpi_f3.sh --android             # Android only
./flash_bpi_f3.sh --dfu --wipe          # first-time DFU, clean userdata

# MusePi Pro — bootloader to SPI-NOR, Android to eMMC
./flash_bpi_f3.sh --board musepi-pro            # bootloader + Android
./flash_bpi_f3.sh --board musepi-pro --android  # Android only (NOR untouched)
./flash_bpi_f3.sh --board musepi-pro --dfu      # first-time DFU
```

What `--board musepi-pro` changes:

- The bootloader is read from `PRODUCT_OUT/musepi-pro/` instead of `PRODUCT_OUT/`.
- The bootloader is written to **SPI-NOR**: the script first does
  `fastboot flash mtd partition_nor.json` (which routes subsequent named
  partitions to the NOR MTD device), then writes `bootinfo_spinor.bin`, FSBL,
  `env`, OpenSBI and U-Boot to NOR.
- Android (`boot`/`vendor_boot`/`super`/`vbmeta`/`dtbo`, both A/B slots) is still
  flashed to **eMMC**, exactly as on the BananaPi F3.

The BananaPi F3 path instead writes the bootloader to eMMC
(`flash fsbl/env/opensbi/uboot`, plus `bootinfo_emmc.bin`).

See `flash_bpi_f3.sh --help` for all modes and `--no-avb` (bring-up).

## See also

- `flash_bpi_f3.sh` — the flash tool (both boards).
- `profiling/README.md` — A/B kernel profiling harness (currently exercised on
  the BananaPi F3; board-agnostic via the `adtb_idx`-selected DTB).
- `README.fr.md` — French version of this document.
