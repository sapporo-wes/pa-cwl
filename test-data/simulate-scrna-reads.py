#!/usr/bin/env python3
"""Generate simulated single-cell RNA-seq reads from a genome FASTA.
Produces small FASTQ files for lightweight STARsolo testing.

R1: barcode (16bp) + UMI (12bp) = 28bp (10x v3 format)
R2: cDNA reads (~100bp) from genome

Also generates a barcode whitelist file.
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


def generate_barcodes(n_barcodes=50, bc_len=16):
    """Generate random cell barcodes."""
    random.seed(123)
    bases = "ACGT"
    barcodes = set()
    while len(barcodes) < n_barcodes:
        bc = "".join(random.choice(bases) for _ in range(bc_len))
        barcodes.add(bc)
    return sorted(barcodes)


def generate_umi(umi_len=12):
    """Generate a random UMI."""
    bases = "ACGT"
    return "".join(random.choice(bases) for _ in range(umi_len))


def simulate_scrna_reads(genome, barcodes, n_reads=5000,
                         read_length=100, fragment_size=250,
                         bc_len=16, umi_len=12):
    """Simulate single-cell RNA-seq reads.

    R1: barcode + UMI (28bp for 10x v3)
    R2: cDNA reads from genome
    """
    random.seed(42)
    chroms = list(genome.keys())
    chrom_weights = [len(genome[c]) for c in chroms]
    total_len = sum(chrom_weights)

    # Assign reads to cells with realistic distribution
    # Most reads come from a few cells (power-law-ish)
    n_cells = len(barcodes)
    cell_weights = [1.0 / (i + 1) ** 0.5 for i in range(n_cells)]
    total_w = sum(cell_weights)
    cell_weights = [w / total_w for w in cell_weights]

    reads_r1 = []
    reads_r2 = []

    for i in range(n_reads):
        # Pick a cell
        cell_idx = random.choices(range(n_cells), weights=cell_weights, k=1)[0]
        barcode = barcodes[cell_idx]
        umi = generate_umi(umi_len)

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

        # R1: barcode + UMI
        r1_seq = barcode + umi
        r1_qual = "I" * len(r1_seq)

        # R2: cDNA (reverse complement of fragment end, as in real 10x)
        r2_seq = reverse_complement(fragment[-read_length:]).upper()
        if r2_seq.count("N") > 5:
            continue
        r2_qual = "I" * read_length

        read_name = f"@sim_{i:06d} {chrom}:{start}:cell{cell_idx}"
        reads_r1.append(f"{read_name}/1\n{r1_seq}\n+\n{r1_qual}\n")
        reads_r2.append(f"{read_name}/2\n{r2_seq}\n+\n{r2_qual}\n")

    return reads_r1, reads_r2


def main():
    genome_fasta = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else "."
    n_reads = int(sys.argv[3]) if len(sys.argv) > 3 else 5000
    n_cells = int(sys.argv[4]) if len(sys.argv) > 4 else 50
    bc_len = 16
    umi_len = 12

    print(f"Reading genome: {genome_fasta}")
    genome = read_fasta(genome_fasta)
    print(f"  {len(genome)} chromosomes, "
          f"{sum(len(s) for s in genome.values()):,} bp total")

    print(f"Generating {n_cells} cell barcodes...")
    barcodes = generate_barcodes(n_cells, bc_len)

    print(f"Simulating {n_reads} single-cell reads ({n_cells} cells)...")
    r1, r2 = simulate_scrna_reads(
        genome, barcodes, n_reads=n_reads,
        bc_len=bc_len, umi_len=umi_len
    )
    print(f"  Generated {len(r1)} read pairs")

    # Write FASTQ files
    r1_path = f"{outdir}/yeast_scrna_R1.fastq.gz"
    r2_path = f"{outdir}/yeast_scrna_R2.fastq.gz"
    wl_path = f"{outdir}/barcode_whitelist.txt"

    with gzip.open(r1_path, "wt") as f:
        f.writelines(r1)
    with gzip.open(r2_path, "wt") as f:
        f.writelines(r2)

    # Write barcode whitelist
    with open(wl_path, "w") as f:
        for bc in barcodes:
            f.write(bc + "\n")

    print(f"Written: {r1_path}")
    print(f"Written: {r2_path}")
    print(f"Written: {wl_path} ({len(barcodes)} barcodes)")


if __name__ == "__main__":
    main()
