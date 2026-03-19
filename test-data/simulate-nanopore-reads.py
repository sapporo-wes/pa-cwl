#!/usr/bin/env python3
"""Generate simulated Nanopore reads for testing the nanoseq pipeline.
Creates a tiny reference genome and long reads with Nanopore-like error profiles.
"""
import gzip
import random
import sys
import os


# Tiny reference: 3 "chromosomes" with simple sequences
CHROMOSOMES = {
    "chr1": 5000,
    "chr2": 3000,
    "chr3": 2000,
}


def generate_genome(chrom_sizes, seed=42):
    """Generate random reference genome sequences."""
    rng = random.Random(seed)
    genome = {}
    for name, length in chrom_sizes.items():
        seq = []
        for _ in range(length):
            if rng.random() < 0.41:
                seq.append(rng.choice("GC"))
            else:
                seq.append(rng.choice("AT"))
        genome[name] = "".join(seq)
    return genome


def simulate_nanopore_read(genome_seq, chrom, rng, mean_len=2000, std_len=800,
                           error_rate=0.05):
    """Simulate a single Nanopore read with substitutions, insertions, deletions."""
    read_len = max(200, int(rng.gauss(mean_len, std_len)))
    if read_len > len(genome_seq):
        read_len = len(genome_seq)
    start = rng.randint(0, len(genome_seq) - read_len)
    frag = genome_seq[start:start + read_len]

    # Apply Nanopore-like errors
    read = []
    for base in frag:
        r = rng.random()
        if r < error_rate * 0.4:
            # Substitution
            read.append(rng.choice([b for b in "ACGT" if b != base]))
        elif r < error_rate * 0.7:
            # Deletion — skip base
            continue
        elif r < error_rate:
            # Insertion — add random base then current
            read.append(rng.choice("ACGT"))
            read.append(base)
        else:
            read.append(base)

    # Randomly reverse complement some reads
    if rng.random() < 0.5:
        comp = {"A": "T", "T": "A", "G": "C", "C": "G"}
        read = [comp[b] for b in reversed(read)]

    return "".join(read)


def simulate_quality(length, rng, mean_q=12, std_q=4):
    """Simulate Nanopore quality scores (generally lower than Illumina)."""
    quals = []
    for _ in range(length):
        q = max(2, min(30, int(rng.gauss(mean_q, std_q))))
        quals.append(chr(q + 33))
    return "".join(quals)


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    n_reads = int(sys.argv[2]) if len(sys.argv) > 2 else 500
    os.makedirs(outdir, exist_ok=True)

    rng = random.Random(42)

    # Generate reference
    genome = generate_genome(CHROMOSOMES)
    ref_path = os.path.join(outdir, "reference.fasta")
    with open(ref_path, "w") as f:
        for chrom, seq in genome.items():
            f.write(f">{chrom}\n")
            for i in range(0, len(seq), 80):
                f.write(seq[i:i+80] + "\n")
    print(f"Written: {ref_path} ({sum(CHROMOSOMES.values())} bp, "
          f"{len(CHROMOSOMES)} chromosomes)")

    # Generate reads
    records = []
    chroms = list(genome.keys())
    for i in range(n_reads):
        chrom = rng.choice(chroms)
        read_seq = simulate_nanopore_read(genome[chrom], chrom, rng)
        qual = simulate_quality(len(read_seq), rng)
        records.append(f"@read{i:06d} runid=sim ch={rng.randint(1,512)} "
                       f"start_time=2024-01-01T00:00:00Z\n"
                       f"{read_seq}\n+\n{qual}\n")

    fastq_path = os.path.join(outdir, "sample1_nanopore.fastq.gz")
    with gzip.open(fastq_path, "wt") as f:
        f.writelines(records)
    print(f"Written: {fastq_path} ({n_reads} reads)")


if __name__ == "__main__":
    main()
