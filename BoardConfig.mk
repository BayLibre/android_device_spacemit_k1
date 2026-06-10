#
# Copyright (C) 2024 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit common configuration
include device/spacemit/common/BoardConfigCommon.mk

# Platform
TARGET_BOARD_PLATFORM := k1
TARGET_BOOTLOADER_BOARD_NAME := k1

# CPU: SpaceMit X60.  Enables the extended ISA flags / -mcpu tuning declared
# by the "x60" arch variant in build/soong/cc/config/riscv64_device.go
# (rv64gcv_zba_zbb_zbs_zicond_zfh_zvfh_zicboz_zicbop_zbc_zkt, -mcpu=spacemit-x60).
TARGET_ARCH_VARIANT := x60

# Kernel
TARGET_KERNEL_USE ?= mainline
KERNEL_MODULES_PATH := device/spacemit/k1-kernel/$(TARGET_KERNEL_USE)

TARGET_PREBUILT_KERNEL := $(KERNEL_MODULES_PATH)/Image
# BOARD_PREBUILT_DTBOIMAGE := $(KERNEL_MODULES_PATH)/dtbo.img

# Kernel modules
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(KERNEL_MODULES_PATH)/ramdisk/*.ko)
# spacemit-ccu.ko (CCU core) MUST load before spacemit-ccu-k1.ko, but the
# alphabetical $(wildcard) order puts "spacemit-ccu-k1.ko" first ('-' < '.'),
# so the K1 clk driver loads with unresolved spacemit_ccu_* symbols -> no clocks
# -> pinctrl/mmc/i2c/etc defer -> reboot. Force the core first; the rest keep
# wildcard order (which booted pre-migration).
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := \
    $(KERNEL_MODULES_PATH)/ramdisk/spacemit-ccu.ko \
    $(filter-out %/spacemit-ccu.ko,$(BOARD_VENDOR_RAMDISK_KERNEL_MODULES))

BOARD_VENDOR_KERNEL_MODULES := $(wildcard $(KERNEL_MODULES_PATH)/vendor_dlkm/*.ko)
# realtek.ko (RTL8211F PHY) and its phy_package.ko dependency MUST load before
# k1_emac.ko. The alphabetical $(wildcard) order loads k1_emac first, so emac's
# MDIO scan binds the PHY to the Generic PHY driver (no rgmii-id RX delay) ->
# eth0 TX works but RX is dead. Force the PHY modules first; the rest keep
# wildcard order.
BOARD_VENDOR_KERNEL_MODULES_LOAD := \
    $(KERNEL_MODULES_PATH)/vendor_dlkm/phy_package.ko \
    $(KERNEL_MODULES_PATH)/vendor_dlkm/realtek.ko \
    $(filter-out %/phy_package.ko %/realtek.ko,$(BOARD_VENDOR_KERNEL_MODULES))
BOARD_SYSTEM_KERNEL_MODULES := $(wildcard $(KERNEL_MODULES_PATH)/system_dlkm/*.ko)
BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(BOARD_SYSTEM_KERNEL_MODULES)

# Bootconfig
BOARD_BOOTCONFIG += androidboot.hardware=k1
BOARD_BOOTCONFIG += androidboot.boot_devices=soc/soc:storage-bus/d4281000.mmc
BOARD_BOOTCONFIG += androidboot.fstab_suffix=k1
BOARD_BOOTCONFIG += androidboot.vendor.apex.com.android.hardware.keymint=com.android.hardware.keymint.rust_nonsecure
BOARD_BOOTCONFIG += androidboot.vendor.apex.com.android.hardware.gatekeeper=com.android.hardware.gatekeeper.nonsecure
BOARD_BOOTCONFIG += androidboot.selinux=permissive

# Partition sizes
BOARD_SUPER_PARTITION_SIZE := 4831838208
BOARD_SPACEMIT_DYNAMIC_PARTITIONS_SIZE := 2411724800
BOARD_USERDATAIMAGE_PARTITION_SIZE := 10662837248

# WiFi
BOARD_WLAN_DEVICE := realtek
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211

# Bluetooth
BOARD_HAVE_BLUETOOTH := true
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := device/spacemit/k1/bluetooth

# SELinux
BOARD_VENDOR_SEPOLICY_DIRS += device/spacemit/k1/sepolicy/vendor

# Recovery
TARGET_RECOVERY_FSTAB_GENRULE := gen_fstab_k1

# VINTF
DEVICE_MANIFEST_FILE := device/spacemit/k1/manifest.xml
