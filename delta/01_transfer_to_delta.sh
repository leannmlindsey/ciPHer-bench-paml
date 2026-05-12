#!/usr/bin/env bash
# Transfer the PAML data zip from laptop to Delta.
# Run from the laptop (NOT from Delta).
#
# Assumes you've already built ciPHer-bench-paml-data.zip locally.
# (See README.md / ../build_data_zip.sh for how that zip was built.)
set -euo pipefail

LOCAL_ZIP="${LOCAL_ZIP:-/Users/leannmlindsey/Desktop/ciPHer-bench-data-zips/ciPHer-bench-paml-data.zip}"
DELTA_USER="${DELTA_USER:-llindsey1}"
DELTA_HOST="${DELTA_HOST:-dt-login.delta.ncsa.illinois.edu}"
DELTA_ROOT="${DELTA_ROOT:-/projects/bfzj/${DELTA_USER}/PHI_TSP/ciPHer-comparisons/paml}"

if [ ! -f "${LOCAL_ZIP}" ]; then
    echo "ERROR: data zip not found at ${LOCAL_ZIP}" >&2
    echo "  Build it first: bash $(dirname "$0")/../build_data_zip.sh" >&2
    exit 1
fi

echo "[1/2] Ensuring Delta target dir exists"
ssh "${DELTA_USER}@${DELTA_HOST}" "mkdir -p ${DELTA_ROOT}/data ${DELTA_ROOT}/logs"

echo "[2/2] Transferring data zip ($(du -sh "${LOCAL_ZIP}" | cut -f1))"
rsync -avz --info=progress2 "${LOCAL_ZIP}" "${DELTA_USER}@${DELTA_HOST}:${DELTA_ROOT}/data/"

echo
echo "Next steps on Delta:"
cat <<EOF
  ssh ${DELTA_USER}@${DELTA_HOST}
  cd ${DELTA_ROOT}

  # (First time only) clone the repo here:
  #   git clone git@github.com:LeAnnMLindsey/ciPHer-bench-paml.git .
  # (Subsequent runs) just pull latest:
  #   git pull

  # Unzip data:
  cd data
  unzip -q $(basename "${LOCAL_ZIP}")
  cd ..

  # Activate env config + install (one-time):
  cp config/paml_delta.env paml.env
  source paml.env
  bash delta/02_setup_env_on_delta.sh

  # Submit:
  sbatch --account="\${ACCOUNT}" --partition="\${PARTITION}" \\
         --gpus-per-node="\${GPUS_PER_NODE}" delta/03_train_paml.sbatch
EOF
