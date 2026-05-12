# Setup + reproduce

## 1. Clone upstream GenoPHI

```bash
# Wherever PAML_GENOPHI_REPO in your env points:
git clone https://github.com/Noonanav/GenoPHI.git "$PAML_GENOPHI_REPO"
```

## 2. Build the conda env

```bash
conda create -n genophi python=3.10 -y
conda activate genophi
conda install -y -c bioconda -c conda-forge mmseqs2 aria2
pip install genophi pyrodigal pyrodigal-gv biopython
```

## 3. Configure paths

```bash
# Pick the variant for your machine:
cp config/paml.env.template paml.env     # laptop
# or:
# cp config/paml_delta.env    paml.env
# cp config/paml_biowulf.env  paml.env

pico paml.env
source paml.env

# Sanity check:
echo "PAML_GENOPHI_REPO=$PAML_GENOPHI_REPO"
echo "PAML_TRAINED_MODEL=$PAML_TRAINED_MODEL"
echo "CIPHER_VAL_GENOMES=$CIPHER_VAL_GENOMES"
echo "CIPHER_REPO=$CIPHER_REPO"
```

## 4. Materialize training proteomes from cipher's Boeckaerts data

PAML needs full bacterial + phage proteomes (`.faa`) for training. The
200 strains + 105 phages live in cipher's Beamud and Ferriol subdirs:

```bash
source paml.env

mkdir -p train_inputs/strain_AAs train_inputs/phage_AAs

python predict_proteomes.py \
    --input_dir  "${CIPHER_VAL_GENOMES}/Beamud/bacteria" \
    --output_dir train_inputs/strain_AAs --kind bacteria --threads 8
python predict_proteomes.py \
    --input_dir  "${CIPHER_VAL_GENOMES}/Beamud/phages" \
    --output_dir train_inputs/phage_AAs --kind phage --threads 8

python predict_proteomes.py \
    --input_dir  "${CIPHER_VAL_GENOMES}/Ferriol/bacteria" \
    --output_dir train_inputs/strain_AAs --kind bacteria --threads 8
python predict_proteomes.py \
    --input_dir  "${CIPHER_VAL_GENOMES}/Ferriol/phages" \
    --output_dir train_inputs/phage_AAs --kind phage --threads 8
```

End state: 200 strain `.faa` files + 105 phage `.faa` files. Wall time
~25 s on an M2 / 8 cores.

## 5. Train on NCSA Delta (recommended)

**Local training is not recommended** — 1.04 M-protein all-vs-all
`mmseqs cluster -s 7.5` takes many hours on an 8-core laptop. Delta
finishes the same workflow in ~1–2 h on a 64-core CPU node.

```bash
# On laptop:
bash delta/01_transfer_to_delta.sh      # rsync inputs + scripts up

# On Delta:
ssh llindsey1@dt-login.delta.ncsa.illinois.edu
cd /projects/bfzj/llindsey1/PHI_TSP/ciPHer-comparisons/paml
bash 02_setup_env_on_delta.sh           # one-time conda env build
sbatch 03_train_paml.sbatch             # ~1–2 h walltime
squeue -u llindsey1                     # to check status

# After the job finishes, on laptop:
bash delta/04_transfer_results_back.sh
```

## 6. Run on cipher OOD validation sets

```bash
source paml.env
./run_paml_on_cipher_set.sh CHEN
./run_paml_on_cipher_set.sh UCSD
./run_paml_on_cipher_set.sh PBIP
./run_paml_on_cipher_set.sh Townsend
./run_paml_on_cipher_set.sh Jing
./run_paml_on_cipher_set.sh Wang
```

The driver:
1. Runs `predict_proteomes.py` on the dataset's bacteria + phages
2. Runs `genophi assign-features` for new strains → strain features
3. Runs `genophi assign-features` for new phages → phage features
4. Runs `genophi predict` for every (strain × phage) pair

Output: `cipher_predictions/<DATASET>/predictions/`

## 7. (Optional) In-distribution sanity check on PHL/Beamud + PHL/Ferriol

The trained model can also be run on the in-distribution cells
(PHL/Beamud, PHL/Ferriol). These should saturate, since the model was
trained on these phages. Use:

```bash
./run_paml_on_cipher_set.sh Beamud
./run_paml_on_cipher_set.sh Ferriol
```

Report these in the leaderboard with a clear `in-distribution` tag.
