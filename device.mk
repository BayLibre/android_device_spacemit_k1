#
# Copyright (C) 2024 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit common
$(call inherit-product, device/spacemit/common/device-common.mk)

# Vendor firmware
$(call inherit-product, vendor/spacemit/k1/k1.mk)

# Platform
PRODUCT_PLATFORM := k1

# Kernel
TARGET_KERNEL_USE ?= mainline
LOCAL_KERNEL := device/spacemit/k1-kernel/$(TARGET_KERNEL_USE)/Image

PRODUCT_COPY_FILES += \
    $(LOCAL_KERNEL):kernel

# Overlays (stay-on, no lockscreen for dev)
DEVICE_PACKAGE_OVERLAYS := device/spacemit/k1/overlay

# Properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware.gralloc=minigbm \
    sys.usb.configfs=1 \
    sys.usb.controller=mv-udc \
    persist.vendor.audio.primary.card_name=BananaPi-F3-Audio \
    persist.vendor.audio.primary.card=0 \
    persist.vendor.audio.primary.device=0 \
    persist.vendor.audio.mixer.config=/vendor/etc/mixer_controls.xml \
    vendor.thermal.hardware=spacemit \
    vendor.hwc.drm.internal_display_names=HDMI-A-1 \
    ro.vendor.boot_security_patch=2025-01-05 \
    config.disable_renderscript=true \
    ro.vendor.hwc.use_overlay_planes=false \
    ro.sf.lcd_density=240

# Audio mixer controls (BPI-F3 / ES8326B codec)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/audio/mixer_controls.xml:$(TARGET_COPY_OUT_VENDOR)/etc/mixer_controls.xml

# ============================================================
# External USB camera support
# ============================================================
PRODUCT_PACKAGES += \
    android.hardware.camera.provider-V1-external-service

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/external_camera_config.xml:$(TARGET_COPY_OUT_VENDOR)/etc/external_camera_config.xml \
    frameworks/native/data/etc/android.hardware.camera.external.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.external.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml

# Codec2: use AIDL HAL so that app processes (e.g. scrcpy) can discover
# software codecs via IComponentStore/software instead of relying on the
# in-process ApexCodecs path that only works in system processes.
PRODUCT_PROPERTY_OVERRIDES += \
    media.c2.hal.selection=aidl \
    debug.stagefright.c2inputsurface=-1

# Vendor seccomp policy extension for media.swcodec.
# Allows syscalls needed by Mesa/Zink GPU init (sched_getaffinity, epoll, etc.)
# triggered via AHardwareBuffer_isSupported inside the mediaswcodec sandbox.
PRODUCT_COPY_FILES += \
    device/spacemit/k1/seccomp_policy/mediaswcodec.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediaswcodec.policy

# Soong namespaces for Mesa prebuilts and gbm_mesa_wrapper
PRODUCT_SOONG_NAMESPACES += device/spacemit/k1/mesa
PRODUCT_SOONG_NAMESPACES += external/minigbm/gbm_mesa_driver

# Override preloaded-classes to drop android.renderscript.* entries —
# RenderScript is deprecated since API 31 and not built on RISC-V, so Zygote
# logs warnings on every preload attempt. The device file is the upstream list
# minus those entries.
PRODUCT_COPY_FILES += \
    device/spacemit/k1/preloaded-classes:system/etc/preloaded-classes

