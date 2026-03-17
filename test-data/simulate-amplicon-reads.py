#!/usr/bin/env python3
"""Generate simulated 16S amplicon reads for DADA2 testing.
Creates minimal FASTQ + taxonomy reference for ampliseq pipeline testing.
"""
import gzip
import random
import sys
import os

# Synthetic 16S V4 region sequences (~253bp between 515F/806R)
# These are short artificial sequences (not real 16S) for testing only
MOCK_ASVS = [
    ("Bacteroidetes;Bacteroidia;Bacteroidales;Bacteroidaceae;Bacteroides;fragilis",
     "ACGTAGCAATACGAGCGAACCCTTGATCTTAGTTGCCAGCATTCAGTTGGGCACTCTAGAGTGCGCAGCGAAATGCGTAAAAGATTGACGGTACCCTACAAAGAACTGCCTAAATGTAACTATCTTCTGAACACTCTTCGGAATCCTGTGGACAGAAATGACTATCCGGAAACGAAAGCTTGATCATGCTACCAGTTTGTGATG"),
    ("Firmicutes;Bacilli;Lactobacillales;Lactobacillaceae;Lactobacillus;acidophilus",
     "ACGTAGCAGCGTATCGGAGCAGGTACCGTCTTCGGGTTGTAAAGTTCTTTCAGCTGGGAAGATAATGACGGTACCTGACGAATAAGCCCCGGCTAACTCCGTGCCAGCAGCCGCGGTAATACGGAGGGGGCTAGCGTTGTTCGGAATTACTGGGCGTAAAGCGCACGTAGGCGGATATTTAAGTCAGGGGTGAAATCCCGGGGCTC"),
    ("Proteobacteria;Gammaproteobacteria;Enterobacterales;Enterobacteriaceae;Escherichia;coli",
     "ACGTAGCGGCAAATGTTAGACAGGGAACCCCTTGTCTCAGGTCGATAAACTCTAGGTCTAATAAACTGGAAGATTAAAGCAAGAGCCCTTCAAGGACTGCATTATAAACTAAGGATAGCTTTGGGTCATCGACAAGATTAAATCAGCTATCCATGACTTCAGGCCAAAATGGCTCATTAAATCAGTTATAGTTTATTTGATGGTACCT"),
]

# Primers (515F/806R V4 region)
PRIMER_FWD = "GTGYCAGCMGCCGCGGTAA"
PRIMER_REV = "GGACTACNVGGGTWTCTAAT"


IUPAC_EXPAND = {
    "A": "A", "C": "C", "G": "G", "T": "T",
    "R": "AG", "Y": "CT", "S": "GC", "W": "AT",
    "K": "GT", "M": "AC", "B": "CGT", "D": "AGT",
    "H": "ACT", "V": "ACG", "N": "ACGT",
}


def expand_iupac(seq):
    """Replace IUPAC degenerate bases with random concrete bases."""
    return "".join(random.choice(IUPAC_EXPAND.get(b, "N")) for b in seq)


def reverse_complement(seq):
    comp = {"A": "T", "T": "A", "G": "C", "C": "G",
            "N": "N", "Y": "R", "R": "Y", "M": "K",
            "K": "M", "W": "W", "S": "S", "V": "B",
            "B": "V", "D": "H", "H": "D"}
    return "".join(comp.get(b, "N") for b in reversed(seq))


def add_errors(seq, error_rate=0.005):
    """Add random substitution errors."""
    bases = list(seq)
    for i in range(len(bases)):
        if random.random() < error_rate:
            bases[i] = random.choice([b for b in "ACGT" if b != bases[i]])
    return "".join(bases)


def simulate_amplicon_reads(asvs, n_reads_per_asv=500, read_length=150):
    """Simulate paired-end amplicon reads with primers."""
    random.seed(42)
    reads_r1 = []
    reads_r2 = []

    for asv_idx, (taxonomy, seq) in enumerate(asvs):
        # Full amplicon = fwd_primer + insert + rc(rev_primer)
        # Expand IUPAC degenerate bases to concrete ACGT for each amplicon
        fwd_concrete = expand_iupac(PRIMER_FWD)
        rev_concrete = expand_iupac(PRIMER_REV)
        rc_rev_primer = reverse_complement(rev_concrete)
        amplicon = fwd_concrete + seq + rc_rev_primer

        for i in range(n_reads_per_asv):
            # Add errors
            amp = add_errors(amplicon)

            # R1 reads from fwd primer end
            r1_seq = amp[:read_length]
            # R2 reads from rev primer end (reverse complement)
            r2_seq = reverse_complement(amp[-read_length:])

            qual_r1 = "".join(chr(random.randint(53, 73)) for _ in range(read_length))
            qual_r2 = "".join(chr(random.randint(48, 73)) for _ in range(read_length))

            read_name = f"@asv{asv_idx}_read{i:05d}"
            reads_r1.append(f"{read_name}/1\n{r1_seq}\n+\n{qual_r1}\n")
            reads_r2.append(f"{read_name}/2\n{r2_seq}\n+\n{qual_r2}\n")

    # Shuffle
    combined = list(zip(reads_r1, reads_r2))
    random.shuffle(combined)
    reads_r1, reads_r2 = zip(*combined)

    return list(reads_r1), list(reads_r2)


def create_taxonomy_ref(asvs, outdir):
    """Create a minimal DADA2-compatible taxonomy reference FASTA."""
    ref_path = os.path.join(outdir, "taxonomy_ref.fasta")
    with open(ref_path, "w") as f:
        for i, (taxonomy, seq) in enumerate(asvs):
            f.write(f">{taxonomy}\n{seq}\n")
    return ref_path


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    n_per_asv = int(sys.argv[2]) if len(sys.argv) > 2 else 500

    os.makedirs(outdir, exist_ok=True)

    print(f"Creating taxonomy reference ({len(MOCK_ASVS)} sequences)...")
    ref_path = create_taxonomy_ref(MOCK_ASVS, outdir)
    print(f"  Written: {ref_path}")

    print(f"Simulating {n_per_asv * len(MOCK_ASVS)} amplicon reads "
          f"({len(MOCK_ASVS)} ASVs x {n_per_asv} reads)...")
    r1, r2 = simulate_amplicon_reads(MOCK_ASVS, n_reads_per_asv=n_per_asv)
    print(f"  Generated {len(r1)} read pairs")

    # Write sample 1
    r1_path = os.path.join(outdir, "sample1_R1.fastq.gz")
    r2_path = os.path.join(outdir, "sample1_R2.fastq.gz")
    with gzip.open(r1_path, "wt") as f:
        f.writelines(r1)
    with gzip.open(r2_path, "wt") as f:
        f.writelines(r2)

    print(f"Written: {r1_path}")
    print(f"Written: {r2_path}")


if __name__ == "__main__":
    main()
