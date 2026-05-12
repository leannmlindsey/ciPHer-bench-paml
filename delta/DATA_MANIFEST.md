# PAML Delta data manifest

What needs to be on Delta before the training sbatch will succeed,
and what additional data is needed for OOD inference on cipher's other
K. pneumoniae validation sets.

## Required for training (small — already handled by `01_transfer_to_delta.sh`)

| Source (laptop)                                                       | Destination on Delta                                                              | Size  |
|---|---|---|
| `paml_run/train_inputs/strain_AAs/`                                   | `/projects/bfzj/llindsey1/PHI_TSP/ciPHer-comparisons/paml/train_inputs/strain_AAs/` | 326 MB |
| `paml_run/train_inputs/phage_AAs/`                                    | same                                                                              | 2 MB   |
| `paml_run/train_inputs/kp_combined_interaction_matrix.csv`            | same                                                                              | 200 KB |
| This repo's `delta/` scripts                                          | `/projects/bfzj/llindsey1/PHI_TSP/ciPHer-comparisons/paml/delta/`                  | <100 KB|

**Total**: ~330 MB. The `01_transfer_to_delta.sh` script handles this.

## Required for OOD inference (uploaded AFTER training finishes)

For each cipher OOD K. pneumoniae validation set, `run_paml_on_cipher_set.sh`
needs the raw bacteria + phage FASTAs under
`${CIPHER_VAL_GENOMES}/${DATASET}/{bacteria,phages}/`.

Currently these live ONLY on the laptop at
`/Users/leannmlindsey/WORK/cipher_data/validation_genomes/<DS>/`.

| Dataset      | Bacteria | Phages | Total | Priority |
|---|---|---|---|---|
| CHEN         | 1.3 GB   | small  | ~1.3 GB | high (small, easy) |
| UCSD         | 834 MB   | small  | ~840 MB | high |
| PBIP         | 714 MB   | small  | ~720 MB | high |
| Townsend     | 164 KB   | 164 KB | tiny    | high — small + still needs benchmarking |
| Jing         | 18 MB    | 18 MB  | ~20 MB  | medium — blocked on Fig 3a transcription |
| Wang         | 16 GB    | (incl) | 16 GB   | low — big, may want to subset before transfer |
| Beamud       | 740 MB   | small  | ~740 MB | **already on Delta** as part of training |
| Ferriol      | 337 MB   | small  | ~340 MB | **already on Delta** as part of training |

Total OOD transfer needed: **~3 GB** for CHEN+UCSD+PBIP+Townsend+Jing
(skipping Wang since it's 16 GB and probably needs subsetting).

### Recommended approach

Either (a) pre-predict proteomes on the laptop and ship just the
`.faa` files (smaller, ~10× compression), or (b) ship raw FASTAs and
run `predict_proteomes.py` on Delta. (a) saves bandwidth but (b) keeps
the reproduction pipeline self-contained on Delta. For Wang specifically,
(a) is strongly preferred (16 GB → ~1 GB after ORF prediction).

## Transfer commands

```bash
# From laptop, transfer cipher_data per-dataset FASTAs to Delta.
# Skip Beamud + Ferriol (already on Delta as proteomes).
LOCAL=/Users/leannmlindsey/WORK/cipher_data/validation_genomes
DELTA=llindsey1@dt-login.delta.ncsa.illinois.edu:/projects/bfzj/llindsey1/PHI_TSP/cipher_data/validation_genomes

for ds in CHEN UCSD PBIP Townsend Jing; do
    rsync -avz --info=progress2 "${LOCAL}/${ds}/" "${DELTA}/${ds}/"
done

# Wang: ship only the subdirs we need (skip embeddings + intermediate analysis files)
rsync -avz --info=progress2 \
    "${LOCAL}/Wang/phage_genomes/" \
    "${LOCAL}/Wang/host_kp_genomes/" \
    "${LOCAL}/Wang/metadata/" \
    "${DELTA}/Wang/"
```
