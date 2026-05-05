#
# Copyright (C) 2024 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Tablet build for BananaPi F3

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, frameworks/native/build/tablet-10in-xhdpi-2048-dalvik-heap.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, device/spacemit/k1/device.mk)

# Tablet characteristics
PRODUCT_CHARACTERISTICS := tablet

# Product identification
PRODUCT_NAME := aosp_bananapi_f3_tablet
PRODUCT_DEVICE := k1
PRODUCT_BRAND := BananaPi
PRODUCT_MODEL := BananaPi F3 Tablet
PRODUCT_MANUFACTURER := Sinovoip

# Tablet packages
PRODUCT_PACKAGES += \
    Launcher3QuickStep
