#
# Copyright (C) 2024 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Generate dtb.img from DTB files

ifneq ($(filter k1%, $(TARGET_DEVICE)),)

MKDTIMG := prebuilts/misc/linux-x86/libufdt/mkdtimg
DTBIMAGE := $(PRODUCT_OUT)/dtb.img

LOCAL_DTB := device/spacemit/k1-kernel/$(TARGET_KERNEL_USE)

# DTB files for BananaPi F3 (K1 SoC)
DTB_FILES := \
	$(LOCAL_DTB)/k1-bananapi-f3.dtb

$(DTBIMAGE): $(DTB_FILES) $(MKDTIMG)
	$(MKDTIMG) create $@ --page_size=4096 $(DTB_FILES)

include $(CLEAR_VARS)
LOCAL_MODULE := dtbimage
LOCAL_LICENSE_KINDS := legacy_notice
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_ADDITIONAL_DEPENDENCIES := $(DTBIMAGE)
include $(BUILD_PHONY_PACKAGE)

droidcore: dtbimage

endif
