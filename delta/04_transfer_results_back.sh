#!/usr/bin/env bash
# Pull trained model + clusters + feature table back from Delta after the job finishes.
# Run from the laptop. Excludes the mmseqs intermediates which the sbatch already removed.
set -euo pipefail

LOCAL_ROOT="/Users/leannmlindsey/WORK/CLAUDE_DPOTROPISEARCH/claude_copy/DpoTropiSearch/benchmark_external/paml_run"
DELTA_USER="llindsey1"
DELTA_HOST="dt-login.delta.ncsa.illinois.edu"
DELTA_ROOT="/projects/bfzj/${DELTA_USER}/PHI_TSP/ciPHer-comparisons/paml"

mkdir -p "${LOCAL_ROOT}/kp_train_output_delta"

echo "Pulling kp_train_output/ (model + clusters + features + logs)"
rsync -avz --info=progress2 \
  --exclude '*/tmp/*' \
  "${DELTA_USER}@${DELTA_HOST}:${DELTA_ROOT}/kp_train_output/" \
  "${LOCAL_ROOT}/kp_train_output_delta/"

echo "Pulling SLURM logs"
rsync -avz \
  "${DELTA_USER}@${DELTA_HOST}:${DELTA_ROOT}/logs/" \
  "${LOCAL_ROOT}/kp_train_output_delta/slurm_logs/"

echo "Done. Trained PAML model under ${LOCAL_ROOT}/kp_train_output_delta/"
echo "Use 'genophi assign-predict' locally to score cipher's OOD validation sets."
