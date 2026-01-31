#!/bin/bash
set -xeo pipefail

rm -f subprojects/gtest.wrap
EXTRA_MESON_ARGS=""
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dgstreamer=enabled"
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dtest=false"
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dcam=enabled"
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dqcam=enabled"
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dpycamera=enabled"
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dv4l2=true"
EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dwerror=false"
if [[ ${variant} == "rpi_fork" ]]; then
  # Make sure we build the standard pipeline and ipas contained in the upstream build
  # in ADDITION to the rpi/pisp ones
  EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dpipelines=imx8-isi,mali-c55,rkisp1,rpi/vc4,simple,uvcvideo,rpi/pisp"
  EXTRA_MESON_ARGS="${EXTRA_MESON_ARGS} -Dipas=mali-c55,rkisp1,rpi/vc4,simple,rpi/pisp"
fi

meson setup build ${MESON_ARGS} \
     -Ddocumentation=disabled \
     ${EXTRA_MESON_ARGS}

ninja -C build install

# Copy the [de]activate scripts to $PREFIX/etc/conda/[de]activate.d.
# This will allow them to be run on environment activation.
for CHANGE in "activate" "deactivate"
do
    mkdir -p "${PREFIX}/etc/conda/${CHANGE}.d"
    cp "${RECIPE_DIR}/${CHANGE}.sh" "${PREFIX}/etc/conda/${CHANGE}.d/${PKG_NAME}_${CHANGE}.sh"
done
