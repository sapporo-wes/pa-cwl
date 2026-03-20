#!/usr/bin/env python3
"""Generate simulated paired-end RNA-seq reads from a genome FASTA.
Produces small FASTQ files (~10K read pairs) for lightweight testing.
"""
import gzip
import random
import sys

def read_fasta(filepath):
    """Read FASTA file, return dict of {seqname: sequence}."""
    seqs = {}
    current = None
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                current = line[1:].split()[0]
                seqs[current] = []
            elif current:
                seqs[current].append(line)
    return {k: "".join(v) for k, v in seqs.items()}

def reverse_complement(seq):
    comp = {"A": "T", "T": "A", "G": "C", "C": "G", "N": "N"}
    return "".join(comp.get(b, "N") for b in reversed(seq))

def simulate_reads(genome, n_reads=10000, read_length=100, fragment_size=250):
    """Simulate paired-end reads from genome sequences."""
    random.seed(42)
    chroms = list(genome.keys())
    chrom_weights = [len(genome[c]) for c in chroms]
    total_len = sum(chrom_weights)

    reads_r1 = []
    reads_r2 = []

    for i in range(n_reads):
        # Pick random chromosome weighted by length
        r = random.randint(0, total_len - 1)
        cumulative = 0
        chrom = chroms[0]
        for c, w in zip(chroms, chrom_weights):
            cumulative += w
            if r < cumulative:
                chrom = c
                break

        seq = genome[chrom]
        max_start = len(seq) - fragment_size
        if max_start < 1:
            continue

        start = random.randint(0, max_start)
        fragment = seq[start:start + fragment_size]

        r1_seq = fragment[:read_length].upper()
        r2_seq = reverse_complement(fragment[-read_length:]).upper()

        # Skip reads with too many Ns
        if r1_seq.count("N") > 5 or r2_seq.count("N") > 5:
            continue

        qual = "I" * read_length  # Phred 40
        read_name = f"@sim_{i:06d} {chrom}:{start}"

        reads_r1.append(f"{read_name}/1\n{r1_seq}\n+\n{qual}\n")
        reads_r2.append(f"{read_name}/2\n{r2_seq}\n+\n{qual}\n")

    return reads_r1, reads_r2

def main():
    genome_fasta = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else "."
    n_reads = int(sys.argv[3]) if len(sys.argv) > 3 else 10000

    print(f"Reading genome: {genome_fasta}")
    genome = read_fasta(genome_fasta)
    print(f"  {len(genome)} chromosomes, {sum(len(s) for s in genome.values()):,} bp total")

    print(f"Simulating {n_reads} paired-end reads...")
    r1, r2 = simulate_reads(genome, n_reads=n_reads)
    print(f"  Generated {len(r1)} read pairs")

    r1_path = f"{outdir}/yeast_sim_R1.fastq.gz"
    r2_path = f"{outdir}/yeast_sim_R2.fastq.gz"

    with gzip.open(r1_path, "wt") as f:
        f.writelines(r1)
    with gzip.open(r2_path, "wt") as f:
        f.writelines(r2)

    print(f"Written: {r1_path}, {r2_path}")

if __name__ == "__main__":
    main()
