"""Predict proteomes for genome FASTAs.

Bacteria → pyrodigal (single-genome mode)
Phages   → pyrodigal-gv (viral gene caller; falls back to pyrodigal meta if missing)

Input dir holds <name>.fasta files (nucleotide).
Output dir gets <name>.faa files (amino acid; ID = <name>_<orf_index>).
"""
import argparse, time
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed

import pyrodigal
try:
    import pyrodigal_gv
    HAS_GV = True
except ImportError:
    HAS_GV = False

from Bio import SeqIO


def _orf_predict(fasta_path: str, kind: str, out_path: str) -> tuple[str, int]:
    """Predict ORFs for one FASTA file. Returns (name, n_proteins)."""
    name = Path(fasta_path).stem
    if kind == "bacteria":
        orf = pyrodigal.GeneFinder(meta=False)
        seqs = [str(r.seq) for r in SeqIO.parse(fasta_path, "fasta")]
        combined = "".join(seqs)
        orf.train(combined)
        n = 0
        with open(out_path, "w") as fh:
            for i, rec in enumerate(SeqIO.parse(fasta_path, "fasta")):
                genes = orf.find_genes(str(rec.seq))
                for g in genes:
                    n += 1
                    fh.write(f">{name}_{n}\n{g.translate()}\n")
        return name, n
    else:  # phage
        if HAS_GV:
            orf = pyrodigal_gv.ViralGeneFinder(meta=True)
        else:
            orf = pyrodigal.GeneFinder(meta=True)
        n = 0
        with open(out_path, "w") as fh:
            for rec in SeqIO.parse(fasta_path, "fasta"):
                genes = orf.find_genes(str(rec.seq))
                for g in genes:
                    n += 1
                    fh.write(f">{name}_{n}\n{g.translate()}\n")
        return name, n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input_dir", required=True)
    ap.add_argument("--output_dir", required=True)
    ap.add_argument("--kind", required=True, choices=["bacteria", "phage"])
    ap.add_argument("--threads", type=int, default=4)
    args = ap.parse_args()

    in_dir = Path(args.input_dir)
    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    inputs = sorted(in_dir.glob("*.fasta")) + sorted(in_dir.glob("*.fa")) + sorted(in_dir.glob("*.fna"))
    print(f"[{args.kind}] {len(inputs)} input genomes → {out_dir}")

    t0 = time.time()
    done, total_prot = 0, 0
    with ProcessPoolExecutor(max_workers=args.threads) as pool:
        futures = {pool.submit(_orf_predict, str(p), args.kind, str(out_dir/(p.stem+".faa"))): p for p in inputs}
        for fut in as_completed(futures):
            name, n = fut.result()
            done += 1
            total_prot += n
            if done % 25 == 0 or done == len(inputs):
                print(f"  [{done}/{len(inputs)}]  {name}: {n} proteins  ({time.time()-t0:.1f}s)", flush=True)
    print(f"[{args.kind}] done — {total_prot} total proteins in {time.time()-t0:.1f}s")


if __name__ == "__main__":
    main()
