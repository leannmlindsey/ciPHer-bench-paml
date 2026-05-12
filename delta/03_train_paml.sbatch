#!/usr/bin/env bash
#SBATCH --job-name=paml_kp_train
#SBATCH --account=bfzj-delta-cpu
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --exclusive
#SBATCH --mem=240G
#SBATCH --time=04:00:00
#SBATCH --output=logs/paml_kp_train.%j.out
#SBATCH --error=logs/paml_kp_train.%j.err

# One-shot PAML / GenoPHI training on combined Beamud + Ferriol
# K. pneumoniae panels (200 strains × 105 phages, 10,006 labeled pairs).
#
# Parallelism: --threads $NCPUS is forwarded by genophi to every mmseqs2
# invocation (createdb, cluster, search, align) AND to CatBoost
# thread_count for RFE feature selection + final model training.

set -euo pipefail
mkdir -p logs

# --- Environment ---------------------------------------------------------
module load anaconda3_cpu 2>/dev/null || module load anaconda3 2>/dev/null || true
eval "$(conda shell.bash hook)"
conda activate genophi

echo "[env] hostname    = $(hostname)"
echo "[env] cpus        = ${SLURM_CPUS_PER_TASK}"
echo "[env] mem         = ${SLURM_MEM_PER_NODE} MB"
echo "[env] mmseqs      = $(which mmseqs)  $(mmseqs version 2>/dev/null | head -1)"
echo "[env] genophi     = $(which genophi)  $(genophi --version)"
echo "[env] start       = $(date)"

NCPUS="${SLURM_CPUS_PER_TASK:-64}"

# --- Workspace ----------------------------------------------------------
RUN_ROOT="$(pwd)"
# mmseqs2 generates ~10 GB of intermediates — keep them on node-local fast
# scratch, not on Lustre/projects.
SCRATCH="/scratch/${USER}/paml_kp_${SLURM_JOB_ID:-noslurm}"
mkdir -p "${SCRATCH}"
echo "[workspace] run_root = ${RUN_ROOT}"
echo "[workspace] scratch  = ${SCRATCH}"

# --- Workflow -----------------------------------------------------------
cd "${RUN_ROOT}"

# protein-family-workflow is the same command we ran locally. The only
# differences are --threads (8 → ${NCPUS}) and the explicit --tmp_dir
# pointing at node-local scratch.
genophi protein-family-workflow \
    --input_path_strain  train_inputs/strain_AAs/ \
    --input_path_phage   train_inputs/phage_AAs/ \
    --phenotype_matrix   train_inputs/kp_combined_interaction_matrix.csv \
    --output_dir         kp_train_output/ \
    --tmp_dir            "${SCRATCH}/tmp" \
    --threads            "${NCPUS}" \
    --num_features       100 \
    --num_runs_fs        5 \
    --num_runs_modeling  10 \
    --method             rfe \
    --filter_type        strain

echo "[workflow] genophi exit = $?"
echo "[workflow] end          = $(date)"

# --- Cleanup ------------------------------------------------------------
# Keep clusters.tsv + feature_table.csv + model dir; throw away the mmseqs
# intermediates (~10 GB) to keep the project quota happy.
if [ -d "kp_train_output/tmp" ]; then
    echo "[cleanup] removing kp_train_output/tmp (mmseqs intermediates)"
    rm -rf kp_train_output/tmp
fi
rm -rf "${SCRATCH}" || true

echo "[done] $(date)"
echo "Outputs under: ${RUN_ROOT}/kp_train_output/"
ls -lh kp_train_output/ 2>/dev/null | head
