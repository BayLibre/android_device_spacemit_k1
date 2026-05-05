#
# Copyright (C) 2024 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, device/spacemit/k1/device.mk)

PRODUCT_NAME := aosp_bananapi_f3
PRODUCT_DEVICE := k1
PRODUCT_BRAND := BananaPi
PRODUCT_MODEL := BananaPi F3
PRODUCT_MANUFACTURER := Sinovoip
