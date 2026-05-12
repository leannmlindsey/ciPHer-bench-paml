#!/usr/bin/env bash
# Transfer PAML inputs + scripts from laptop to Delta.
# Run from the laptop (NOT from Delta).
set -euo pipefail

LOCAL_ROOT="/Users/leannmlindsey/WORK/CLAUDE_DPOTROPISEARCH/claude_copy/DpoTropiSearch/benchmark_external/paml_run"
DELTA_USER="llindsey1"
DELTA_HOST="dt-login.delta.ncsa.illinois.edu"
DELTA_ROOT="/u/${DELTA_USER}/llindsey/PHI_TSP/ciPHer-comparisons/paml"

ssh "${DELTA_USER}@${DELTA_HOST}" "mkdir -p ${DELTA_ROOT}/train_inputs"

echo "[1/3] Strain + phage proteomes + matrix (~155 MB)"
rsync -avz --info=progress2 \
  "${LOCAL_ROOT}/train_inputs/strain_AAs/" \
  "${DELTA_USER}@${DELTA_HOST}:${DELTA_ROOT}/train_inputs/strain_AAs/"
rsync -avz --info=progress2 \
  "${LOCAL_ROOT}/train_inputs/phage_AAs/" \
  "${DELTA_USER}@${DELTA_HOST}:${DELTA_ROOT}/train_inputs/phage_AAs/"
rsync -avz \
  "${LOCAL_ROOT}/train_inputs/kp_combined_interaction_matrix.csv" \
  "${DELTA_USER}@${DELTA_HOST}:${DELTA_ROOT}/train_inputs/"

echo "[2/3] Scripts (sbatch + env setup)"
rsync -avz \
  "${LOCAL_ROOT}/delta/02_setup_env_on_delta.sh" \
  "${LOCAL_ROOT}/delta/03_train_paml.sbatch" \
  "${LOCAL_ROOT}/delta/README.md" \
  "${DELTA_USER}@${DELTA_HOST}:${DELTA_ROOT}/"

echo "[3/3] Done. Next steps on Delta:"
cat <<EOF
  ssh ${DELTA_USER}@${DELTA_HOST}
  cd ${DELTA_ROOT}
  bash 02_setup_env_on_delta.sh   # ~5 min; one-time
  sbatch 03_train_paml.sbatch     # ~1-2 h walltime
  squeue -u ${DELTA_USER}         # to check status
EOF
