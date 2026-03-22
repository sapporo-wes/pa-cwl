#!/usr/bin/env python3
"""Generate simulated tumor paired-end reads with known somatic SNV mutations.

Reads the yeast genome, introduces ~20 random SNVs, simulates paired-end reads
from the mutated genome, and outputs a truth VCF listing the mutations.
Designed to pair with the existing yeast_sim_R1/R2.fastq.gz as the "normal" sample
for somatic calling (e.g., Mutect2) testing.
"""
import gzip
import random
import sys
import os
from datetime import date


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


def introduce_mutations(genome, n_mutations=20, seed=123):
    """Introduce random SNV mutations into the genome.

    Returns:
        mutated_genome: dict of {chrom: mutated_sequence}
        mutations: list of (chrom, pos_0based, ref, alt) tuples
    """
    random.seed(seed)
    bases = ["A", "C", "G", "T"]

    # Collect eligible positions (only canonical bases, avoid edges)
    eligible = []
    for chrom, seq in genome.items():
        for i in range(100, len(seq) - 100):
            if seq[i].upper() in bases:
                eligible.append((chrom, i))

    # Pick random positions for mutations
    selected = sorted(random.sample(eligible, n_mutations))

    # Apply mutations
    mutated_genome = {k: list(v) for k, v in genome.items()}
    mutations = []
    for chrom, pos in selected:
        ref = mutated_genome[chrom][pos].upper()
        alt_choices = [b for b in bases if b != ref]
        alt = random.choice(alt_choices)
        mutated_genome[chrom][pos] = alt
        mutations.append((chrom, pos, ref, alt))

    mutated_genome = {k: "".join(v) for k, v in mutated_genome.items()}
    return mutated_genome, mutations


def simulate_reads(genome, n_reads=500, read_length=150, fragment_size=300):
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
        read_name = f"@tumor_sim_{i:06d} {chrom}:{start}"

        reads_r1.append(f"{read_name}/1\n{r1_seq}\n+\n{qual}\n")
        reads_r2.append(f"{read_name}/2\n{r2_seq}\n+\n{qual}\n")

    return reads_r1, reads_r2


def write_truth_vcf(mutations, genome, vcf_path):
    """Write a VCF file listing the introduced mutations."""
    with open(vcf_path, "w") as f:
        f.write("##fileformat=VCFv4.2\n")
        f.write(f"##fileDate={date.today().strftime('%Y%m%d')}\n")
        f.write("##source=simulate-tumor-reads.py\n")
        f.write('##INFO=<ID=SOMATIC,Number=0,Type=Flag,Description="Simulated somatic mutation">\n')
        # Contig headers
        for chrom, seq in genome.items():
            f.write(f"##contig=<ID={chrom},length={len(seq)}>\n")
        f.write("#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\n")
        for chrom, pos_0, ref, alt in mutations:
            # VCF uses 1-based positions
            pos_1 = pos_0 + 1
            f.write(f"{chrom}\t{pos_1}\t.\t{ref}\t{alt}\t.\tPASS\tSOMATIC\n")


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    genome_fasta = os.path.join(script_dir, "yeast", "genome.fa")
    outdir = os.path.join(script_dir, "yeast")

    # Allow overrides via command-line
    if len(sys.argv) > 1:
        genome_fasta = sys.argv[1]
    if len(sys.argv) > 2:
        outdir = sys.argv[2]

    n_mutations = 20
    n_reads = 500

    print(f"Reading genome: {genome_fasta}")
    genome = read_fasta(genome_fasta)
    print(f"  {len(genome)} chromosomes, {sum(len(s) for s in genome.values()):,} bp total")

    print(f"Introducing {n_mutations} somatic SNV mutations...")
    mutated_genome, mutations = introduce_mutations(genome, n_mutations=n_mutations)
    for chrom, pos, ref, alt in mutations:
        print(f"  {chrom}:{pos + 1} {ref}>{alt}")

    print(f"Simulating {n_reads} tumor paired-end reads (150bp)...")
    r1, r2 = simulate_reads(mutated_genome, n_reads=n_reads, read_length=150,
                            fragment_size=300)
    print(f"  Generated {len(r1)} read pairs")

    r1_path = os.path.join(outdir, "tumor_R1.fastq.gz")
    r2_path = os.path.join(outdir, "tumor_R2.fastq.gz")
    vcf_path = os.path.join(outdir, "tumor_truth.vcf")

    with gzip.open(r1_path, "wt") as f:
        f.writelines(r1)
    with gzip.open(r2_path, "wt") as f:
        f.writelines(r2)

    write_truth_vcf(mutations, genome, vcf_path)

    print(f"Written: {r1_path}")
    print(f"Written: {r2_path}")
    print(f"Written: {vcf_path}")
    print(f"\nTruth mutations: {len(mutations)} SNVs")
    print("Use yeast_sim_R1/R2.fastq.gz as normal, tumor_R1/R2.fastq.gz as tumor")


if __name__ == "__main__":
    main()
