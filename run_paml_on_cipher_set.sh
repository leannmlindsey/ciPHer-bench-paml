#!/usr/bin/env bash
# Drive PAML / GenoPHI inference on one cipher OOD K. pneumoniae validation set.
#
# Paths come from paml.env — source it first:
#   cp config/paml.env.template paml.env        # or _delta / _biowulf variant
#   pico paml.env  ; source paml.env
#
# Required env vars (see paml.env):
#   PAML_TRAINED_MODEL   trained model dir from the Delta training run
#   CIPHER_VAL_GENOMES   parent dir of cipher's per-dataset validation_genomes/
#   PAML_CONDA_ENV       conda env name (default: genophi)
#
# Prerequisites under $PAML_TRAINED_MODEL:
#   strain/clusters.tsv
#   strain/features/feature_table.csv
#   strain/features/selected_features.csv
#   phage/features/feature_table.csv
#   tmp/strain/mmseqs_db
#   tmp/phage/mmseqs_db
#   modeling_results/cutoff_10/  (trained CatBoost dir)
#
# Usage:
#   source paml.env
#   ./run_paml_on_cipher_set.sh DATASET
# Example:
#   ./run_paml_on_cipher_set.sh CHEN
#   ./run_paml_on_cipher_set.sh PBIP
# Per-dataset bacteria/phage FASTAs are resolved as:
#   $CIPHER_VAL_GENOMES/$DATASET/bacteria/ and $CIPHER_VAL_GENOMES/$DATASET/phages/

set -euo pipefail

: "${PAML_TRAINED_MODEL:?source paml.env first}"
: "${CIPHER_VAL_GENOMES:?source paml.env first}"
PAML_CONDA_ENV="${PAML_CONDA_ENV:-genophi}"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 DATASET  [BAC_FASTA_DIR  PHAGE_FASTA_DIR]" >&2
    echo "  DATASET: CHEN | UCSD | PBIP | Townsend | Jing | Wang | GORODNICHIV" >&2
    echo "  BAC/PHAGE_FASTA_DIR: override if not at \$CIPHER_VAL_GENOMES/\$DATASET/{bacteria,phages}/" >&2
    exit 2
fi

DATASET="$1"
BAC_DIR="${2:-${CIPHER_VAL_GENOMES}/${DATASET}/bacteria}"
PHAGE_DIR="${3:-${CIPHER_VAL_GENOMES}/${DATASET}/phages}"

PAML_ROOT="$(cd "$(dirname "$0")" && pwd)"
TRAINED="${PAML_TRAINED_MODEL}"
OUT="${PAML_ROOT}/cipher_predictions/${DATASET}"
mkdir -p "${OUT}"

if [ ! -d "${TRAINED}" ]; then
    echo "ERROR: trained PAML model not found at ${TRAINED}" >&2
    echo "       (PAML_TRAINED_MODEL env var; run delta/04_transfer_results_back.sh after Delta finishes)" >&2
    exit 1
fi

eval "$(conda shell.bash hook)"
conda activate "${PAML_CONDA_ENV}"

# -- 1. Proteomes for the new bacteria + phages -----------------------------
echo "[1/4] Predicting proteomes for ${DATASET}"
mkdir -p "${OUT}/strain_AAs" "${OUT}/phage_AAs"
python "${PAML_ROOT}/predict_proteomes.py" \
    --input_dir "${BAC_DIR}"  --output_dir "${OUT}/strain_AAs" \
    --kind bacteria --threads 8
python "${PAML_ROOT}/predict_proteomes.py" \
    --input_dir "${PHAGE_DIR}" --output_dir "${OUT}/phage_AAs" \
    --kind phage --threads 8

# -- 2. Assign new bacteria to existing strain clusters ---------------------
echo "[2/4] Assigning ${DATASET} bacteria to PAML strain clusters"
genophi assign-features \
    --input_dir   "${OUT}/strain_AAs/" \
    --mmseqs_db   "${TRAINED}/tmp/strain/mmseqs_db" \
    --clusters_tsv "${TRAINED}/strain/clusters.tsv" \
    --feature_map  "${TRAINED}/strain/features/selected_features.csv" \
    --tmp_dir     "${OUT}/tmp_strain" \
    --output_dir  "${OUT}/strain_features" \
    --genome_type strain \
    --threads     8

# -- 3. Assign new phages to existing phage clusters ------------------------
echo "[3/4] Assigning ${DATASET} phages to PAML phage clusters"
genophi assign-features \
    --input_dir   "${OUT}/phage_AAs/" \
    --mmseqs_db   "${TRAINED}/tmp/phage/mmseqs_db" \
    --clusters_tsv "${TRAINED}/phage/clusters.tsv" \
    --feature_map  "${TRAINED}/strain/features/selected_features.csv" \
    --tmp_dir     "${OUT}/tmp_phage" \
    --output_dir  "${OUT}/phage_features" \
    --genome_type phage \
    --threads     8

# -- 4. Cross-predict every (new strain, new phage) pair --------------------
echo "[4/4] Predicting (${DATASET} strain × ${DATASET} phage) pairs"
genophi predict \
    --input_dir            "${OUT}/strain_features" \
    --phage_feature_table  "${OUT}/phage_features/feature_table.csv" \
    --model_dir            "${TRAINED}/modeling_results/cutoff_10" \
    --output_dir           "${OUT}/predictions" \
    --threads              8

echo "Done. Predictions at: ${OUT}/predictions/"
ls -lh "${OUT}/predictions/" 2>/dev/null | head
