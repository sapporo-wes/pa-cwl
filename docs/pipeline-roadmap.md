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

## Conversion Targets

Ranked by GitHub stars (proxy for community adoption). All are released/stable nf-core pipelines.

### Tier 1 — Highest impact, significant tool overlap with rnaseq

| Pipeline | Stars | Domain | Description | Shared tools |
|----------|-------|--------|-------------|--------------|
| **sarek** | 554 | Variant Calling | Germline + somatic variant calling from WGS/WES/targeted. GATK HaplotypeCaller, Mutect2, Strelka2, DeepVariant, Manta, TIDDIT. | fastp, STAR (for RNA), BWA-MEM2, samtools, picard, MultiQC |
| ~~**chipseq**~~ | 233 | Epigenomics | **Done (1.0)** — see chipseq section above |  |
| **atacseq** | 220 | Epigenomics | ATAC-seq chromatin accessibility. BWA, MACS2, genrich, deepTools. | fastp, samtools, picard, MultiQC (nearly identical to chipseq) |

### Tier 2 — High impact, some new tool domains

| Pipeline | Stars | Domain | Description | New tools needed |
|----------|-------|--------|-------------|-----------------|
| **scrnaseq** | 316 | Single-cell | 10x, Drop-seq, Smart-seq2 scRNA-seq. STARsolo, CellRanger, Alevin, Kallisto-BUStools. | STARsolo, cellranger, alevin-fry, bustools, scanpy/seurat |
| **methylseq** | 189 | Epigenomics | Bisulfite/EM-seq methylation. Bismark or bwa-meth + MethylDackel. | bismark, bwa-meth, methyldackel |
| **ampliseq** | 236 | Microbiome | 16S/ITS/18S amplicon analysis. Cutadapt, DADA2, QIIME2. | cutadapt, DADA2, QIIME2 (R/Python heavy) |
| **viralrecon** | 159 | Virology | Viral genome assembly + variant calling. Used massively for SARS-CoV-2 surveillance. | ivar, nextclade, pangolin, bcftools, bedtools |

### Tier 3 — Specialized, mostly new tool stacks

| Pipeline | Stars | Domain | Description | Notes |
|----------|-------|--------|-------------|-------|
| **mag** | 279 | Metagenomics | Metagenome assembly, binning, annotation. megahit, metaSPAdes, MetaBAT2, GTDB-Tk. | Complex; many domain-specific tools |
| **taxprofiler** | 180 | Metagenomics | Multi-tool taxonomic profiling. Kraken2, Bracken, MetaPhlAn, Centrifuge, DIAMOND, mOTUs. | Many classifiers, large reference DBs |
| **nanoseq** | 220 | Long-read | Nanopore QC, demux, alignment. minimap2, NanoPlot, pycoQC. | minimap2, nanopore-specific tools |
| **rnafusion** | 172 | Transcriptomics | Gene fusion detection. STAR-Fusion, Arriba, FusionCatcher, pizzly. | Fusion-specific tools, large reference data |

### Tier 4 — Niche but valuable

| Pipeline | Stars | Domain | Description | Notes |
|----------|-------|--------|-------------|-------|
| **raredisease** | 114 | Clinical Genomics | Rare disease WGS/WES. Overlaps heavily with sarek + annotation (VEP, CADD). | Do sarek first |
| **cutandrun** | 109 | Epigenomics | CUT&RUN/CUT&TAG. Shares ~80% with chipseq. | Do chipseq first |
| **hic** | 108 | 3D Genomics | Hi-C analysis. HiCUP, cooler, juicer, HiGlass. | Specialized tooling |

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
4. atacseq             ~90% shared with chipseq
5. sarek               + GATK, Mutect2, Strelka2, DeepVariant, BWA-MEM2, VEP
6. methylseq           + Bismark, bwa-meth, MethylDackel
7. scrnaseq            + STARsolo, alevin-fry, bustools
8. viralrecon          + ivar, nextclade, pangolin
9. ampliseq            + DADA2, QIIME2 (R/Python heavy)
10. mag                + megahit, MetaBAT2, GTDB-Tk
11. taxprofiler        + Kraken2, MetaPhlAn, Centrifuge
12. nanoseq            + minimap2, NanoPlot
13. rnafusion          + STAR-Fusion, Arriba
14. raredisease        sarek + annotation extensions
15. cutandrun          chipseq + spike-in normalization
16. hic                new stack (HiCUP, cooler)
```

---

## Tool Reuse Matrix

Tools already in `tools/` that will be reused across pipelines:

| Tool | rnaseq | chipseq | atacseq | sarek | methylseq | scrnaseq | viralrecon |
|------|--------|---------|---------|-------|-----------|----------|------------|
| fastp | x | x | x | x | x | x | x |
| fastqc | x | x | x | x | x | x | x |
| multiqc | x | x | x | x | x | x | x |
| samtools-sort | x | x | x | x | x | | x |
| samtools-index | x | x | x | x | x | | x |
| picard-markduplicates | x | x | x | x | x | | |
| star-align | x | | | | | x | |
| star-genome-generate | x | | | | | x | |
| featurecounts | x | x | x | | | | |
| pigz | x | x | x | x | x | x | x |
| trim-galore | x | x | x | | x | | |

New shared tools added:
- **bwa-mem2** (index + align) — chipseq ✓, atacseq, sarek, methylseq
- **deeptools** (bamCoverage) — chipseq ✓, atacseq
- **samtools-filter** — chipseq ✓, atacseq
- **samtools-sort-index** — chipseq ✓ (combined sort+index)
- **macs2-callpeak** — chipseq ✓, atacseq

New shared tools needed next:
- **bedtools** — atacseq, sarek, viralrecon
- **bcftools** — sarek, viralrecon
