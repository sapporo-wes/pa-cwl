#!/usr/bin/env python3
"""Generate simulated viral sequencing reads with primer coordinates.
Produces small FASTQ files and a primer BED for viralrecon testing.
Uses a small segment of yeast genome as a stand-in viral reference.
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


def create_viral_reference(genome, outdir, chrom="I", length=5000):
    """Extract a small region as a 'viral' reference genome."""
    seq = genome[chrom][:length].upper()
    ref_name = "viral_ref"
    ref_path = f"{outdir}/viral_ref.fa"

    with open(ref_path, "w") as f:
        f.write(f">{ref_name}\n")
        for i in range(0, len(seq), 80):
            f.write(seq[i:i+80] + "\n")

    return ref_name, seq, ref_path


def create_primer_bed(ref_name, ref_len, outdir, amplicon_size=400,
                      overlap=30, primer_len=25):
    """Generate tiling amplicon primer coordinates (ARTIC-like scheme)."""
    primers = []
    pos = 0
    pool = 1
    amp_num = 1

    while pos < ref_len - amplicon_size:
        # Forward primer
        fwd_start = pos
        fwd_end = pos + primer_len
        primers.append((ref_name, fwd_start, fwd_end,
                       f"amp{amp_num}_LEFT", pool, "+"))

        # Reverse primer
        rev_end = min(pos + amplicon_size, ref_len)
        rev_start = rev_end - primer_len
        primers.append((ref_name, rev_start, rev_end,
                       f"amp{amp_num}_RIGHT", pool, "-"))

        pos += amplicon_size - overlap
        pool = 2 if pool == 1 else 1
        amp_num += 1

    bed_path = f"{outdir}/primers.bed"
    with open(bed_path, "w") as f:
        for p in primers:
            f.write(f"{p[0]}\t{p[1]}\t{p[2]}\t{p[3]}\t{p[4]}\t{p[5]}\n")

    return bed_path, primers


def simulate_amplicon_reads(ref_name, ref_seq, primers, n_reads=3000,
                            read_length=150, fragment_size=250):
    """Simulate paired-end reads from amplicon tiling scheme."""
    random.seed(42)
    ref_len = len(ref_seq)

    # Group primers into amplicons (LEFT + RIGHT pairs)
    amplicons = []
    for i in range(0, len(primers), 2):
        left = primers[i]
        right = primers[i + 1]
        amplicons.append((left[1], right[2]))  # start, end

    reads_r1 = []
    reads_r2 = []
    amp_weights = [end - start for start, end in amplicons]

    for i in range(n_reads):
        # Pick random amplicon
        amp_idx = random.choices(range(len(amplicons)),
                                 weights=amp_weights, k=1)[0]
        amp_start, amp_end = amplicons[amp_idx]
        amp_len = amp_end - amp_start

        # Random fragment within amplicon
        max_start = max(0, amp_end - fragment_size)
        min_start = amp_start
        if max_start <= min_start:
            start = min_start
        else:
            start = random.randint(min_start, max_start)

        frag_end = min(start + fragment_size, ref_len)
        fragment = ref_seq[start:frag_end]

        if len(fragment) < read_length:
            continue

        r1_seq = fragment[:read_length]
        r2_seq = reverse_complement(fragment[-read_length:])

        if r1_seq.count("N") > 3 or r2_seq.count("N") > 3:
            continue

        qual = "I" * read_length
        read_name = f"@sim_{i:06d} {ref_name}:{start}:amp{amp_idx}"

        reads_r1.append(f"{read_name}/1\n{r1_seq}\n+\n{qual}\n")
        reads_r2.append(f"{read_name}/2\n{r2_seq}\n+\n{qual}\n")

    return reads_r1, reads_r2


def main():
    genome_fasta = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else "."
    n_reads = int(sys.argv[3]) if len(sys.argv) > 3 else 3000

    print(f"Reading genome: {genome_fasta}")
    genome = read_fasta(genome_fasta)

    print("Creating viral reference (5kb from chr I)...")
    ref_name, ref_seq, ref_path = create_viral_reference(genome, outdir)
    print(f"  Written: {ref_path} ({len(ref_seq)} bp)")

    print("Creating primer BED (ARTIC-like tiling)...")
    bed_path, primers = create_primer_bed(ref_name, len(ref_seq), outdir)
    print(f"  Written: {bed_path} ({len(primers)} primers, "
          f"{len(primers)//2} amplicons)")

    print(f"Simulating {n_reads} amplicon reads...")
    r1, r2 = simulate_amplicon_reads(ref_name, ref_seq, primers,
                                      n_reads=n_reads)
    print(f"  Generated {len(r1)} read pairs")

    r1_path = f"{outdir}/viral_R1.fastq.gz"
    r2_path = f"{outdir}/viral_R2.fastq.gz"

    with gzip.open(r1_path, "wt") as f:
        f.writelines(r1)
    with gzip.open(r2_path, "wt") as f:
        f.writelines(r2)

    print(f"Written: {r1_path}")
    print(f"Written: {r2_path}")


if __name__ == "__main__":
    main()
