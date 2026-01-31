#!/bin/bash
set -ex

# Set libcamera paths for testing
export LIBCAMERA_IPA_MODULE_PATH="${PREFIX}/lib/libcamera"
export LIBCAMERA_IPA_PROXY_PATH="${PREFIX}/libexec/libcamera"
export LIBCAMERA_IPA_CONFIG_PATH="${PREFIX}/share/libcamera/ipa"

# Verify paths exist
echo "Checking libcamera installation..."
echo "IPA_MODULE_PATH: $LIBCAMERA_IPA_MODULE_PATH"
ls -la "$LIBCAMERA_IPA_MODULE_PATH" || echo "WARNING: IPA module path not found"

echo "IPA_PROXY_PATH: $LIBCAMERA_IPA_PROXY_PATH"
ls -la "$LIBCAMERA_IPA_PROXY_PATH" || echo "WARNING: IPA proxy path not found"

echo "IPA_CONFIG_PATH: $LIBCAMERA_IPA_CONFIG_PATH"
ls -la "$LIBCAMERA_IPA_CONFIG_PATH" || echo "WARNING: IPA config path not found"

# Run the actual test
echo "Running cam -l..."
cam -l

echo "See if qcam is installed:"
which qcam

echo "Checking libcamera.so installation..."
test -f $PREFIX/lib/libcamera.so

echo "Checking libcamera.h installation..."
test -f $PREFIX/include/libcamera/libcamera/libcamera.h

if [[ "${target_platform}" != "linux-aarch64" ]]; then
    echo "Checking libcamerify installation..."
    # libcamerify is a V4L2 camera wrapper for libcamera
    libcamerify -h
fi
