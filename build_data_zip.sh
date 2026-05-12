#!/usr/bin/env bash
# Build ciPHer-bench-paml-data.zip from the laptop's existing artifacts.
# Output: /Users/leannmlindsey/Desktop/ciPHer-bench-data-zips/ciPHer-bench-paml-data.zip
#
# Contents (extracts to data/ on Delta):
#   data/train_inputs/strain_AAs/             200 K. pneumoniae bacterial .faa
#   data/train_inputs/phage_AAs/              105 phage .faa
#   data/train_inputs/kp_combined_interaction_matrix.csv
#   data/GenoPHI/                              Upstream GenoPHI clone, so the
#                                              Delta install does NOT need
#                                              internet for `git clone`
#
# OOD validation genomes (CHEN/UCSD/PBIP/Townsend/Jing/Wang) are NOT in this
# zip — those datasets have inconsistent on-disk layouts and need a separate
# normalization pass. Build that zip later with build_ood_data_zip.sh
# (TBD — once we agree on the normalized layout).
#
# Run from anywhere on the laptop.
set -euo pipefail

SRC_PAML_RUN="/Users/leannmlindsey/WORK/CLAUDE_DPOTROPISEARCH/claude_copy/DpoTropiSearch/benchmark_external/paml_run"
OUT_DIR="/Users/leannmlindsey/Desktop/ciPHer-bench-data-zips"
STAGE_PARENT="$(mktemp -d -t paml-data-zip-XXXXXX)"
STAGE_DIR="${STAGE_PARENT}/data"
ZIP_PATH="${OUT_DIR}/ciPHer-bench-paml-data.zip"

mkdir -p "${OUT_DIR}"
mkdir -p "${STAGE_DIR}"
echo "[stage] ${STAGE_DIR}"

echo "[1/3] Copy training proteomes + matrix (~330 MB)"
cp -R "${SRC_PAML_RUN}/train_inputs" "${STAGE_DIR}/"

echo "[2/3] Copy upstream GenoPHI clone (~235 MB)"
if [ -d "${SRC_PAML_RUN}/GenoPHI" ]; then
    cp -R "${SRC_PAML_RUN}/GenoPHI" "${STAGE_DIR}/"
fi
echo "  staged total: $(du -sh "${STAGE_DIR}" | cut -f1)"

echo "[3/3] Zip (fast compression)"
cd "${STAGE_PARENT}"
zip -qr -1 "${ZIP_PATH}" data
du -sh "${ZIP_PATH}"

rm -rf "${STAGE_PARENT}"

echo
echo "Done. Zip at: ${ZIP_PATH}"
echo
echo "Next: bash $(dirname "$0")/01_transfer_to_delta.sh"
