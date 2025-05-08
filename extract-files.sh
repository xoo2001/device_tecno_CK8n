#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=CK8n
VENDOR=tecno

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

export TARGET_ENABLE_CHECKELF=true

# Define the default patchelf version used to patch blobs
# This will also be used for utility functions like FIX_SONAME
# Older versions break some camera blobs for us
export PATCHELF_VERSION=0_17_2

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        system_ext/lib64/libimsma.so)
            [ "$2" = "" ] && return 0
            "$PATCHELF" --replace-needed "libsink.so" "libsink-mtk.so" "${2}"
            ;;
        system_ext/lib64/libsource.so)
            [ "$2" = "" ] && return 0
            grep -q libui_shim.so "$2" || "$PATCHELF" --add-needed libui_shim.so "$2"
            ;;
        vendor/bin/hw/android.hardware.gnss-service.mediatek | vendor/lib64/hw/android.hardware.gnss-impl-mediatek.so)
            [ "$2" = "" ] && return 0
            "$PATCHELF" --replace-needed "android.hardware.gnss-V1-ndk_platform.so" "android.hardware.gnss-V1-ndk.so" "$2"
            ;;
        vendor/bin/hw/android.hardware.lights-service.mediatek)
            [ "$2" = "" ] && return 0
            "$PATCHELF" --replace-needed "android.hardware.light-V1-ndk_platform.so" "android.hardware.light-V1-ndk.so" "$2"
            ;;
        vendor/bin/hw/android.hardware.media.c2@1.2-mediatek-64b)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libstagefright_foundation-v33.so" "${2}"
            "${PATCHELF}" --replace-needed "libavservices_minijail_vendor.so" "libavservices_minijail.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.neuralnetworks@1.3-service-mtk-neuron |\
        vendor/bin/nfcstackp-vendor |\
        vendor/lib*/libnvram.so |\
        vendor/lib*/libsysenv.so |\
        vendor/lib*/libtflite_mtk.so)
            [ "$2" = "" ] && return 0
            grep -q "libbase_shim.so" "$2" || "$PATCHELF" --add-needed "libbase_shim.so" "$2"
            ;;
        vendor/bin/hw/camerahalserver)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v31.so" "${2}"
            "${PATCHELF}" --replace-needed "libbinder.so" "libbinder-v31.so" "${2}"
            "${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v31.so" "${2}"
            ;;
        vendor/bin/mnld)
             ;&
         vendor/lib64/libaalservice.so)
             ;&
         vendor/lib64/libcam.utils.sensorprovider.so)
            [ "$2" = "" ] && return 0
             "${PATCHELF}" --replace-needed "libsensorndkbridge.so" "libsensorndkbridge-v31.so" "${2}"
             ;;
        vendor/lib64/hw/android.hardware.camera.provider@2.6-impl-mediatek.so)
            [ "$2" = "" ] && return 0
            grep -q libshim_camera_metadata.so "$2" || "$PATCHELF" --add-needed libshim_camera_metadata.so "$2"
            ;;
        vendor/bin/hw/vendor.mediatek.hardware.pq@2.2-service)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libbinder.so" "libbinder-v31.so" "${2}"
            "${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v31.so" "${2}"
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v31.so" "${2}"
            ;;
        vendor/etc/init/android.hardware.media.c2@1.2-mediatek.rc)
            [ "$2" = "" ] && return 0
            sed -i 's/@1.2-mediatek/@1.2-mediatek-64b/g' "${2}"
            ;;
        vendor/lib/hw/audio.primary.mt6893.so)
            [ "$2" = "" ] && return 0
            ;&
        vendor/lib64/hw/audio.primary.mt6893.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v31.so" "${2}"
            "${PATCHELF}" --replace-needed "libalsautils.so" "libalsautils-v31.so" "$2"
            ;;
        vendor/etc/vintf/manifest/manifest_media_c2_V1_2_default.xml)
            [ "$2" = "" ] && return 0
            sed -i 's/1.1/1.2/' "$2"
            ;;
        vendor/lib64/hw/gf_fingerprint.default.so)
            [ "$2" = "" ] && return 0
            sed -i 's/libfingerprint.default.so/gf_fingerprint.default.so/' "$2"
            ;;
        vendor/lib64/lib3a.ae.stat.so |\
        vendor/lib64/lib3a.flash.so |\
        vendor/lib64/lib3a.sensors.color.so |\
        vendor/lib64/lib3a.sensors.flicker.so)
            [ "$2" = "" ] && return 0
            grep -q "liblog.so" "${2}" || "$PATCHELF" --add-needed "liblog.so" "${2}"
            ;;
        vendor/lib64/mt6893/libmnl.so)
            [ "$2" = "" ] && return 0
            grep -q "libcutils.so" "${2}" || "$PATCHELF" --add-needed "libcutils.so" "${2}"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

function blob_fixup_dry() {
    blob_fixup "$1" ""
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
