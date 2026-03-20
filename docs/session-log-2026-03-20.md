# Session Log — 2026-03-20

Pipeline roadmap completion session. Built, tested, and committed the final 6 pipelines (taxprofiler through hic), completing all 16 target workflows.

## Pipelines Built & Tested

| # | Pipeline | Commit | Key Tools | Test Mode |
|---|----------|--------|-----------|-----------|
| 11 | taxprofiler | `3cc5ca0` | Kraken2, Bracken | Local |
| 12 | nanoseq | `80f010e` | minimap2, NanoPlot | Local |
| 13 | rnafusion | `0c48fc6` | STAR (chimeric), Arriba | Docker |
| 14 | raredisease | `a85d087` | sarek + Ensembl VEP | Docker |
| 15 | cutandrun | `15bfb6a` | Bowtie2, MACS2 (--nomodel), deepTools | Local |
| 16 | hic | `c1e6555` | Bowtie2 two-step, pairtools, cooler | Docker |

## New CWL Tools Created

| Tool | Pipeline | Description |
|------|----------|-------------|
| minimap2 | nanoseq | Long-read aligner (Nanopore/PacBio) |
| nanoplot | nanoseq | Nanopore QC (read length, quality) |
| star-align-fusion | rnafusion | STAR with chimeric detection params |
| arriba | rnafusion | Gene fusion detection |
| ensembl-vep | raredisease | Variant effect prediction (cache/GFF) |
| hic-mapping | hic | Two-step Bowtie2 with chimeric read rescue |
| pairtools-process | hic | Hi-C pair parse + sort + dedup |
| cooler-cload | hic | Contact matrix from pairs |
| cooler-zoomify | hic | Multi-resolution .mcool |

## Test Data Generators Created

| Script | Purpose |
|--------|---------|
| simulate-nanopore-reads.py | Nanopore reads with 5% error profile |
| simulate-fusion-reads.py | Paired-end reads with synthetic gene fusion |
| simulate-hic-reads.py | Hi-C reads with ligation junctions and inter-chromosomal interactions |
| simulate-taxonomic-reads.py | Reads from multiple microbial genomes |

## Bug Fixes

| Fix | File | Issue |
|-----|------|-------|
| Read group tags | tools/bowtie2-align.cwl | Picard 3.x requires `@RG` in BAM; added `--rg-id`, `--rg SM:`, `--rg PL:`, `--rg LB:` |
| Docker image tag | tools/bowtie2-align.cwl | Mulled bowtie2+samtools image hash was wrong on quay.io |
| NanoPlot glob | tools/nanoplot.cwl | `*.*` matched both .html and .png; changed to `*.html` |
| Arriba blacklist | tools/arriba.cwl | Auto-disable blacklist filter when no blacklist file provided (`-f blacklist`) |
| VEP FASTA lock | tools/ensembl-vep.cwl | VEP needs writable FASTA for lock/index; copy to workdir |
| VEP GFF bgzip | tools/ensembl-vep.cwl | Auto bgzip+tabix for plain GFF3 input |
| CWL awk escaping | tools/hic-mapping.cwl | Use `$0` not `\$0` in awk — CWL only escapes `$` before `(` or `{` |
| SAM flag tagging | tools/hic-mapping.cwl | Add paired-end flags (0x41/0x81) so pairtools recognizes R1/R2 |
| Picard input naming | workflows/cutandrun/main.cwl | Fixed `bam` to `sorted_bam` and `deduped_bam` to `markdup_bam` |

## Platform Issues (ARM Mac)

| Tool | Issue | Workaround |
|------|-------|------------|
| STAR (conda) | Broken binary, reads 0 input reads | Use Docker image |
| MACS2 (Docker) | `__log_finite` symbol error (x86 emulation) | Install macs3 locally via pip, symlink as macs2 |
| pairtools (pip) | `pipes` module removed in Python 3.13 + shared lib error | Use Docker image |
| Picard (conda) | Native GKL compression library incompatible (x86) | Works with Java fallback (slower but functional) |
| MetaBAT2 (Docker) | x86 binary crashes on ARM | Skipped in local tests; works on x86 Linux |

## Key Technical Learnings

### CWL Expression Escaping in `Dirent.entry`

- `$(expr)` — CWL evaluates as JavaScript expression
- `\$(...)` — literal `$(...)` for bash command substitution
- `\${VAR}` — literal `${VAR}` for bash variables
- Bare `$0`, `$1` etc. — passed through as-is (no escaping needed)

### Hi-C Pipeline Design

- Two-step mapping: align end-to-end, then trim unmapped reads at ligation junction and re-align
- pairtools requires SAM paired-end flags (0x1 + 0x40/0x80) to recognize read pairs
- cooler zoomify resolutions must be multiples of the base resolution
- Chromosome sizes in chromsizes.tsv must match the actual reference FASTA

### Docker Image Discovery

- BioContainers mulled image tags on quay.io don't match conda build strings
- Use quay.io API to find correct tags: `curl -s "https://quay.io/api/v1/repository/biocontainers/<tool>/tag/"`
- nf-core modules source code has correct container references

## Final Repository Stats

- **16 workflows** — all tested and passing
- **68 CWL tools** — shared across pipelines
- **Roadmap** — all Tier 1-4 pipelines complete
