LOCAL_PATH := $(call my-dir)

#
# Copy bootloader prebuilts and flash script to PRODUCT_OUT
# Source: vendor/spacemit/k1/bootloader/ (populated by release_android.sh)
#
BL_PREBUILT := vendor/spacemit/k1/bootloader

ifneq ($(wildcard $(BL_PREBUILT)/u-boot-release.itb),)

SPACEMIT_FLASH_FILES :=

# u-boot.itb
$(PRODUCT_OUT)/u-boot.itb: $(BL_PREBUILT)/u-boot-release.itb
	cp $< $@
SPACEMIT_FLASH_FILES += $(PRODUCT_OUT)/u-boot.itb

# fw_dynamic.itb (prefer .itb, fallback to .bin)
ifneq ($(wildcard $(BL_PREBUILT)/fw_dynamic.itb),)
$(PRODUCT_OUT)/fw_dynamic.itb: $(BL_PREBUILT)/fw_dynamic.itb
	cp $< $@
else
$(PRODUCT_OUT)/fw_dynamic.itb: $(BL_PREBUILT)/fw_dynamic-release.bin
	cp $< $@
endif
SPACEMIT_FLASH_FILES += $(PRODUCT_OUT)/fw_dynamic.itb

# env.bin
$(PRODUCT_OUT)/env.bin: $(BL_PREBUILT)/env-release.bin
	cp $< $@
SPACEMIT_FLASH_FILES += $(PRODUCT_OUT)/env.bin

# factory/FSBL.bin
ifneq ($(wildcard $(BL_PREBUILT)/factory/FSBL.bin),)
$(PRODUCT_OUT)/factory/FSBL.bin: $(BL_PREBUILT)/factory/FSBL.bin
	mkdir -p $(dir $@)
	cp $< $@
else
$(PRODUCT_OUT)/factory/FSBL.bin: $(BL_PREBUILT)/u-boot-spl-release.bin
	mkdir -p $(dir $@)
	cp $< $@
endif
SPACEMIT_FLASH_FILES += $(PRODUCT_OUT)/factory/FSBL.bin

# factory/bootinfo_emmc.bin (optional)
ifneq ($(wildcard $(BL_PREBUILT)/factory/bootinfo_emmc.bin),)
$(PRODUCT_OUT)/factory/bootinfo_emmc.bin: $(BL_PREBUILT)/factory/bootinfo_emmc.bin
	mkdir -p $(dir $@)
	cp $< $@
SPACEMIT_FLASH_FILES += $(PRODUCT_OUT)/factory/bootinfo_emmc.bin
endif

# partition_android.json (optional)
ifneq ($(wildcard $(BL_PREBUILT)/partition_android.json),)
$(PRODUCT_OUT)/partition_android.json: $(BL_PREBUILT)/partition_android.json
	cp $< $@
SPACEMIT_FLASH_FILES += $(PRODUCT_OUT)/partition_android.json
endif

# flash script
$(PRODUCT_OUT)/flash_bpi_f3.sh: device/spacemit/k1/flash_bpi_f3.sh
	cp $< $@
	chmod +x $@
SPACEMIT_FLASH_FILES += $(PRODUCT_OUT)/flash_bpi_f3.sh

droidcore: $(SPACEMIT_FLASH_FILES)

endif # u-boot-release.itb exists
