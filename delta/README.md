# PAML / GenoPHI on NCSA Delta — one-shot Klebsiella training

Local laptop choked on the all-vs-all `mmseqs cluster -s 7.5` over 1.04 M
strain proteins (only 8 cores). The same workflow runs in ~1-2 h on a
single 64-core Delta CPU node. This directory holds everything needed
to lift-and-shift.

## Pieces

1. `01_transfer_to_delta.sh` — one-time rsync of inputs + scripts up
   to `/u/llindsey1/llindsey/PHI_TSP/ciPHer-comparisons/paml/`
2. `02_setup_env_on_delta.sh` — run on Delta login node once;
   builds the `genophi` conda env (genophi pip + mmseqs2 bioconda)
3. `03_train_paml.sbatch` — the one-shot SLURM job:
   - 64 cores (cpu partition, full node, `--exclusive`)
   - 256 GB RAM
   - 4 h walltime (generous, expecting ~1-2 h)
   - `mmseqs` tmp dir on local node `/scratch/llindsey1/...`
     to avoid Lustre I/O latency
   - Forwards `--threads 64` end-to-end (genophi correctly propagates
     this to all mmseqs2 invocations and CatBoost `thread_count`)
4. `04_transfer_results_back.sh` — pull the trained model + logs
   back to the laptop after the job finishes

## What ships
- 200 strain `.faa` (~150 MB) + 105 phage `.faa` (~5 MB) — already on
  laptop in `paml_run/train_inputs/`
- `kp_combined_interaction_matrix.csv` (200 KB)
- This entire `delta/` subdir
- No private weights, no checkpoints, no cipher RBP data

## After it lands
- Pull back the trained CatBoost model + the MMseqs2 `clusters.tsv`
  and `feature_table.csv`. With those, `genophi assign-predict` runs
  in <1 h on the laptop for each cipher OOD set — that work doesn't
  need Delta.
