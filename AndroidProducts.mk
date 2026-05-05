#
# Copyright (C) 2024 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/bananapi_f3/aosp_bananapi_f3.mk \
    $(LOCAL_DIR)/bananapi_f3/aosp_bananapi_f3_tablet.mk

COMMON_LUNCH_CHOICES := \
    aosp_bananapi_f3-trunk_staging-userdebug \
    aosp_bananapi_f3-trunk_staging-eng \
    aosp_bananapi_f3_tablet-trunk_staging-userdebug \
    aosp_bananapi_f3_tablet-trunk_staging-eng
