# Setup + reproduce

## Workflow at a glance

```text
1. (on laptop) build data zip      → ciPHer-bench-paml-data.zip  (~368 MB)
2. (on laptop) rsync zip to Delta
3. (on Delta) unzip into data/
4. (on Delta) source paml.env, build conda env, sbatch
5. (on laptop) pull results back
```

## 1. Build the data zip on the laptop

```bash
cd /Users/leannmlindsey/Desktop/ciPHer-bench-staging/ciPHer-bench-paml
bash build_data_zip.sh
# Output: /Users/leannmlindsey/Desktop/ciPHer-bench-data-zips/ciPHer-bench-paml-data.zip
```

The zip contains:
- `data/train_inputs/strain_AAs/` — 200 K. pneumoniae bacterial proteomes (.faa)
- `data/train_inputs/phage_AAs/` — 105 phage proteomes (.faa)
- `data/train_inputs/kp_combined_interaction_matrix.csv` — 10,006-row label matrix
- `data/GenoPHI/` — upstream GenoPHI clone (so Delta install doesn't need
  internet for the `git clone`)

OOD validation genomes (CHEN/UCSD/PBIP/Townsend/Jing/Wang) are NOT in this
zip — those need a separate normalization pass and a second zip later.

## 2. Clone the repo on Delta + transfer the zip

```bash
# On laptop:
bash delta/01_transfer_to_delta.sh
```

This `ssh`'s to Delta, ensures the target dir exists, and rsyncs the zip up.

## 3. Unzip on Delta

```bash
ssh llindsey1@dt-login.delta.ncsa.illinois.edu
cd /projects/bfzj/llindsey1/PHI_TSP/ciPHer-comparisons/paml

# First time only — clone the repo:
git clone git@github.com:LeAnnMLindsey/ciPHer-bench-paml.git .

# Unzip into data/:
cd data
unzip -q ciPHer-bench-paml-data.zip
cd ..
```

## 4. Configure env + install conda + submit

```bash
cp config/paml_delta.env paml.env
source paml.env

# One-time conda env build (~5 min):
bash delta/02_setup_env_on_delta.sh

# Submit the training job:
sbatch --account="${ACCOUNT}" --partition="${PARTITION}" \
       --gpus-per-node="${GPUS_PER_NODE}" delta/03_train_paml.sbatch

# Monitor:
squeue -u llindsey1
tail -f logs/paml_kp_train.*.out
```

DeltaAI uses GPU partition `ghx4` exclusively (no Delta CPU allocation
under our `bfzj` account). PAML is CPU-bound (mmseqs2 + CatBoost), so
the requested GPU sits idle, but that's the trade-off for running on
the available allocation.

## 5. Pull results back to laptop

```bash
# On laptop, after the job finishes:
bash delta/04_transfer_results_back.sh
```

The trained model + clusters + feature tables land at
`paml_run/kp_train_output_delta/` on the laptop.

## 6. OOD inference (after training)

```bash
# On laptop, with the trained model in place:
source paml.env
./run_paml_on_cipher_set.sh CHEN          # needs per-dataset FASTAs
```

Note: the OOD wrappers need the per-dataset bacteria + phage FASTAs at
`${CIPHER_VAL_GENOMES}/<DS>/{bacteria,phages}/`, which are NOT included
in the training data zip. Either:
- Run the wrappers on the laptop (cipher_data already has them), or
- Build a second zip with normalized OOD validation_genomes/ layout
  and transfer to Delta.
