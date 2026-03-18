#!/usr/bin/env python3
"""Generate simulated metagenomic reads and a tiny Kraken2 database for testing.
Creates minimal FASTQ + Kraken2 DB for taxprofiler pipeline testing.
"""
import gzip
import random
import sys
import os
import subprocess

# Tiny synthetic genomes for 3 taxa
TAXA = [
    (1, "root", 1),
    (131567, "cellular organisms", 1),
    (2, "Bacteria", 131567),
    (1224, "Proteobacteria", 2),
    (1236, "Gammaproteobacteria", 1224),
    (91347, "Enterobacterales", 1236),
    (543, "Enterobacteriaceae", 91347),
    (561, "Escherichia", 543),
    (562, "Escherichia coli", 561),
    (1239, "Firmicutes", 2),
    (91061, "Bacilli", 1239),
    (186826, "Lactobacillales", 91061),
    (33958, "Lactobacillaceae", 186826),
    (1578, "Lactobacillus", 33958),
    (1579, "Lactobacillus acidophilus", 1578),
    (976, "Bacteroidetes", 2),
    (200643, "Bacteroidia", 976),
    (171549, "Bacteroidales", 200643),
    (815, "Bacteroidaceae", 171549),
    (816, "Bacteroides", 815),
    (817, "Bacteroides fragilis", 816),
]

GENOMES = {
    562: ("Escherichia coli", 3000, 0.51),
    1579: ("Lactobacillus acidophilus", 2500, 0.35),
    817: ("Bacteroides fragilis", 2800, 0.43),
}


def generate_genome(length, gc_content, seed):
    rng = random.Random(seed)
    genome = []
    for _ in range(length):
        if rng.random() < gc_content:
            genome.append(rng.choice("GC"))
        else:
            genome.append(rng.choice("AT"))
    return "".join(genome)


def simulate_reads(genome_seq, n_reads, read_length=150, error_rate=0.005):
    reads_r1, reads_r2 = [], []
    comp = {"A": "T", "T": "A", "G": "C", "C": "G"}
    for _ in range(n_reads):
        insert = max(read_length * 2, int(random.gauss(350, 50)))
        if insert > len(genome_seq):
            insert = len(genome_seq)
        start = random.randint(0, len(genome_seq) - insert)
        frag = genome_seq[start:start + insert]
        r1 = list(frag[:read_length])
        r2 = list("".join(comp[b] for b in reversed(frag[-read_length:])))
        for seq in [r1, r2]:
            for j in range(len(seq)):
                if random.random() < error_rate:
                    seq[j] = random.choice([b for b in "ACGT" if b != seq[j]])
        reads_r1.append("".join(r1))
        reads_r2.append("".join(r2))
    return reads_r1, reads_r2


def build_kraken2_db(outdir, genomes, taxa):
    """Build a minimal Kraken2 database."""
    db_dir = os.path.join(outdir, "kraken2_testdb")
    tax_dir = os.path.join(db_dir, "taxonomy")
    lib_dir = os.path.join(db_dir, "library")
    os.makedirs(tax_dir, exist_ok=True)
    os.makedirs(lib_dir, exist_ok=True)

    # Write names.dmp
    with open(os.path.join(tax_dir, "names.dmp"), "w") as f:
        for taxid, name, _ in taxa:
            f.write(f"{taxid}\t|\t{name}\t|\t\t|\tscientific name\t|\n")

    # Write nodes.dmp
    with open(os.path.join(tax_dir, "nodes.dmp"), "w") as f:
        for taxid, name, parent in taxa:
            rank = "no rank"
            if taxid == 1:
                rank = "root"
            elif "aceae" in name:
                rank = "family"
            elif "ales" in name:
                rank = "order"
            elif "ia" in name and taxid in [1236, 200643, 91061]:
                rank = "class"
            elif taxid in [1224, 1239, 976]:
                rank = "phylum"
            elif taxid == 2:
                rank = "superkingdom"
            elif " " in name:
                rank = "species"
            elif taxid in [561, 1578, 816]:
                rank = "genus"
            f.write(f"{taxid}\t|\t{parent}\t|\t{rank}\t|\t\t|\t\t|\t\t|\t\t|\t\t|\t\t|\t\t|\t\t|\t\t|\t\t|\n")

    # Write library FASTA
    lib_fasta = os.path.join(lib_dir, "library.fna")
    with open(lib_fasta, "w") as f:
        for taxid, (name, length, gc) in genomes.items():
            seq = generate_genome(length, gc, seed=taxid)
            f.write(f">kraken:taxid|{taxid}|{name.replace(' ', '_')}\n{seq}\n")

    return db_dir


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    n_per_genome = int(sys.argv[2]) if len(sys.argv) > 2 else 1000

    os.makedirs(outdir, exist_ok=True)
    random.seed(42)

    # Build Kraken2 database files (taxonomy + library)
    print("Building minimal Kraken2 database structure...")
    db_dir = build_kraken2_db(outdir, GENOMES, TAXA)
    print(f"  Database structure at: {db_dir}")
    print("  NOTE: Run 'kraken2-build --build --db <path>' to finalize")

    # Simulate reads
    all_r1, all_r2 = [], []
    read_idx = 0
    for taxid, (name, length, gc) in GENOMES.items():
        print(f"Simulating {n_per_genome} reads from {name} (taxid={taxid})...")
        genome = generate_genome(length, gc, seed=taxid)
        r1s, r2s = simulate_reads(genome, n_per_genome)
        for r1, r2 in zip(r1s, r2s):
            qr1 = "".join(chr(random.randint(53, 73)) for _ in range(150))
            qr2 = "".join(chr(random.randint(50, 73)) for _ in range(150))
            all_r1.append(f"@read{read_idx:06d}/1\n{r1}\n+\n{qr1}\n")
            all_r2.append(f"@read{read_idx:06d}/2\n{r2}\n+\n{qr2}\n")
            read_idx += 1

    combined = list(zip(all_r1, all_r2))
    random.shuffle(combined)
    all_r1, all_r2 = zip(*combined)

    r1_path = os.path.join(outdir, "sample1_R1.fastq.gz")
    r2_path = os.path.join(outdir, "sample1_R2.fastq.gz")
    with gzip.open(r1_path, "wt") as f:
        f.writelines(all_r1)
    with gzip.open(r2_path, "wt") as f:
        f.writelines(all_r2)

    print(f"Written: {r1_path} ({len(all_r1)} reads)")
    print(f"Written: {r2_path}")


if __name__ == "__main__":
    main()
