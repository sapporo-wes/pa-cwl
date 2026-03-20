#!/usr/bin/env python3
"""Simulate Hi-C paired-end reads with ligation junctions.

Generates reads that mimic Hi-C library preparation:
- Some reads span ligation junctions (chimeric)
- Some reads are normal pairs from the same restriction fragment
- Some reads capture inter-chromosomal interactions

Usage:
  python simulate-hic-reads.py [output_dir] [num_reads]
"""

import gzip
import os
import random
import sys

SEED = 42
CHROM_SIZES = {"chr1": 5000, "chr2": 3000, "chr3": 2000}
RESTRICTION_SITE = "GATC"  # MboI/DpnII
LIGATION_SITE = "GATCGATC"
READ_LEN = 100
QUALITY = "I" * READ_LEN


def generate_genome():
    """Generate a simple reference genome."""
    random.seed(SEED)
    genome = {}
    for chrom, size in CHROM_SIZES.items():
        seq = []
        for i in range(size):
            # Insert restriction sites at regular intervals
            if i % 500 == 200 and i + len(RESTRICTION_SITE) < size:
                seq.append("")  # placeholder
            else:
                seq.append(random.choice("ACGT"))
        # Insert restriction sites
        genome[chrom] = list("".join(seq))
        for i in range(0, size, 500):
            pos = i + 200
            if pos + len(RESTRICTION_SITE) < size:
                for j, base in enumerate(RESTRICTION_SITE):
                    genome[chrom][pos + j] = base
    return {k: "".join(v) for k, v in genome.items()}


def reverse_complement(seq):
    comp = {"A": "T", "T": "A", "C": "G", "G": "C", "N": "N"}
    return "".join(comp.get(b, "N") for b in reversed(seq))


def get_fragment(genome, chrom, pos, length):
    """Get a fragment from the genome, wrapping if needed."""
    seq = genome[chrom]
    end = min(pos + length, len(seq))
    frag = seq[pos:end]
    if len(frag) < length:
        frag += "N" * (length - len(frag))
    return frag


def simulate_reads(genome, num_reads, output_dir):
    """Generate Hi-C paired-end reads."""
    random.seed(SEED + 1)
    chroms = list(CHROM_SIZES.keys())

    r1_path = os.path.join(output_dir, "hic_sample1_R1.fastq.gz")
    r2_path = os.path.join(output_dir, "hic_sample1_R2.fastq.gz")

    with gzip.open(r1_path, "wt") as r1_fh, gzip.open(r2_path, "wt") as r2_fh:
        for i in range(num_reads):
            read_type = random.random()

            if read_type < 0.3:
                # Chimeric read with ligation junction
                chrom1 = random.choice(chroms)
                chrom2 = random.choice(chroms)
                pos1 = random.randint(0, len(genome[chrom1]) - READ_LEN - len(LIGATION_SITE))
                pos2 = random.randint(0, len(genome[chrom2]) - READ_LEN)

                # R1: fragment from chrom1 + ligation site + fragment from chrom2
                frag1 = get_fragment(genome, chrom1, pos1, READ_LEN // 2)
                frag2 = get_fragment(genome, chrom2, pos2, READ_LEN // 2)
                r1_seq = (frag1 + LIGATION_SITE + frag2)[:READ_LEN]

                # R2: normal read from the other side
                pos2_r2 = random.randint(0, len(genome[chrom2]) - READ_LEN)
                r2_seq = get_fragment(genome, chrom2, pos2_r2, READ_LEN)

            elif read_type < 0.6:
                # Inter-chromosomal interaction (no junction in read)
                chrom1 = random.choice(chroms)
                chrom2 = random.choice([c for c in chroms if c != chrom1]) if len(chroms) > 1 else chroms[0]
                pos1 = random.randint(0, len(genome[chrom1]) - READ_LEN)
                pos2 = random.randint(0, len(genome[chrom2]) - READ_LEN)
                r1_seq = get_fragment(genome, chrom1, pos1, READ_LEN)
                r2_seq = reverse_complement(get_fragment(genome, chrom2, pos2, READ_LEN))

            else:
                # Intra-chromosomal interaction
                chrom = random.choice(chroms)
                pos1 = random.randint(0, len(genome[chrom]) - READ_LEN)
                # Distance follows a power-law distribution
                distance = int(random.paretovariate(1.0) * 100) + 200
                pos2 = min(pos1 + distance, len(genome[chrom]) - READ_LEN)
                pos2 = max(0, pos2)
                r1_seq = get_fragment(genome, chrom, pos1, READ_LEN)
                r2_seq = reverse_complement(get_fragment(genome, chrom, pos2, READ_LEN))

            # Add some sequencing errors (~1%)
            r1_seq = list(r1_seq)
            r2_seq = list(r2_seq)
            for seq in [r1_seq, r2_seq]:
                for j in range(len(seq)):
                    if random.random() < 0.01:
                        seq[j] = random.choice("ACGT")
            r1_seq = "".join(r1_seq)
            r2_seq = "".join(r2_seq)

            name = f"hic_read_{i:06d}"
            r1_fh.write(f"@{name}\n{r1_seq}\n+\n{QUALITY[:len(r1_seq)]}\n")
            r2_fh.write(f"@{name}\n{r2_seq}\n+\n{QUALITY[:len(r2_seq)]}\n")


def write_genome(genome, output_dir):
    """Write genome FASTA and chromsizes."""
    fasta_path = os.path.join(output_dir, "reference.fasta")
    sizes_path = os.path.join(output_dir, "chromsizes.tsv")

    with open(fasta_path, "w") as fh:
        for chrom, seq in sorted(genome.items()):
            fh.write(f">{chrom}\n")
            for i in range(0, len(seq), 80):
                fh.write(seq[i : i + 80] + "\n")

    with open(sizes_path, "w") as fh:
        for chrom in sorted(genome.keys()):
            fh.write(f"{chrom}\t{len(genome[chrom])}\n")


def main():
    output_dir = sys.argv[1] if len(sys.argv) > 1 else "hic"
    num_reads = int(sys.argv[2]) if len(sys.argv) > 2 else 500
    os.makedirs(output_dir, exist_ok=True)

    print(f"Generating Hi-C test data in {output_dir}/")
    genome = generate_genome()
    write_genome(genome, output_dir)
    simulate_reads(genome, num_reads, output_dir)
    print(f"  - reference.fasta ({sum(CHROM_SIZES.values())} bp, {len(CHROM_SIZES)} chromosomes)")
    print(f"  - chromsizes.tsv")
    print(f"  - hic_sample1_R1.fastq.gz ({num_reads} reads)")
    print(f"  - hic_sample1_R2.fastq.gz ({num_reads} reads)")
    print(f"  - Restriction enzyme: MboI/DpnII (GATC)")
    print(f"  - Ligation site: {LIGATION_SITE}")


if __name__ == "__main__":
    main()
