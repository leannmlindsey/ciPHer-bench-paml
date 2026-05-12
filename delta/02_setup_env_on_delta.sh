#!/usr/bin/env bash
# Build the `genophi` conda env on Delta. Run once on a login node.
set -euo pipefail

ENV_NAME="genophi"

# Load Delta's conda/anaconda module
module load anaconda3_cpu 2>/dev/null || module load anaconda3 2>/dev/null || true

if conda env list | grep -q "^${ENV_NAME} "; then
    echo "Env '${ENV_NAME}' already exists. Updating in place."
else
    echo "Creating env '${ENV_NAME}' (python 3.10)..."
    conda create -y -n "${ENV_NAME}" python=3.10
fi

# Activate the env via the conda shell hook (login shells often don't have it sourced)
eval "$(conda shell.bash hook)"
conda activate "${ENV_NAME}"

echo "Installing mmseqs2 + aria2 from bioconda/conda-forge..."
conda install -y -c bioconda -c conda-forge mmseqs2 aria2

echo "Installing genophi (pip)..."
pip install --upgrade pip
pip install genophi

echo "Verifying:"
which mmseqs && mmseqs version
which genophi && genophi --version

echo
echo "OK. Activate later with:"
echo "  module load anaconda3_cpu && conda activate ${ENV_NAME}"
