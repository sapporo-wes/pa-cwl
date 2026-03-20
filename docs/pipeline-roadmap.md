# pa-cwl Pipeline Roadmap

Production-ready CWL v1.2 conversions of popular nf-core pipelines.

## Current Workflows

### rnaseq — RNA-seq Analysis

**Status: 1.0 — All 4 pathways tested, RSeQC + featureCounts QC integrated**

All core analysis steps, QC tools, and quantification pathways implemented and tested.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| Trimming (fastp / Trim Galore) | Done | Switchable via input parameter |
| STAR alignment + index | Done | Tested local + Docker |
| HISAT2 alignment + index | Done | Tested local |
| Salmon quant + index | Done | Alignment-based (STAR) and mapping-based (HISAT2) modes |
| RSEM quant + index | Done | Tested via Docker (STAR+RSEM) |
| Kallisto quant + index | Done | Tested local |
| samtools sort/index | Done | |
| Picard MarkDuplicates | Done | |
| featureCounts | Done | Supplementary QC for all genome-aligned paths |
| Count matrix aggregation | Done | gene_counts.tsv + gene_tpm.tsv |
| MultiQC | Done | Integrates FastQC, fastp, STAR, HISAT2, Picard, RSeQC, featureCounts |
| RSeQC bam_stat | Done | BAM alignment statistics |
| RSeQC infer_experiment | Done | Library strandedness inference |
| RSeQC read_distribution | Done | Read distribution over genome features |
| GTF to BED12 conversion | Done | Auto-converted from GTF input for RSeQC |
| Multi-sample scatter | Done | Tested with 2 samples |
| UMI handling | Not planned | Rare in bulk RNA-seq |
| StringTie assembly | Not planned | Novel transcript discovery (niche use case) |
| Qualimap | Not planned | Coverage QC (nice-to-have) |
| Dupradar | Not planned | PCR duplicate assessment (nice-to-have) |
| Preseq | Not planned | Library complexity estimation (nice-to-have) |
| DESeq2 QC | Not planned | PCA, sample distance heatmaps (nice-to-have) |

**Tested pathway matrix:**

| Pathway | Local | Docker |
|---------|-------|--------|
| STAR + Salmon | Pass | Pass |
| STAR + RSEM | — | Pass |
| HISAT2 + Salmon | Pass | Pass |
| Kallisto | Pass | Fail (x86 emulation too slow on ARM Mac) |
| Multi-sample (2 samples) | Pass | — |

Kallisto Docker failure is ARM Mac-specific (BioContainers are x86-only, Rosetta emulation too slow). All pathways expected to work on x86 Linux.

---

### chipseq — ChIP-seq Peak Calling

**Status: 1.0 — Narrow and broad peak modes tested**

ChIP-seq analysis with QC, alignment, filtering, peak calling, and coverage track generation.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| Trimming (fastp / Trim Galore) | Done | Switchable via input parameter |
| BWA-MEM2 alignment + index | Done | Conditional index building |
| samtools sort/index | Done | |
| Picard MarkDuplicates | Done | |
| samtools filter | Done | -F 1804 -f 2 -q 1 (ChIP-seq standard) |
| MACS2 narrow peak calling | Done | For transcription factor binding |
| MACS2 broad peak calling | Done | For histone modifications |
| deepTools bamCoverage | Done | Normalized bigWig generation |
| Optional control sample | Done | IgG/input DNA for background subtraction |
| MultiQC | Done | Integrates FastQC, fastp, Picard |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| Narrow peaks (no control) | Pass |
| Broad peaks (no control) | Pass |

---

### sarek — Germline Variant Calling

**Status: 1.0 — Germline HaplotypeCaller tested (without BQSR)**

Germline variant calling with GATK best practices: alignment, dedup, HaplotypeCaller, hard filtering.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| Trimming (fastp / Trim Galore) | Done | Switchable via input parameter |
| BWA-MEM2 alignment + index | Done | Shared with chipseq/atacseq |
| samtools sort/index | Done | |
| Picard MarkDuplicates | Done | |
| Reference prep (faidx + dict) | Done | Auto-generated if not provided |
| GATK4 HaplotypeCaller | Done | Per-sample VCF or gVCF mode |
| GATK4 VariantFiltration | Done | GATK recommended hard filters |
| samtools stats | Done | Alignment QC for MultiQC |
| bcftools stats | Done | VCF QC for MultiQC |
| MultiQC | Done | Integrates FastQC, fastp, Picard, samtools, bcftools |
| BQSR | Planned v1.1 | Requires known sites VCFs |
| Joint calling (GenomicsDBImport) | Planned v1.1 | Multi-sample cohort calling |
| Somatic calling (Mutect2) | Planned v2.0 | Tumor-normal pairs |
| Annotation (VEP/snpEff) | Planned v2.0 | Functional variant annotation |
| Scatter-gather parallelization | Planned v1.1 | For large genomes |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| Germline (no BQSR, no dbSNP) | Pass |

---

### methylseq — Bisulfite Sequencing Methylation

**Status: 1.0 — Bismark path tested**

Bisulfite sequencing analysis with Bismark: alignment, deduplication, methylation extraction.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| Trim Galore / fastp | Done | Switchable; Trim Galore standard for bisulfite |
| Bismark genome preparation | Done | Conditional index building |
| Bismark alignment | Done | bowtie2 backend |
| Bismark deduplication | Done | |
| samtools sort/index | Done | |
| Bismark methylation extractor | Done | bedGraph + coverage + cytosine report |
| M-bias reports | Done | |
| MultiQC | Done | Integrates FastQC, Bismark reports |
| bwa-meth + MethylDackel path | Planned v1.1 | Alternative aligner |
| RRBS mode (skip dedup) | Planned v1.1 | |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| Bismark (paired-end, Trim Galore) | Pass |

---

### atacseq — ATAC-seq Chromatin Accessibility

**Status: 1.0 — Narrow peak mode tested**

ATAC-seq analysis with QC, alignment, filtering, peak calling (--nomodel), and coverage tracks.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| Trimming (fastp / Trim Galore) | Done | Switchable via input parameter |
| BWA-MEM2 alignment + index | Done | Shared with chipseq |
| samtools sort/index | Done | |
| Picard MarkDuplicates | Done | |
| samtools filter | Done | -F 1804 -f 2 -q 1 |
| MACS2 --nomodel peak calling | Done | ATAC-seq mode: --nomodel --keep-dup all |
| deepTools bamCoverage | Done | Normalized bigWig generation |
| MultiQC | Done | Integrates FastQC, fastp, Picard |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| Narrow peaks | Pass |

---

### fetchngs — Public Data Retrieval

**Status: 1.0 — FTP and sratools paths tested, accession validation + project/GEO resolution**

Downloads FASTQ from ENA/SRA and generates samplesheets for downstream workflows.

| Feature | Status | Notes |
|---------|--------|-------|
| ENA metadata API | Done | 19 metadata fields |
| FTP download + MD5 check | Done | |
| sratools (fasterq-dump) | Done | With gzip integrity check |
| Samplesheet generation | Done | CSV with sample, fastq_1, fastq_2, strandedness |
| Run-level IDs (SRR/ERR/DRR) | Done | |
| Experiment/Sample IDs (SRX/SRS/ERX/ERS) | Done | Resolved via ENA API |
| Project-level IDs (SRP/PRJNA/PRJEB) | Done | Resolved via ENA API |
| GEO IDs (GSE/GSM) | Done | Resolved via NCBI eutils chain |
| BioSample/BioProject IDs (SAMN/PRJNA) | Done | Resolved via ENA API |
| Accession format validation | Done | Regex validation with helpful error messages |
| Deduplication | Done | Across multiple accessions |
| Aspera download | Not planned | FTP + sratools cover most use cases |
| S3/GCP mirror fallback | Not planned | |
| Tests | Done | FTP + sratools tests with small public accessions |

---

### scrnaseq — Single-Cell RNA-seq

**Status: 1.0 — STARsolo path tested (10x v3 format)**

Single-cell RNA-seq quantification using STARsolo. Barcode-aware alignment, UMI deduplication, and gene-barcode count matrix generation.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | Both barcode (R1) and cDNA (R2) reads |
| STAR genome index | Done | Reused from rnaseq pipeline |
| STARsolo alignment + quant | Done | CB_UMI_Simple mode |
| Gene count matrix (raw) | Done | MEX format: barcodes.tsv, features.tsv, matrix.mtx |
| GeneFull count matrix | Done | Includes intronic reads (useful for snRNA-seq) |
| Cell filtering | Done | CellRanger2_3, EmptyDrops_CR, TopCells, or None |
| MultiQC | Done | Integrates FastQC + STAR logs |
| 10x Chromium v2/v3 | Done | Via cb_len/umi_len parameters |
| Drop-seq | Done | cb_len=12, umi_len=8 |
| Alevin-Fry path | Planned v1.1 | Salmon-based pseudo-alignment |
| Kallisto+BUStools path | Planned v1.1 | |
| CellRanger path | Not planned | Licensing constraints |
| Smart-seq2 (plate-based) | Planned v1.1 | No barcode demux needed |
| Empty droplet detection (R) | Planned v1.1 | dropletUtils::emptyDrops |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| STARsolo (10x v3 format, yeast) | Pass |

---

### ampliseq — 16S/ITS Amplicon Sequencing

**Status: 1.0 — DADA2 path tested (16S V4 paired-end)**

Amplicon sequencing analysis with Cutadapt primer trimming and DADA2 for ASV inference, chimera removal, and taxonomy assignment.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| Cutadapt primer trimming | Done | 5'-anchored primer removal, per-sample scatter |
| DADA2 filterAndTrim | Done | Quality filtering with configurable truncation |
| DADA2 learnErrors | Done | Error model learned across all samples |
| DADA2 dada + mergePairs | Done | ASV inference and pair merging |
| DADA2 removeBimeraDenovo | Done | Chimera removal |
| DADA2 assignTaxonomy | Done | Naive Bayesian classifier (SILVA, UNITE) |
| ASV count table | Done | Samples x ASVs CSV |
| Representative sequences | Done | FASTA of unique ASVs |
| MultiQC | Done | Integrates FastQC + Cutadapt |
| QIIME2 integration | Planned v1.1 | Phylogenetic diversity, ordination |
| Single-end mode | Planned v1.1 | |
| Species-level assignment | Planned v1.1 | addSpecies with exact matching |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| 16S V4 paired-end (simulated, 3 ASVs) | Pass |

---

### viralrecon — Viral Variant Calling and Consensus

**Status: 1.0 — iVar amplicon path tested**

Viral genome variant calling and consensus generation using iVar. Supports amplicon (primer-trimmed) and whole-genome sequencing modes.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| Trimming (fastp / Trim Galore) | Done | Switchable via input parameter |
| BWA-MEM2 alignment + index | Done | Shared with chipseq/atacseq/sarek |
| samtools sort/index | Done | |
| Picard MarkDuplicates | Done | |
| iVar trim (primer removal) | Done | Conditional on primer_bed input |
| iVar variants | Done | samtools mpileup piped to ivar variants |
| iVar consensus | Done | Low-coverage positions masked with N |
| samtools stats | Done | Alignment QC for MultiQC |
| MultiQC | Done | Integrates FastQC, fastp, Picard, samtools |
| Pangolin lineage assignment | Planned v1.1 | SARS-CoV-2 specific |
| Nextclade annotation | Planned v1.1 | Multi-pathogen support |
| bcftools variant calling path | Planned v1.1 | Alternative to iVar |
| Kraken2 host filtering | Planned v1.1 | |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| Amplicon (iVar, simulated viral genome) | Pass |

---

### mag — Metagenome-Assembled Genomes

**Status: 1.0 — SPAdes + MetaBAT2 path tested (local, ARM Mac partial)**

Metagenome assembly with SPAdes, contig binning with MetaBAT2, gene prediction with Prodigal.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| fastp trimming | Done | |
| SPAdes (metaSPAdes) assembly | Done | Co-assembly mode |
| MEGAHIT assembly | Done (CWL) | Binary crashes on ARM Mac; works on x86 Linux |
| QUAST assembly QC | Done | N50, total length, # contigs |
| Bowtie2 read mapping | Done | Map reads back to contigs for coverage |
| MetaBAT2 binning | Done (CWL) | jgi_summarize_bam_contig_depths + metabat2 |
| Prodigal gene prediction | Done | Metagenome mode |
| MultiQC | Done | Integrates FastQC, fastp, Bowtie2 |
| Host read removal | Planned v1.1 | Bowtie2 against host reference |
| MaxBin2 | Planned v1.1 | Alternative binner |
| DAS Tool | Planned v1.1 | Bin refinement |
| BUSCO | Planned v1.1 | Bin completeness assessment |
| GTDB-Tk | Planned v1.1 | Bin taxonomic classification |
| Prokka | Planned v1.1 | Bin functional annotation |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| SPAdes + Bowtie2 + Prodigal (simulated, 3 genomes) | Pass |
| MetaBAT2 binning (Docker) | Fail (x86 binary, ARM Mac) |

---

### taxprofiler — Taxonomic Profiling

**Status: 1.0 — Kraken2 + Bracken path tested**

Taxonomic classification with Kraken2 and abundance re-estimation with Bracken.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| fastp trimming | Done | |
| Kraken2 classification | Done | k-mer based, paired-end support |
| Bracken abundance | Done | Bayesian re-estimation from Kraken2 reports |
| MultiQC | Done | Integrates FastQC, fastp, Kraken2 |
| MetaPhlAn | Planned v1.1 | Marker-gene based profiling |
| Centrifuge | Planned v1.1 | FM-index based classification |
| Krona visualization | Planned v1.1 | Interactive taxonomy plots |
| Taxpasta | Planned v1.1 | Standardized output format |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| Kraken2 + Bracken (viral DB, simulated reads) | Pass |

---

### nanoseq — Nanopore Long-Read Sequencing

**Status: 1.0 — minimap2 alignment + NanoPlot QC tested**

Nanopore long-read sequencing analysis with NanoPlot QC, minimap2 alignment, and MultiQC reporting.

| Feature | Status | Notes |
|---------|--------|-------|
| NanoPlot QC | Done | Read length distributions, quality scores |
| FastQC | Done | General QC |
| minimap2 alignment | Done | map-ont (DNA), splice (RNA) presets |
| samtools sort/index | Done | |
| samtools stats | Done | Alignment statistics for MultiQC |
| MultiQC | Done | Integrates NanoStat, FastQC, samtools |
| NanoFilt quality filtering | Planned v1.1 | |
| StringTie2 transcript assembly | Planned v1.1 | For RNA mode |
| Variant calling (medaka) | Planned v1.1 | Short variants from Nanopore reads |
| Structural variants (sniffles) | Planned v1.1 | |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| DNA (map-ont, simulated 500 reads) | Pass |

---

### rnafusion — Gene Fusion Detection

**Status: 1.0 — Arriba path tested (Docker)**

Gene fusion detection from RNA-seq data using STAR chimeric alignment and Arriba.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| fastp trimming | Done | |
| STAR alignment (chimeric mode) | Done | chimSegmentMin, chimOutType WithinBAM |
| Arriba fusion detection | Done | Blacklist auto-disabled when not provided |
| samtools index | Done | |
| MultiQC | Done | Integrates FastQC, fastp, STAR |
| STAR-Fusion | Planned v1.1 | CTAT resource bundle required |
| FusionCatcher | Planned v1.1 | |
| FusionInspector | Planned v1.1 | Post-processing validation |
| Arriba visualization | Planned v1.1 | draw_fusions.R |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| Arriba (simulated GENEA-GENEB fusion, 499 reads) | Pass |

---

### raredisease — Rare Disease Variant Calling and Annotation

**Status: 1.0 — sarek + VEP annotation tested (Docker)**

Extends the sarek germline variant calling pipeline with Ensembl VEP annotation.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC + fastp | Done | Reused from sarek |
| BWA-MEM2 alignment | Done | Reused from sarek |
| Picard MarkDuplicates | Done | Reused from sarek |
| GATK HaplotypeCaller | Done | Reused from sarek |
| GATK VariantFiltration | Done | Reused from sarek |
| Ensembl VEP annotation | Done | Cache or GFF mode, auto-bgzip GFF |
| samtools stats | Done | |
| bcftools stats | Done | |
| MultiQC | Done | |
| DeepVariant | Planned v1.1 | Alternative SNV caller |
| Joint calling | Planned v1.1 | GenomicsDBImport + GenotypeGVCFs |
| SV calling (Manta) | Planned v1.1 | |
| CADD scores | Planned v1.1 | Pathogenicity scoring |
| GENMOD ranking | Planned v1.1 | Pedigree-aware variant ranking |
| ExpansionHunter | Planned v1.1 | Repeat expansion detection |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| VEP annotation (GFF3 mode, synthetic genome) | Pass |

---

### cutandrun — CUT&RUN/CUT&TAG Peak Calling

**Status: 1.0 — Narrow peak mode tested (local)**

CUT&RUN and CUT&TAG analysis with Bowtie2 alignment, MACS2 peak calling (--nomodel), and bigWig coverage tracks.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| fastp trimming | Done | |
| Bowtie2 alignment | Done | With read group tags |
| Picard MarkDuplicates | Done | |
| samtools filter | Done | -F 1804 -f 2 -q 1 |
| samtools index | Done | |
| MACS2 --nomodel peak calling | Done | Narrow (TF) or broad (histone) modes |
| deepTools bamCoverage | Done | Normalized bigWig generation |
| Optional IgG control | Done | Optional control inputs in workflow |
| MultiQC | Done | Integrates FastQC, fastp, Bowtie2, Picard |
| SEACR peak calling | Planned v1.1 | Alternative to MACS2 for CUT&RUN |
| Spike-in normalization | Planned v1.1 | E. coli spike-in calibration |
| Fragment size QC | Planned v1.1 | CUT&RUN diagnostic plots |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| Narrow peaks (no control, yeast) | Pass |

---

### hic — Hi-C Chromatin Conformation Capture

**Status: 1.0 — MboI/DpnII protocol tested (Docker)**

Hi-C chromatin interaction analysis with two-step Bowtie2 alignment, pairtools valid pair extraction and deduplication, and cooler contact map generation with ICE normalization.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| fastp trimming | Done | |
| Two-step Bowtie2 mapping | Done | Chimeric read rescue at ligation junctions |
| SAM flag tagging | Done | Paired-end flags for pairtools compatibility |
| pairtools parse | Done | Valid pair extraction from name-sorted BAM |
| pairtools sort + dedup | Done | Duplicate removal with statistics |
| cooler cload | Done | Contact matrix at specified resolution |
| cooler zoomify | Done | Multi-resolution .mcool with ICE balancing |
| MultiQC | Done | Integrates FastQC, fastp, Bowtie2 logs |
| TAD calling (HiCExplorer) | Planned v1.1 | |
| A/B compartments (cooltools) | Planned v1.1 | |
| Juicer .hic conversion | Planned v1.1 | |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| MboI/DpnII (simulated 500 reads, 3 chromosomes) | Pass |

---

## Conversion Targets

Ranked by GitHub stars (proxy for community adoption). All are released/stable nf-core pipelines.

### Tier 1 — Highest impact, significant tool overlap with rnaseq

| Pipeline | Stars | Domain | Description | Shared tools |
|----------|-------|--------|-------------|--------------|
| ~~**sarek**~~ | 554 | Variant Calling | **Done (1.0 germline)** — see sarek section above |  |
| ~~**chipseq**~~ | 233 | Epigenomics | **Done (1.0)** — see chipseq section above |  |
| ~~**atacseq**~~ | 220 | Epigenomics | **Done (1.0)** — see atacseq section above |  |

### Tier 2 — High impact, some new tool domains

| Pipeline | Stars | Domain | Description | New tools needed |
|----------|-------|--------|-------------|-----------------|
| ~~**scrnaseq**~~ | 316 | Single-cell | **Done (1.0 STARsolo)** — see scrnaseq section above |  |
| ~~**methylseq**~~ | 189 | Epigenomics | **Done (1.0 Bismark)** — see methylseq section above |  |
| ~~**ampliseq**~~ | 236 | Microbiome | **Done (1.0 DADA2)** — see ampliseq section above |  |
| ~~**viralrecon**~~ | 159 | Virology | **Done (1.0 iVar amplicon)** — see viralrecon section above |  |

### Tier 3 — Specialized, mostly new tool stacks

| Pipeline | Stars | Domain | Description | Notes |
|----------|-------|--------|-------------|-------|
| ~~**mag**~~ | 279 | Metagenomics | **Done (1.0 SPAdes + MetaBAT2)** — see mag section above |  |
| ~~**taxprofiler**~~ | 180 | Metagenomics | **Done (1.0 Kraken2 + Bracken)** — see taxprofiler section above |  |
| ~~**nanoseq**~~ | 220 | Long-read | **Done (1.0 minimap2 + NanoPlot)** — see nanoseq section above |  |
| ~~**rnafusion**~~ | 172 | Transcriptomics | **Done (1.0 Arriba)** — see rnafusion section above |  |

### Tier 4 — Niche but valuable

| Pipeline | Stars | Domain | Description | Notes |
|----------|-------|--------|-------------|-------|
| ~~**raredisease**~~ | 114 | Clinical Genomics | **Done (1.0 sarek + VEP)** — see raredisease section above |  |
| ~~**cutandrun**~~ | 109 | Epigenomics | **Done (1.0)** — see cutandrun section above |  |
| ~~**hic**~~ | 108 | 3D Genomics | **Done (1.0)** — see hic section above |  |

### Not targeted

| Pipeline | Stars | Why skip |
|----------|-------|---------|
| eager | 200 | Ancient DNA — very niche audience |
| pangenome | 104 | Specialized graph genome tools |
| funcscan | 103 | AMR/AMP screening — narrow use case |
| proteinfold | 99 | GPU-dependent (AlphaFold2) — poor fit for CWL/WES |
| smrnaseq | 98 | Small RNA — low demand |

---

## Suggested Conversion Order

Prioritized by impact, tool reuse, and incremental complexity:

```
Done                  Next up — shared tooling builds on previous
  │                         │
  ▼                         ▼
✓ rnaseq (1.0)        fastp, samtools, picard, MultiQC, STAR, featureCounts, RSeQC
✓ fetchngs (1.0)      utility — feeds all pipelines
✓ chipseq (1.0)       + BWA-MEM2, MACS2, deepTools, samtools-filter
✓ atacseq (1.0)       ~90% shared with chipseq + --nomodel
✓ sarek (1.0)         + GATK4 HaplotypeCaller, VariantFiltration, prepare-gatk-reference
✓ methylseq (1.0)     + Bismark (genome-prep, align, dedup, methylation-extractor)
✓ scrnaseq (1.0)      + STARsolo (barcode-aware alignment + count matrices)
✓ viralrecon (1.0)    + ivar (trim, variants, consensus)
✓ ampliseq (1.0)      + cutadapt, DADA2 (R-based ASV inference + taxonomy)
✓ mag (1.0)           + SPAdes, Bowtie2, MetaBAT2, Prodigal, QUAST
✓ taxprofiler (1.0)   + Kraken2, Bracken
✓ nanoseq (1.0)       + minimap2, NanoPlot
✓ rnafusion (1.0)     + Arriba, STAR chimeric mode
✓ raredisease (1.0)   + Ensembl VEP annotation
✓ cutandrun (1.0)      chipseq tools + Bowtie2 + MACS2 --nomodel
✓ hic (1.0)            Bowtie2 + pairtools + cooler
```

---

## Tool Reuse Matrix

Tools already in `tools/` that will be reused across pipelines:

| Tool | rnaseq | chipseq | atacseq | sarek | methylseq | scrnaseq | viralrecon | ampliseq | mag | taxprofiler | nanoseq | cutandrun | hic |
|------|--------|---------|---------|-------|-----------|----------|------------|----------|-----|-------------|---------|-----------|-----|
| fastp | x | x | x | x | x | x | x | | x | x | | x | x |
| fastqc | x | x | x | x | x | x | x | x | x | x | x | x | x |
| multiqc | x | x | x | x | x | x | x | x | x | x | x | x | x |
| samtools-sort | x | x | x | x | x | | x | | | | x | | |
| samtools-index | x | x | x | x | x | | x | | | | x | x | |
| samtools-filter | | x | x | | | | | | | | | x | |
| samtools-stats | | | | x | | | x | | | | x | | |
| picard-markduplicates | x | x | x | x | x | | | | | | | x | |
| star-align | x | | | | | | | | | | | | |
| star-genome-generate | x | | | | | x | | | | | | | |
| starsolo | | | | | | x | | | | | | | |
| featurecounts | x | x | x | | | | | | | | | | |
| pigz | x | x | x | x | x | x | x | | | | | | |
| trim-galore | x | x | x | | x | | | | | | | | |
| bowtie2-align | | | | | | | | | x | | | x | |
| macs2-callpeak | | x | x | | | | | | | | | x | |
| deeptools-bamcoverage | | x | x | | | | | | | | | x | |

New shared tools added:
- **bwa-mem2** (index + align) — chipseq ✓, atacseq, sarek, methylseq
- **deeptools** (bamCoverage) — chipseq ✓, atacseq
- **samtools-filter** — chipseq ✓, atacseq
- **samtools-sort-index** — chipseq ✓ (combined sort+index)
- **macs2-callpeak** — chipseq ✓, atacseq

New tools added:
- **starsolo** — scrnaseq ✓ (STARsolo barcode-aware alignment + count matrices)
- **cutadapt** — ampliseq ✓ (5'-anchored primer trimming)
- **dada2-denoise** — ampliseq ✓ (full DADA2 pipeline: filter → error learning → denoise → merge → chimera removal)
- **dada2-assign-taxonomy** — ampliseq ✓ (naive Bayesian taxonomy assignment)
- **megahit** — mag ✓ (de novo metagenome assembly)
- **spades** — mag ✓ (metaSPAdes metagenome assembly)
- **bowtie2-build** — mag ✓ (build Bowtie2 index)
- **bowtie2-align** — mag ✓ (short read alignment with sorted BAM output)
- **metabat2** — mag ✓ (depth calculation + metagenome binning)
- **prodigal** — mag ✓ (prokaryotic gene prediction)
- **quast** — mag ✓ (assembly quality assessment)
- **kraken2** — taxprofiler ✓ (k-mer taxonomic classification)
- **bracken** — taxprofiler ✓ (Bayesian abundance re-estimation)
- **minimap2** — nanoseq ✓ (long-read alignment, Nanopore/PacBio)
- **nanoplot** — nanoseq ✓ (Nanopore QC: read length, quality, throughput)
- **star-align-fusion** — rnafusion ✓ (STAR with chimeric detection for fusion calling)
- **arriba** — rnafusion ✓ (gene fusion detection from STAR chimeric alignments)
- **ensembl-vep** — raredisease ✓ (variant effect prediction, consequence annotation)
- **hic-mapping** — hic ✓ (two-step Bowtie2 Hi-C mapping with chimeric read rescue)
- **pairtools-process** — hic ✓ (Hi-C pair parsing, sorting, deduplication)
- **cooler-cload** — hic ✓ (contact matrix generation from pairs)
- **cooler-zoomify** — hic ✓ (multi-resolution mcool with ICE normalization)

New shared tools needed next:
- **bedtools** — atacseq, sarek, viralrecon
- **bcftools** — sarek, viralrecon
