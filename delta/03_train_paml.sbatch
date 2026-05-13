#!/usr/bin/env bash
#SBATCH --job-name=paml_kp_train
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gpus-per-node=1
#SBATCH --mem=240G
#SBATCH --time=04:00:00
#SBATCH --output=logs/paml_kp_train.%j.out
#SBATCH --error=logs/paml_kp_train.%j.err

# One-shot PAML / GenoPHI training on combined Beamud + Ferriol
# K. pneumoniae panels (200 strains × 105 phages, 10,006 labeled pairs).
#
# Runs on DeltaAI GPU partition (ghx4) — the only allocation our bfzj
# account has access to. PAML's workload is CPU-bound (mmseqs2 + CatBoost),
# so the GPU sits idle, but we still need to request one per ghx4 policy.
# ghx4 nodes have 64 cores per GH200 superchip; we ask for 16 to leave
# room for other jobs on the shared node.
#
# SLURM allocation + partition come from paml.env at submission time.
# Submit:
#   source paml.env
#   sbatch --account="${ACCOUNT}" --partition="${PARTITION}" \
#          --gpus-per-node="${GPUS_PER_NODE}" \
#          delta/03_train_paml.sbatch
#
# Parallelism: --threads $NCPUS is forwarded by genophi to every mmseqs2
# invocation (createdb, cluster, search, align) AND to CatBoost
# thread_count for RFE feature selection + final model training.

set -euo pipefail

# --- Auto-source paml.env from the repo root (matches cipher's idiom) ---
# Resolve REPO_ROOT relative to this sbatch's location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [[ -f "${REPO_ROOT}/paml.env" ]]; then
    # shellcheck disable=SC1091
    source "${REPO_ROOT}/paml.env"
else
    echo "ERROR: ${REPO_ROOT}/paml.env not found." >&2
    echo "  Copy config/paml_delta.env to paml.env first." >&2
    exit 1
fi

: "${PAML_CONDA_ENV:?source paml.env first}"
: "${PAML_DATA_DIR:?source paml.env first (PAML_DATA_DIR should point at <repo>/data)}"

mkdir -p "${REPO_ROOT}/logs"
cd "${REPO_ROOT}"

# --- Conda activation ----------------------------------------------------
if [[ -z "${CONDA_EXE:-}" ]] && command -v conda >/dev/null 2>&1; then
    CONDA_EXE="$(command -v conda)"
fi
if [[ -z "${CONDA_EXE:-}" ]]; then
    echo "ERROR: conda not found. Install Miniforge first (see SETUP.md)." >&2
    exit 1
fi
# shellcheck disable=SC1091
source "$(dirname "${CONDA_EXE}")/../etc/profile.d/conda.sh"
conda activate "${PAML_CONDA_ENV}"

echo "[env] hostname    = $(hostname)"
echo "[env] cpus        = ${SLURM_CPUS_PER_TASK:-N/A}"
echo "[env] account     = ${SLURM_JOB_ACCOUNT:-N/A}"
echo "[env] partition   = ${SLURM_JOB_PARTITION:-N/A}"
echo "[env] mmseqs      = $(which mmseqs)  $(mmseqs version 2>/dev/null | head -1)"
echo "[env] genophi     = $(which genophi)  $(genophi --version 2>&1 | head -1)"
echo "[env] start       = $(date)"

NCPUS="${SLURM_CPUS_PER_TASK:-64}"

# --- Workspace ----------------------------------------------------------
# mmseqs2 generates ~10 GB of intermediates — keep them on node-local fast
# scratch, not on Lustre/projects.
SCRATCH="/scratch/${USER}/paml_kp_${SLURM_JOB_ID:-noslurm}"
mkdir -p "${SCRATCH}"
echo "[workspace] run_root = ${REPO_ROOT}"
echo "[workspace] scratch  = ${SCRATCH}"

# --- Sanity check the inputs exist before launching mmseqs --------------
for f in train_inputs/strain_AAs train_inputs/phage_AAs train_inputs/kp_combined_interaction_matrix.csv; do
    if [[ ! -e "${PAML_DATA_DIR}/${f}" ]]; then
        echo "ERROR: missing required input: ${PAML_DATA_DIR}/${f}" >&2
        echo "  Did you unzip ciPHer-bench-paml-data.zip into ${PAML_DATA_DIR}? See SETUP.md." >&2
        exit 1
    fi
done

# --- Workflow -----------------------------------------------------------
# Outputs land under ${PAML_DATA_DIR}/kp_train_output so they're alongside
# the inputs (and naturally pulled back by 04_transfer_results_back.sh).
genophi protein-family-workflow \
    --input_path_strain  "${PAML_DATA_DIR}/train_inputs/strain_AAs/" \
    --input_path_phage   "${PAML_DATA_DIR}/train_inputs/phage_AAs/" \
    --phenotype_matrix   "${PAML_DATA_DIR}/train_inputs/kp_combined_interaction_matrix.csv" \
    --output_dir         "${PAML_DATA_DIR}/kp_train_output/" \
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
if [[ -d "${PAML_DATA_DIR}/kp_train_output/tmp" ]]; then
    echo "[cleanup] removing kp_train_output/tmp (mmseqs intermediates)"
    rm -rf "${PAML_DATA_DIR}/kp_train_output/tmp"
fi
rm -rf "${SCRATCH}" || true

echo "[done] $(date)"
echo "Outputs under: ${PAML_DATA_DIR}/kp_train_output/"
ls -lh "${PAML_DATA_DIR}/kp_train_output/" 2>/dev/null | head
