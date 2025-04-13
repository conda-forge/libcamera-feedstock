#!/bin/bash
set -xeo pipefail

rm -f subprojects/gtest.wrap
EXTRA_MESON_ARGS=""
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dgstreamer=enabled"
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dtest=false"
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dcam=enabled"
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dpycamera=enabled"
if [[ ${target_platform} == "linux-*" ]]; then
  EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dv4l2=true"
fi
if [[ ${variant} == "rpi_fork" ]]; then
  EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dpipelines=rpi/vc4,rpi/pisp"
  EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dipas=rpi/vc4,rpi/pisp"
  EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dqcam=disabled"
fi

meson setup build ${MESON_ARGS} \
     -Ddocumentation=disabled \
     ${EXTRA_MESON_ARGS}

ninja -C build install
