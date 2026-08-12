LOCAL_PATH := $(call my-dir)

#
# Copy bootloader prebuilts and flash script to PRODUCT_OUT
# Source: vendor/spacemit/k1/bootloader/ (populated by release_android.sh)
#
# Every device/*/Android.mk is parsed for all products, and these rules write to
# the shared $(PRODUCT_OUT). Gate on TARGET_DEVICE so the K1 bootloader rules
# only fire for a K1 build; otherwise they collide with the K3 rules, which
# define the same $(PRODUCT_OUT)/u-boot.itb (and friends).
ifneq ($(filter k1%, $(TARGET_DEVICE)),)

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

#
# MusePi Pro bootloader prebuilts (same generic K1 U-Boot, separate board slot).
# Source: vendor/spacemit/musepi-pro/bootloader/ (populated by release_android.sh
# from config/boards/spacemit-musepi-pro.yaml). Staged under PRODUCT_OUT/musepi-pro/
# so it does not collide with the BPI-F3 set; the flash script selects per board.
# Guarded by the wildcard, so this is inert until that board's bootloader exists.
#
MUSEPI_BL_PREBUILT := vendor/spacemit/musepi-pro/bootloader
MUSEPI_OUT := $(PRODUCT_OUT)/musepi-pro

ifneq ($(wildcard $(MUSEPI_BL_PREBUILT)/u-boot-release.itb),)

SPACEMIT_MUSEPI_FLASH_FILES :=

$(MUSEPI_OUT)/u-boot.itb: $(MUSEPI_BL_PREBUILT)/u-boot-release.itb
	mkdir -p $(dir $@)
	cp $< $@
SPACEMIT_MUSEPI_FLASH_FILES += $(MUSEPI_OUT)/u-boot.itb

ifneq ($(wildcard $(MUSEPI_BL_PREBUILT)/fw_dynamic.itb),)
$(MUSEPI_OUT)/fw_dynamic.itb: $(MUSEPI_BL_PREBUILT)/fw_dynamic.itb
	mkdir -p $(dir $@)
	cp $< $@
else
$(MUSEPI_OUT)/fw_dynamic.itb: $(MUSEPI_BL_PREBUILT)/fw_dynamic-release.bin
	mkdir -p $(dir $@)
	cp $< $@
endif
SPACEMIT_MUSEPI_FLASH_FILES += $(MUSEPI_OUT)/fw_dynamic.itb

$(MUSEPI_OUT)/env.bin: $(MUSEPI_BL_PREBUILT)/env-release.bin
	mkdir -p $(dir $@)
	cp $< $@
SPACEMIT_MUSEPI_FLASH_FILES += $(MUSEPI_OUT)/env.bin

ifneq ($(wildcard $(MUSEPI_BL_PREBUILT)/factory/FSBL.bin),)
$(MUSEPI_OUT)/factory/FSBL.bin: $(MUSEPI_BL_PREBUILT)/factory/FSBL.bin
	mkdir -p $(dir $@)
	cp $< $@
else
$(MUSEPI_OUT)/factory/FSBL.bin: $(MUSEPI_BL_PREBUILT)/u-boot-spl-release.bin
	mkdir -p $(dir $@)
	cp $< $@
endif
SPACEMIT_MUSEPI_FLASH_FILES += $(MUSEPI_OUT)/factory/FSBL.bin

ifneq ($(wildcard $(MUSEPI_BL_PREBUILT)/factory/bootinfo_emmc.bin),)
$(MUSEPI_OUT)/factory/bootinfo_emmc.bin: $(MUSEPI_BL_PREBUILT)/factory/bootinfo_emmc.bin
	mkdir -p $(dir $@)
	cp $< $@
SPACEMIT_MUSEPI_FLASH_FILES += $(MUSEPI_OUT)/factory/bootinfo_emmc.bin
endif

# bootinfo_spinor.bin: BROM header for SPI-NOR boot (MusePi Pro boots from NOR)
ifneq ($(wildcard $(MUSEPI_BL_PREBUILT)/factory/bootinfo_spinor.bin),)
$(MUSEPI_OUT)/factory/bootinfo_spinor.bin: $(MUSEPI_BL_PREBUILT)/factory/bootinfo_spinor.bin
	mkdir -p $(dir $@)
	cp $< $@
SPACEMIT_MUSEPI_FLASH_FILES += $(MUSEPI_OUT)/factory/bootinfo_spinor.bin
endif

ifneq ($(wildcard $(MUSEPI_BL_PREBUILT)/partition_android.json),)
$(MUSEPI_OUT)/partition_android.json: $(MUSEPI_BL_PREBUILT)/partition_android.json
	mkdir -p $(dir $@)
	cp $< $@
SPACEMIT_MUSEPI_FLASH_FILES += $(MUSEPI_OUT)/partition_android.json
endif

# partition_nor.json: SPI-NOR (MTD) bootloader layout for the MusePi Pro
ifneq ($(wildcard $(MUSEPI_BL_PREBUILT)/partition_nor.json),)
$(MUSEPI_OUT)/partition_nor.json: $(MUSEPI_BL_PREBUILT)/partition_nor.json
	mkdir -p $(dir $@)
	cp $< $@
SPACEMIT_MUSEPI_FLASH_FILES += $(MUSEPI_OUT)/partition_nor.json
endif

droidcore: $(SPACEMIT_MUSEPI_FLASH_FILES)

endif # musepi-pro u-boot-release.itb exists

endif # TARGET_DEVICE is k1*
