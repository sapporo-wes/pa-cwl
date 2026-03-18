#!/usr/bin/env python3
"""Generate simulated metagenomic reads for MAG pipeline testing.
Creates minimal FASTQ files from synthetic microbial genomes.
"""
import gzip
import random
import sys
import os

# Synthetic genome fragments (~5-8kb, different GC content for binning)
# These are random sequences, not real genomes
GENOMES = [
    ("genome_A", 0.35, 6000),  # Low GC
    ("genome_B", 0.55, 7000),  # Medium GC
    ("genome_C", 0.70, 5000),  # High GC
]


def generate_genome(length, gc_content, seed):
    """Generate a random genome with specified GC content."""
    rng = random.Random(seed)
    genome = []
    for _ in range(length):
        if rng.random() < gc_content:
            genome.append(rng.choice("GC"))
        else:
            genome.append(rng.choice("AT"))
    return "".join(genome)


def simulate_reads(genome_seq, n_reads, read_length=150, error_rate=0.005):
    """Simulate paired-end shotgun reads from a genome."""
    reads_r1 = []
    reads_r2 = []
    insert_mean = 350
    insert_sd = 50

    comp = {"A": "T", "T": "A", "G": "C", "C": "G"}

    for i in range(n_reads):
        insert_size = max(read_length * 2, int(random.gauss(insert_mean, insert_sd)))
        if insert_size > len(genome_seq):
            insert_size = len(genome_seq)

        start = random.randint(0, len(genome_seq) - insert_size)
        fragment = genome_seq[start:start + insert_size]

        # R1: forward from start
        r1_seq = list(fragment[:read_length])
        # R2: reverse complement from end
        r2_seq = list("".join(comp[b] for b in reversed(fragment[-read_length:])))

        # Add errors
        for seq in [r1_seq, r2_seq]:
            for j in range(len(seq)):
                if random.random() < error_rate:
                    seq[j] = random.choice([b for b in "ACGT" if b != seq[j]])

        r1_str = "".join(r1_seq)
        r2_str = "".join(r2_seq)

        # Quality scores (Phred+33)
        qual_r1 = "".join(chr(random.randint(53, 73)) for _ in range(read_length))
        qual_r2 = "".join(chr(random.randint(50, 73)) for _ in range(read_length))

        reads_r1.append(r1_str)
        reads_r2.append(r2_str)

    return reads_r1, reads_r2


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    n_per_genome = int(sys.argv[2]) if len(sys.argv) > 2 else 2000

    os.makedirs(outdir, exist_ok=True)
    random.seed(42)

    all_r1 = []
    all_r2 = []
    read_idx = 0

    for genome_name, gc, length in GENOMES:
        print(f"Generating genome {genome_name}: {length}bp, GC={gc:.0%}")
        genome_seq = generate_genome(length, gc, seed=hash(genome_name) % 2**32)

        print(f"  Simulating {n_per_genome} read pairs...")
        r1_seqs, r2_seqs = simulate_reads(genome_seq, n_per_genome)

        for r1, r2 in zip(r1_seqs, r2_seqs):
            name = f"@read{read_idx:06d}"
            qual_r1 = "".join(chr(random.randint(53, 73)) for _ in range(150))
            qual_r2 = "".join(chr(random.randint(50, 73)) for _ in range(150))
            all_r1.append(f"{name}/1\n{r1}\n+\n{qual_r1}\n")
            all_r2.append(f"{name}/2\n{r2}\n+\n{qual_r2}\n")
            read_idx += 1

    # Shuffle reads
    combined = list(zip(all_r1, all_r2))
    random.shuffle(combined)
    all_r1, all_r2 = zip(*combined)

    # Write sample 1 (all reads in one sample for single-sample test)
    r1_path = os.path.join(outdir, "sample1_R1.fastq.gz")
    r2_path = os.path.join(outdir, "sample1_R2.fastq.gz")
    with gzip.open(r1_path, "wt") as f:
        f.writelines(all_r1)
    with gzip.open(r2_path, "wt") as f:
        f.writelines(all_r2)

    print(f"Written: {r1_path} ({len(all_r1)} reads)")
    print(f"Written: {r2_path} ({len(all_r2)} reads)")


if __name__ == "__main__":
    main()
