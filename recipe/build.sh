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

# ============================================================================
# POSSIBLE FIX FOR ISSUE #19: Re-sign IPA modules after conda post-processing
# ============================================================================
# Conda's post-processing (RPATH rewriting, binary prefixing) modifies the
# IPA module binaries, which invalidates their cryptographic signatures.
# We must re-sign them after these modifications.

PRIV_KEY="${SRC_DIR}/build/src/ipa-priv-key.pem"
SIGN_SCRIPT="${SRC_DIR}/src/ipa/ipa-sign.sh"

if [ -f "$PRIV_KEY" ] && [ -f "$SIGN_SCRIPT" ]; then
    echo "=========================================="
    echo "Re-signing IPA modules post-installation"
    echo "=========================================="

    # Find all IPA modules in the installation
    IPA_MODULES=$(find "${PREFIX}/lib/libcamera" -name "ipa_*.so" 2>/dev/null || true)

    if [ -n "$IPA_MODULES" ]; then
        for ipa_module in $IPA_MODULES; do
            echo "Re-signing: $(basename $ipa_module)"

            # Sign the module (creates .so.sign file)
            "$SIGN_SCRIPT" "$PRIV_KEY" "$ipa_module" "${ipa_module}.sign"

            # Verify the signature file was created
            if [ ! -f "${ipa_module}.sign" ]; then
                echo "WARNING: Failed to create signature for $ipa_module"
            fi
        done
        echo "IPA module re-signing complete"
    else
        echo "WARNING: No IPA modules found to sign"
    fi

    # Clean up the private key for security
    rm -f "$PRIV_KEY"
    echo "Private key removed"
else
    echo "=========================================="
    echo "WARNING: Cannot re-sign IPA modules"
    echo "Private key: $([ -f "$PRIV_KEY" ] && echo "found" || echo "NOT FOUND")"
    echo "Sign script: $([ -f "$SIGN_SCRIPT" ] && echo "found" || echo "NOT FOUND")"
    echo "IPA modules will run in isolated mode (slower)"
    echo "=========================================="
fi

# Copy the [de]activate scripts to $PREFIX/etc/conda/[de]activate.d.
# This will allow them to be run on environment activation.
for CHANGE in "activate" "deactivate"
do
    mkdir -p "${PREFIX}/etc/conda/${CHANGE}.d"
    cp "${RECIPE_DIR}/${CHANGE}.sh" "${PREFIX}/etc/conda/${CHANGE}.d/${PKG_NAME}_${CHANGE}.sh"
done
