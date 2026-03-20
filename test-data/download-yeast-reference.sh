#!/bin/bash
# Download S. cerevisiae (yeast) reference genome and annotation from Ensembl
# Small genome (~12MB) suitable for lightweight testing
set -euo pipefail

OUTDIR="${1:-.}"
RELEASE="112"
SPECIES="saccharomyces_cerevisiae"
ASSEMBLY="R64-1-1"
BASE_URL="https://ftp.ensembl.org/pub/release-${RELEASE}"

mkdir -p "${OUTDIR}"

echo "Downloading yeast genome FASTA..."
curl -L -o "${OUTDIR}/genome.fa.gz" \
  "${BASE_URL}/fasta/${SPECIES}/dna/Saccharomyces_cerevisiae.${ASSEMBLY}.dna.toplevel.fa.gz"
gunzip -f "${OUTDIR}/genome.fa.gz"

echo "Downloading yeast GTF annotation..."
curl -L -o "${OUTDIR}/genes.gtf.gz" \
  "${BASE_URL}/gtf/${SPECIES}/Saccharomyces_cerevisiae.${ASSEMBLY}.${RELEASE}.gtf.gz"
gunzip -f "${OUTDIR}/genes.gtf.gz"

echo "Downloading yeast cDNA (transcriptome) FASTA..."
curl -L -o "${OUTDIR}/transcriptome.fa.gz" \
  "${BASE_URL}/fasta/${SPECIES}/cdna/Saccharomyces_cerevisiae.${ASSEMBLY}.cdna.all.fa.gz"
gunzip -f "${OUTDIR}/transcriptome.fa.gz"

echo "Done. Files in ${OUTDIR}:"
ls -lh "${OUTDIR}"
