# ciPHer-bench-paml

Reproducible wrapper around **GenoPHI** (the public Python package for
the PAML method from Noonan et al. 2025, *"Phylogeny-agnostic strain-level
prediction of phage-host interactions from genomes,"* ResearchSquare
preprint 10.21203/rs.3.rs-8176565/v1) for evaluation on cipher's
K. pneumoniae validation panel.

**Important contamination caveat.** GenoPHI's bundled `klebsiella1` and
`klebsiella2` interaction matrices are **identical** to cipher's
PHL/Ferriol (59 phages × 62 strains) and PHL/Beamud (46 phages × 138
strains) subsets respectively (100 % phage-name overlap). So a PAML
model trained on those matrices is **in-distribution** for cipher's
PHL/Beamud and PHL/Ferriol cells and **out-of-distribution** for cipher's
CHEN / GORODNICHIV / UCSD / PBIP / Townsend / Jing / Wang cells. Report
the OOD cells in the manuscript; tag the in-distribution cells as such.

## What this repo does NOT contain
- GenoPHI source (clone separately — see SETUP.md)
- Trained model checkpoints (run training yourself — see SETUP.md)
- Bacterial / phage `.faa` proteomes (regenerated on demand)

## What this repo DOES contain
- `predict_proteomes.py` — pyrodigal-based ORF caller for bacteria + phages
- `delta/` — NCSA Delta SLURM scripts for one-shot training on 64 cores
- `run_paml_on_cipher_set.sh` — driver that runs the trained model on any
  cipher OOD K. pneumoniae validation set
- `train_inputs/kp_combined_interaction_matrix.csv` — cleaned, merged
  labels for the 200 × 105 K. pneumoniae training panel

## Quick start
See [SETUP.md](SETUP.md).
```

### Add `SETUP.md`

```markdown
# Setup + reproduce

## 1. Clone upstream GenoPHI

```bash
git clone https://github.com/Noonanav/GenoPHI.git
```

## 2. Build the conda env

```bash
conda create -n genophi python=3.10 -y
conda activate genophi
conda install -y -c bioconda -c conda-forge mmseqs2 aria2
pip install genophi pyrodigal pyrodigal-gv biopython
```

## 3. Materialize training proteomes from cipher's Boeckaerts data

You need the Beamud (138 bacteria, 46 phages) and Ferriol (62 bacteria,
59 phages) genome FASTAs from cipher. On the laptop they live at:

```
/Users/leannmlindsey/WORK/cipher_data/validation_genomes/Beamud/{bacteria,phages}/
/Users/leannmlindsey/WORK/cipher_data/validation_genomes/Ferriol/{bacteria,phages}/
```

Predict full proteomes (~25 s on M2 / 8 cores):

```bash
mkdir -p train_inputs/strain_AAs train_inputs/phage_AAs
for src in Beamud Ferriol; do
    python predict_proteomes.py \
        --input_dir  /path/to/cipher_data/validation_genomes/$src/bacteria \
        --output_dir train_inputs/strain_AAs --kind bacteria --threads 8
    python predict_proteomes.py \
        --input_dir  /path/to/cipher_data/validation_genomes/$src/phages \
        --output_dir train_inputs/phage_AAs   --kind phage    --threads 8
done
```

## 4. Train on NCSA Delta (recommended) or locally

**Delta (one-shot, ~1–2 h on 64 cores):**

```bash
bash delta/01_transfer_to_delta.sh
ssh llindsey1@dt-login.delta.ncsa.illinois.edu
cd /u/llindsey1/llindsey/PHI_TSP/ciPHer-comparisons/paml
bash 02_setup_env_on_delta.sh   # one-time
sbatch 03_train_paml.sbatch
```

After the job finishes:

```bash
# (back on laptop)
bash delta/04_transfer_results_back.sh
```

**Locally:** not recommended — 1.04 M-protein all-vs-all mmseqs alignment
takes many hours on 8 cores.

## 5. Run on cipher OOD validation sets

```bash
./run_paml_on_cipher_set.sh CHEN \
    /path/to/cipher_data/validation_genomes/CHEN/host_fastas_flat \
    /path/to/cipher_data/validation_genomes/CHEN/phages/per_phage_fastas
```

Repeat for UCSD, PBIP, Townsend, Jing, Wang.
