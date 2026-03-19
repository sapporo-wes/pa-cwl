#!/usr/bin/env python3
"""Generate simulated RNA-seq reads with gene fusions for testing rnafusion pipeline.
Creates a tiny reference genome, GTF annotation, and paired-end reads containing
a synthetic gene fusion event.
"""
import gzip
import random
import sys
import os


# Two "genes" on different chromosomes that will be fused
GENE_A = {
    "chrom": "chr1", "start": 100, "end": 1100, "strand": "+",
    "name": "GENEA", "exons": [(100, 400), (500, 800), (900, 1100)],
}
GENE_B = {
    "chrom": "chr2", "start": 200, "end": 1200, "strand": "+",
    "name": "GENEB", "exons": [(200, 500), (600, 900), (1000, 1200)],
}
# A normal gene (no fusion)
GENE_C = {
    "chrom": "chr1", "start": 2000, "end": 3000, "strand": "-",
    "name": "GENEC", "exons": [(2000, 2400), (2500, 2800), (2900, 3000)],
}

CHROM_SIZES = {"chr1": 5000, "chr2": 5000}


def generate_genome(chrom_sizes, seed=42):
    rng = random.Random(seed)
    genome = {}
    for name, length in chrom_sizes.items():
        seq = []
        for _ in range(length):
            if rng.random() < 0.42:
                seq.append(rng.choice("GC"))
            else:
                seq.append(rng.choice("AT"))
        genome[name] = "".join(seq)
    return genome


def get_transcript_seq(genome, gene):
    """Extract spliced transcript sequence from gene exons."""
    seq = ""
    for start, end in gene["exons"]:
        seq += genome[gene["chrom"]][start:end]
    return seq


def reverse_complement(seq):
    comp = {"A": "T", "T": "A", "G": "C", "C": "G"}
    return "".join(comp.get(b, "N") for b in reversed(seq))


def simulate_paired_reads(template_seq, n_reads, rng, read_length=100,
                          error_rate=0.005):
    """Simulate paired-end reads from a transcript template."""
    reads_r1, reads_r2 = [], []
    for _ in range(n_reads):
        insert = max(read_length * 2, int(rng.gauss(250, 40)))
        if insert > len(template_seq):
            insert = len(template_seq)
        start = rng.randint(0, max(0, len(template_seq) - insert))
        frag = template_seq[start:start + insert]
        r1 = list(frag[:read_length])
        r2 = list(reverse_complement(frag[-read_length:]))
        for seq in [r1, r2]:
            for j in range(len(seq)):
                if rng.random() < error_rate:
                    seq[j] = rng.choice([b for b in "ACGT" if b != seq[j]])
        reads_r1.append("".join(r1))
        reads_r2.append("".join(r2))
    return reads_r1, reads_r2


def write_gtf(filepath, genes):
    """Write a minimal GTF annotation."""
    with open(filepath, "w") as f:
        for gene in genes:
            chrom = gene["chrom"]
            name = gene["name"]
            strand = gene["strand"]
            gs, ge = gene["start"] + 1, gene["end"]
            f.write(f'{chrom}\tsim\tgene\t{gs}\t{ge}\t.\t{strand}\t.\t'
                    f'gene_id "{name}"; gene_name "{name}";\n')
            f.write(f'{chrom}\tsim\ttranscript\t{gs}\t{ge}\t.\t{strand}\t.\t'
                    f'gene_id "{name}"; transcript_id "{name}_t1"; '
                    f'gene_name "{name}";\n')
            for i, (es, ee) in enumerate(gene["exons"], 1):
                f.write(f'{chrom}\tsim\texon\t{es+1}\t{ee}\t.\t{strand}\t.\t'
                        f'gene_id "{name}"; transcript_id "{name}_t1"; '
                        f'exon_number "{i}"; gene_name "{name}";\n')


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    n_fusion = int(sys.argv[2]) if len(sys.argv) > 2 else 100
    n_normal = int(sys.argv[3]) if len(sys.argv) > 3 else 400
    os.makedirs(outdir, exist_ok=True)

    rng = random.Random(42)
    genome = generate_genome(CHROM_SIZES)

    # Write reference FASTA
    ref_path = os.path.join(outdir, "reference.fasta")
    with open(ref_path, "w") as f:
        for chrom, seq in genome.items():
            f.write(f">{chrom}\n")
            for i in range(0, len(seq), 80):
                f.write(seq[i:i+80] + "\n")
    print(f"Written: {ref_path}")

    # Write GTF
    gtf_path = os.path.join(outdir, "annotation.gtf")
    write_gtf(gtf_path, [GENE_A, GENE_B, GENE_C])
    print(f"Written: {gtf_path}")

    # Get transcript sequences
    tx_a = get_transcript_seq(genome, GENE_A)
    tx_b = get_transcript_seq(genome, GENE_B)
    tx_c = get_transcript_seq(genome, GENE_C)
    if GENE_C["strand"] == "-":
        tx_c = reverse_complement(tx_c)

    # Create fusion transcript: exons 1-2 of GENE_A + exons 2-3 of GENE_B
    exons_a = [genome[GENE_A["chrom"]][s:e] for s, e in GENE_A["exons"]]
    exons_b = [genome[GENE_B["chrom"]][s:e] for s, e in GENE_B["exons"]]
    fusion_tx = "".join(exons_a[:2]) + "".join(exons_b[1:])
    print(f"Fusion transcript: {GENE_A['name']}(exon1-2)--{GENE_B['name']}"
          f"(exon2-3) = {len(fusion_tx)} bp")

    # Simulate reads
    all_r1, all_r2 = [], []

    # Fusion reads
    f_r1, f_r2 = simulate_paired_reads(fusion_tx, n_fusion, rng)
    all_r1.extend(f_r1)
    all_r2.extend(f_r2)

    # Normal reads from each gene
    n_per = n_normal // 3
    for tx in [tx_a, tx_b, tx_c]:
        r1, r2 = simulate_paired_reads(tx, n_per, rng)
        all_r1.extend(r1)
        all_r2.extend(r2)

    # Shuffle
    combined = list(zip(all_r1, all_r2))
    rng.shuffle(combined)
    all_r1, all_r2 = zip(*combined)

    # Write FASTQ
    read_idx = 0
    r1_records, r2_records = [], []
    for r1, r2 in zip(all_r1, all_r2):
        qual = "I" * len(r1)
        r1_records.append(f"@read{read_idx:06d}/1\n{r1}\n+\n{qual}\n")
        r2_records.append(f"@read{read_idx:06d}/2\n{r2}\n+\n{qual}\n")
        read_idx += 1

    r1_path = os.path.join(outdir, "sample1_R1.fastq.gz")
    r2_path = os.path.join(outdir, "sample1_R2.fastq.gz")
    with gzip.open(r1_path, "wt") as f:
        f.writelines(r1_records)
    with gzip.open(r2_path, "wt") as f:
        f.writelines(r2_records)
    print(f"Written: {r1_path} ({len(r1_records)} reads)")
    print(f"Written: {r2_path}")


if __name__ == "__main__":
    main()
