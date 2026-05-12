#!/usr/bin/env bash
#SBATCH --job-name=paml_smoke
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --gpus-per-node=1
#SBATCH --mem=8G
#SBATCH --time=00:10:00
#SBATCH --output=logs/smoke.%j.out
#SBATCH --error=logs/smoke.%j.err

# Submit me FIRST, before delta/03_train_paml.sbatch. 5-minute job that
# proves the env + conda + mmseqs + genophi + data layout are all reachable.
# Submit:
#   source paml.env
#   sbatch --account="${ACCOUNT}" --partition="${PARTITION}" \
#          --gpus-per-node="${GPUS_PER_NODE}" delta/00_smoke_test.sbatch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [[ ! -f "${REPO_ROOT}/paml.env" ]]; then
    echo "FAIL: ${REPO_ROOT}/paml.env missing. cp config/paml_delta.env paml.env first." >&2
    exit 1
fi
# shellcheck disable=SC1091
source "${REPO_ROOT}/paml.env"

mkdir -p "${REPO_ROOT}/logs"

echo "============================================================"
echo "PAML smoke test"
echo "  hostname    : $(hostname)"
echo "  date        : $(date)"
echo "  partition   : ${SLURM_JOB_PARTITION:-unknown}"
echo "  account     : ${SLURM_JOB_ACCOUNT:-unknown}"
echo "  cpus        : ${SLURM_CPUS_PER_TASK:-unknown}"
echo "  gpus        : ${SLURM_GPUS_ON_NODE:-unknown}"
echo "  cpu arch    : $(uname -m)"
echo "============================================================"

# --- Conda activation -------------------------------------------------------
echo
echo "[1/5] Conda activation"
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${PAML_CONDA_ENV}"
echo "  active env: ${CONDA_DEFAULT_ENV}"
echo "  python:     $(python --version 2>&1)"

# --- Tool versions ----------------------------------------------------------
echo
echo "[2/5] Tool versions"
if command -v mmseqs >/dev/null 2>&1; then
    echo "  mmseqs:  $(mmseqs version 2>&1 | head -1)"
else
    echo "  FAIL: mmseqs not found in \$PATH. conda env may be missing the package." >&2
    exit 2
fi
if command -v genophi >/dev/null 2>&1; then
    echo "  genophi: $(genophi --version 2>&1 | head -1)"
else
    echo "  FAIL: genophi not found in \$PATH. pip install genophi inside conda env." >&2
    exit 2
fi
python -c "import pyrodigal; print(f'  pyrodigal: {pyrodigal.__version__}')" 2>&1
python -c "import pyrodigal_gv; print(f'  pyrodigal_gv: {pyrodigal_gv.__version__}')" 2>&1 || \
    echo "  pyrodigal_gv: NOT INSTALLED (only needed for ORF prediction on phages)"

# --- Data layout ------------------------------------------------------------
echo
echo "[3/5] Data layout"
: "${PAML_DATA_DIR:?PAML_DATA_DIR not set — paml.env broken}"
echo "  PAML_DATA_DIR     = ${PAML_DATA_DIR}"
echo "  PAML_GENOPHI_REPO = ${PAML_GENOPHI_REPO}"
echo "  CIPHER_VAL_GENOMES= ${CIPHER_VAL_GENOMES}"

if [[ ! -d "${PAML_DATA_DIR}" ]]; then
    echo "  FAIL: ${PAML_DATA_DIR} does not exist. Did you unzip the data zip?" >&2
    exit 3
fi

for f in train_inputs/strain_AAs train_inputs/phage_AAs train_inputs/kp_combined_interaction_matrix.csv; do
    if [[ -e "${PAML_DATA_DIR}/${f}" ]]; then
        N=$(ls -1 "${PAML_DATA_DIR}/${f}" 2>/dev/null | wc -l)
        echo "  OK : ${f}  ($([ -d "${PAML_DATA_DIR}/${f}" ] && echo "${N} entries" || echo "exists"))"
    else
        echo "  FAIL: missing ${PAML_DATA_DIR}/${f}" >&2
        exit 3
    fi
done

# --- Tiny mmseqs sanity ---------------------------------------------------
echo
echo "[4/5] Tiny mmseqs createdb on 5 strains"
SCRATCH="/scratch/${USER}/paml_smoke_${SLURM_JOB_ID:-noslurm}"
mkdir -p "${SCRATCH}"
FIRST5=$(ls "${PAML_DATA_DIR}/train_inputs/strain_AAs/"*.faa 2>/dev/null | head -5)
if [[ -z "${FIRST5}" ]]; then
    echo "  FAIL: no .faa under train_inputs/strain_AAs/" >&2
    exit 3
fi
cat ${FIRST5} > "${SCRATCH}/test.faa"
mmseqs createdb "${SCRATCH}/test.faa" "${SCRATCH}/test_db" -v 1 2>&1 | tail -3
rm -rf "${SCRATCH}"
echo "  OK"

# --- Final ----------------------------------------------------------------
echo
echo "[5/5] All smoke checks passed."
echo "Ready to submit:"
echo "  sbatch --account=\"\${ACCOUNT}\" --partition=\"\${PARTITION}\" \\"
echo "         --gpus-per-node=\"\${GPUS_PER_NODE}\" delta/03_train_paml.sbatch"
