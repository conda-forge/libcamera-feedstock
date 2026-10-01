#!/bin/bash
set -xeo pipefail

rm -f subprojects/gtest.wrap
EXTRA_MESON_ARGS=(
  "-Dgstreamer=enabled"
  "-Dtest=false"
  "-Dcam=enabled"
  "-Dqcam=enabled"
  "-Dpycamera=enabled"
  "-Dv4l2=true"
  "-Dwerror=false"
  # New in 0.7.x: GPU SoftISP is an `auto` feature. Pin it off so an
  # incidentally-discoverable egl/glesv2 in host can't silently enable it and
  # link runtime deps we don't declare. (Flip to =enabled + add egl/glesv2 to
  # host & run if you ever want it.)
  "-Dsoftisp-gpu=disabled"
)
if [[ ${variant} == "rpi_fork" ]]; then
  # Make sure we build the standard pipeline and ipas contained in the upstream build
  # in ADDITION to the rpi/pisp ones
  EXTRA_MESON_ARGS+=(
    "-Dpipelines=imx8-isi,mali-c55,rkisp1,rpi/vc4,simple,uvcvideo,rpi/pisp"
    "-Dipas=mali-c55,rkisp1,rpi/vc4,simple,rpi/pisp"
    # New in 0.7.x rpi fork: the NN AWB algorithm needs tensorflow-lite, which
    # we don't package here. Pin it off (also an `auto` feature otherwise).
    "-Drpi-awb-nn=disabled"
  )
fi

# The build env also ships a python (meson depends on it), and it comes first on
# PATH, so meson would build the bindings against it instead of the python from
# the host env matrix. Point meson at the host python explicitly.
# (When cross compiling, the cross file already targets the host python.)
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" != "1" ]]; then
  cat > "${SRC_DIR}/native-python.ini" <<EOF2
[binaries]
python = '${PREFIX}/bin/python'
python3 = '${PREFIX}/bin/python'
EOF2
  MESON_ARGS="${MESON_ARGS} --native-file ${SRC_DIR}/native-python.ini"
fi

meson setup build ${MESON_ARGS} \
     -Ddocumentation=disabled \
     "${EXTRA_MESON_ARGS[@]}"

ninja -C build install

# Fail the build if the bindings were not built for the host python
PY_TAG=$("${PREFIX}/bin/python" -c "import sysconfig; print(sysconfig.get_config_var('SOABI'))")
ls "${PREFIX}"/lib/python*/site-packages/libcamera/_libcamera.${PY_TAG}.so

mkdir -p $PREFIX/etc/conda/env_vars.d
cp $RECIPE_DIR/env_vars.json $PREFIX/etc/conda/env_vars.d/libcamera.json