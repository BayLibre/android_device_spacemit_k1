#
# Copyright (C) 2024 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Generate dtb.img from DTB files

ifneq ($(filter k1%, $(TARGET_DEVICE)),)

MKDTIMG := prebuilts/misc/linux-x86/libufdt/mkdtimg
DTBIMAGE := $(PRODUCT_OUT)/dtb.img

LOCAL_DTB := device/spacemit/kernel/$(TARGET_KERNEL_USE)

# Every K1 DTB the selected kernel ships gets packed into dtb.img (multi-DTB),
# which BOARD_INCLUDE_DTB_IN_BOOTIMG puts in vendor_boot; U-Boot selects the
# matching one by board compatible at boot. Which boards exist depends on
# TARGET_KERNEL_USE -- mainline builds the BananaPi F3 and the MusePi Pro, the
# 6.18 tree only the F3 -- so discover them instead of hardcoding a list that
# would break the build on a kernel that does not have them all.
DTB_FILES := $(wildcard $(LOCAL_DTB)/k1-*.dtb)

ifeq ($(DTB_FILES),)
$(error No K1 DTB in $(LOCAL_DTB) (TARGET_KERNEL_USE=$(TARGET_KERNEL_USE)))
endif

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
