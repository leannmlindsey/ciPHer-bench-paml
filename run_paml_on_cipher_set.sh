#!/usr/bin/env bash
# Drive PAML / GenoPHI inference on one cipher OOD K. pneumoniae validation set.
#
# Prerequisites (all should be present after the Delta training run lands):
#   kp_train_output_delta/strain/clusters.tsv
#   kp_train_output_delta/strain/features/feature_table.csv
#   kp_train_output_delta/strain/features/selected_features.csv
#   kp_train_output_delta/phage/features/feature_table.csv
#   kp_train_output_delta/tmp/strain/mmseqs_db   (the cluster representative DB)
#   kp_train_output_delta/tmp/phage/mmseqs_db
#   kp_train_output_delta/modeling_results/cutoff_10/  (trained CatBoost dir)
#
# Usage:
#   ./run_paml_on_cipher_set.sh DATASET BAC_FASTA_DIR PHAGE_FASTA_DIR
# Example:
#   ./run_paml_on_cipher_set.sh CHEN \
#       /Users/leannmlindsey/WORK/cipher_data/validation_genomes/CHEN/host_fastas_flat \
#       /Users/leannmlindsey/WORK/cipher_data/validation_genomes/CHEN/phages/per_phage_fastas

set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 DATASET BAC_FASTA_DIR PHAGE_FASTA_DIR" >&2
    exit 2
fi

DATASET="$1"
BAC_DIR="$2"
PHAGE_DIR="$3"

PAML_ROOT="$(cd "$(dirname "$0")" && pwd)"
TRAINED="${PAML_ROOT}/kp_train_output_delta"
OUT="${PAML_ROOT}/cipher_predictions/${DATASET}"
mkdir -p "${OUT}"

if [ ! -d "${TRAINED}" ]; then
    echo "ERROR: trained PAML model not found at ${TRAINED}" >&2
    echo "       run 04_transfer_results_back.sh after Delta finishes." >&2
    exit 1
fi

eval "$(conda shell.bash hook)"
conda activate genophi

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
