#!/usr/bin/env python3
"""Generate a small synthetic known-sites VCF from a FASTA reference.

Picks random positions and creates a bgzipped, tabix-indexed VCF
suitable for GATK BQSR testing.
"""

import gzip
import random
import subprocess
import sys
from pathlib import Path

SEED = 42
NUM_VARIANTS = 200


def read_fasta(path):
    """Read FASTA and return dict of chrom -> sequence."""
    genome = {}
    current = None
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                current = line[1:].split()[0]
                genome[current] = []
            elif current:
                genome[current].append(line)
    return {k: "".join(v) for k, v in genome.items()}


def alt_base(ref):
    """Return a random alternative base."""
    bases = [b for b in "ACGT" if b != ref.upper()]
    return random.choice(bases)


def main():
    if len(sys.argv) < 2:
        print("Usage: simulate-known-sites.py <reference.fasta> [output_dir]")
        sys.exit(1)

    ref_path = sys.argv[1]
    out_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(ref_path).parent
    out_vcf = out_dir / "known_sites.vcf"
    out_gz = out_dir / "known_sites.vcf.gz"

    random.seed(SEED)
    genome = read_fasta(ref_path)

    # Generate random variant positions
    variants = []
    for chrom, seq in genome.items():
        n = max(1, int(NUM_VARIANTS * len(seq) / sum(len(s) for s in genome.values())))
        positions = sorted(random.sample(range(1, len(seq)), min(n, len(seq) - 1)))
        for pos in positions:
            ref = seq[pos - 1].upper()
            if ref in "ACGT":
                variants.append((chrom, pos, ref, alt_base(ref)))

    # Write VCF
    with open(out_vcf, "w") as f:
        f.write("##fileformat=VCFv4.2\n")
        f.write(f"##source=simulate-known-sites.py\n")
        for chrom, seq in genome.items():
            f.write(f"##contig=<ID={chrom},length={len(seq)}>\n")
        f.write("#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\n")
        for chrom, pos, ref, alt in sorted(variants):
            f.write(f"{chrom}\t{pos}\t.\t{ref}\t{alt}\t.\tPASS\t.\n")

    # bgzip and tabix
    subprocess.run(["bgzip", "-f", str(out_vcf)], check=True)
    subprocess.run(["tabix", "-p", "vcf", str(out_gz)], check=True)
    print(f"Created {out_gz} ({len(variants)} variants) + .tbi index")


if __name__ == "__main__":
    main()
