# ciPHer-bench-paml

Reproducible wrapper around **GenoPHI** (the public Python package for
the PAML method from Noonan et al. 2025, *"Phylogeny-agnostic strain-level
prediction of phage-host interactions from genomes,"* ResearchSquare
preprint 10.21203/rs.3.rs-8176565/v1) for evaluation on ciPHer's
K. pneumoniae validation panel.

Upstream: https://github.com/Noonanav/GenoPHI

**Important contamination caveat.** GenoPHI's bundled `klebsiella1` and
`klebsiella2` interaction matrices are **identical** to cipher's
PHL/Ferriol (59 phages × 62 strains) and PHL/Beamud (46 phages × 138
strains) subsets respectively (100 % phage-name overlap). So a PAML
model trained on those matrices is **in-distribution** for cipher's
PHL/Beamud and PHL/Ferriol cells and **out-of-distribution** for cipher's
CHEN / GORODNICHIV / UCSD / PBIP / Townsend / Jing / Wang cells. Report
the OOD cells in the manuscript; tag the in-distribution cells as such.

## What this repo contains

- `predict_proteomes.py` — pyrodigal-based ORF caller for bacteria + phages
- `delta/` — NCSA Delta SLURM scripts for one-shot training on 64 cores
  (`01_transfer_to_delta.sh`, `02_setup_env_on_delta.sh`,
  `03_train_paml.sbatch`, `04_transfer_results_back.sh`)
- `run_paml_on_cipher_set.sh` — driver that runs the trained model on
  any cipher OOD K. pneumoniae validation set
- `train_inputs/kp_combined_interaction_matrix.csv` — cleaned, merged
  labels for the 200 × 105 K. pneumoniae training panel
  (= klebsiella1 + klebsiella2 from upstream)
- `config/paml.env.template` — env file template; copy to `paml.env`
  and edit before running any wrapper

## What this repo does NOT contain

- GenoPHI source (clone separately — see [SETUP.md](SETUP.md))
- Trained model checkpoints (run training yourself — see [SETUP.md](SETUP.md))
- Bacterial / phage `.faa` proteomes (regenerated on demand by
  `predict_proteomes.py`)

## Quick start

```bash
git clone https://github.com/LeAnnMLindsey/ciPHer-bench-paml.git
cd ciPHer-bench-paml

# 1. Pick the env config for your machine:
cp config/paml.env.template paml.env     # laptop
# or:
# cp config/paml_delta.env    paml.env   # NCSA Delta
# cp config/paml_biowulf.env  paml.env   # NIH Biowulf

# 2. Edit paths + source:
pico paml.env
source paml.env

# 3. See SETUP.md for upstream clone + env install + training
```

See [SETUP.md](SETUP.md) for full setup.

## Citation

If you use this wrapper, please cite both:
- Noonan AJC, Moriniere L, et al. *Phylogeny-agnostic strain-level
  prediction of phage-host interactions from genomes.* ResearchSquare
  preprint, 2025. https://doi.org/10.21203/rs.3.rs-8176565/v1
- (manuscript in prep) ciPHer benchmarking paper, LeAnn M. Lindsey et al.
