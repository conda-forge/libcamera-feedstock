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
    # The fork renamed the soft ISP IPA 'simple' -> 'softisp' in 0.7.2+rpt
    # (vanilla 0.7.2 still calls it 'simple').
    "-Dipas=mali-c55,rkisp1,rpi/vc4,softisp,rpi/pisp"
    # New in 0.7.x rpi fork: the NN AWB algorithm needs tensorflow-lite, which
    # we don't package here. Pin it off (also an `auto` feature otherwise).
    "-Drpi-awb-nn=disabled"
  )
else
  # Upstream's default ('auto') picks every pipeline supported on the target
  # arch. Since 0.7.2 that includes 'virtual', which needs libyuv: not on
  # conda-forge, so meson would git-clone and vendor it during the build. Pin
  # the pre-0.7.2 auto set instead.
  if [[ ${target_platform} == "linux-aarch64" ]]; then
    EXTRA_MESON_ARGS+=("-Dpipelines=imx8-isi,mali-c55,rkisp1,rpi/pisp,rpi/vc4,simple,uvcvideo")
  else
    EXTRA_MESON_ARGS+=("-Dpipelines=ipu3,simple,uvcvideo")
  fi
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

# IPA modules are signed at install time, and libcamera only loads modules
# whose signature verifies in-process; the others run isolated in a proxy
# worker process (conda-forge/libcamera-feedstock#19). rattler-build's RPATH
# relocation would modify the modules after signing, so they are excluded from
# it (see build.dynamic_linking.binary_relocation in recipe.yaml). Set the RPATH
# ourselves (the env's lib/ dir) and then re-sign with the build's private key.
# --force-rpath writes DT_RPATH: rattler-build rewrites DT_RUNPATH to DT_RPATH
# even in files excluded from relocation, which would break the signature again.
for module in "${PREFIX}"/lib/libcamera/ipa/*.so; do
  patchelf --force-rpath --set-rpath '$ORIGIN/../..' "${module}"
  openssl dgst -sha256 -sign build/src/ipa-priv-key.pem -out "${module}.sign" "${module}"
done

# Fail the build if the bindings were not built for the host python
PY_TAG=$("${PREFIX}/bin/python" -c "import sysconfig; print(sysconfig.get_config_var('SOABI'))")
ls "${PREFIX}"/lib/python*/site-packages/libcamera/_libcamera.${PY_TAG}.so

mkdir -p $PREFIX/etc/conda/env_vars.d
cp $RECIPE_DIR/env_vars.json $PREFIX/etc/conda/env_vars.d/libcamera.json