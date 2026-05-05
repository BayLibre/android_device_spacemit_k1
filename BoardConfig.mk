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

# Kernel
TARGET_KERNEL_USE ?= mainline
KERNEL_MODULES_PATH := device/spacemit/k1-kernel/$(TARGET_KERNEL_USE)

TARGET_PREBUILT_KERNEL := $(KERNEL_MODULES_PATH)/Image
# BOARD_PREBUILT_DTBOIMAGE := $(KERNEL_MODULES_PATH)/dtbo.img

# Kernel modules
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(KERNEL_MODULES_PATH)/ramdisk/*.ko)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES)

BOARD_VENDOR_KERNEL_MODULES := $(wildcard $(KERNEL_MODULES_PATH)/vendor_dlkm/*.ko)
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
