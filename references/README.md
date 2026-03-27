# Reference Resolution Guide

## Overview

This directory provides a genome catalog (`genomes.yaml`) and this guide for resolving reference genomes required by pa-cwl analysis workflows. The target audience is AI agents executing pa-cwl workflows on behalf of researchers.

## Using the Catalog

1. Read `genomes.yaml` in this directory.
2. Look up the organism by `name` (e.g., `GRCh38`) or `taxonomy_id` (e.g., `9606`).
3. Each entry contains:
   - **Ensembl HTTPS URLs** for genome FASTA and GTF annotation files.
   - **iGenomes S3 paths** (optional) for pre-built aligner indices.

### Ensembl HTTPS URLs

Ensembl HTTPS URLs can be passed directly as CWL `File` inputs. `cwltool` resolves HTTPS locations natively — no download step is needed.

Example CWL input:

```yaml
genome_fasta:
  class: File
  location: https://ftp.ensembl.org/pub/release-113/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
```

### iGenomes S3 Paths

iGenomes S3 paths require local download before use. Download with:

```bash
aws s3 cp --no-sign-request <s3-path> <local-path> --recursive
```

These paths point to pre-built indices (STAR, HISAT2, BWA, Bowtie2, etc.) hosted in the `s3://ngi-igenomes/` bucket.

## Workflow-to-Index Mapping

This table defines which reference files each workflow requires.

| Workflow | Required References |
|----------|-------------------|
| rnaseq | genome FASTA + GTF + (STAR index OR HISAT2 index) |
| scrnaseq | genome FASTA + GTF + STAR index |
| rnafusion | genome FASTA + GTF + STAR index |
| sarek | genome FASTA + FAI + BWA-MEM2 index + known sites VCF |
| raredisease | genome FASTA + FAI + BWA-MEM2 index + known sites VCF |
| chipseq | genome FASTA + BWA-MEM2 index |
| atacseq | genome FASTA + BWA-MEM2 index |
| methylseq | genome FASTA (Bismark builds index internally) |
| cutandrun | genome FASTA + Bowtie2 index |
| hic | genome FASTA + Bowtie2 index + chromsizes |
| viralrecon | genome FASTA + BWA-MEM2 index + primer BED |
| nanoseq | genome FASTA (minimap2 indexes on-the-fly) |
| ampliseq | taxonomy reference FASTA (not a genome) |
| mag | genome FASTA (for host filtering, optional) |
| taxprofiler | Kraken2/Bracken databases (not genome references) |
| fetchngs | N/A |

## Decision Tree

Follow these steps to resolve references for a given organism and workflow:

1. **Look up the organism in `genomes.yaml`.**

2. **If found:**
   - Determine the required index type from the workflow-to-index mapping table above.
   - Check whether the entry has an iGenomes path with a pre-built index for that type.
     - **Yes** — Download with:
       ```bash
       aws s3 cp --no-sign-request <s3-path> <local-path> --recursive
       ```
     - **No** — Use the Ensembl HTTPS URLs from the catalog entry and run the `prepare-references` workflow (located at `workflows/prepare-references/`) to build the needed indices.

3. **If not found:**
   - Query the Ensembl REST API to discover the genome:
     ```
     GET https://rest.ensembl.org/info/genomes/{name}?content-type=application/json
     ```
     This returns assembly metadata including links to FTP/HTTPS locations for FASTA and GTF files.
   - Then run the `prepare-references` workflow with the discovered URLs to build the required indices.

## Custom Genomes

When the researcher provides their own FASTA and/or GTF files:

- If the analysis workflow accepts a genome FASTA input directly, pass the custom files to it.
- If pre-built indices are required (see mapping table), run the `prepare-references` workflow with the custom files to build the needed indices first.
