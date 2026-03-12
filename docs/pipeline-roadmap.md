# pa-cwl Pipeline Roadmap

Production-ready CWL v1.2 conversions of popular nf-core pipelines.

## Current Workflows

### rnaseq — RNA-seq Analysis

**Status: Alpha — STAR+Salmon pathway tested, others untested**

Core analysis steps are implemented. QC-only tools (RSeQC, Qualimap, etc.) are not yet included.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| Trimming (fastp / Trim Galore) | Done | Switchable via input parameter |
| STAR alignment + index | Done | Tested with yeast simulated data (local + Docker) |
| HISAT2 alignment + index | Done | Tool exists, pathway untested |
| Salmon quant + index | Done | Alignment-based and mapping-based modes |
| RSEM quant + index | Done | Tool exists, pathway untested |
| Kallisto quant + index | Done | Tool exists, pathway untested |
| samtools sort/index | Done | |
| Picard MarkDuplicates | Done | |
| featureCounts | Done | |
| Count matrix aggregation | Done | gene_counts.tsv + gene_tpm.tsv |
| MultiQC | Done | |
| UMI handling | Not planned | Rare in bulk RNA-seq |
| StringTie assembly | Missing | Novel transcript discovery |
| RSeQC suite | Missing | bam_stat, infer_experiment, junction metrics, etc. |
| Qualimap | Missing | Alignment coverage QC |
| Dupradar | Missing | PCR duplicate assessment |
| Preseq | Missing | Library complexity estimation |
| DESeq2 QC | Missing | PCA, sample distance heatmaps |

**Remaining work to reach beta:**
1. Test HISAT2+Salmon and HISAT2+featureCounts pathways
2. Test Kallisto-only pathway
3. Add RSeQC (at minimum: infer_experiment, bam_stat, read_distribution)
4. Fix agent.yaml inconsistencies (transcript_counts output declared but not produced, strandedness "auto" not in CWL)
5. Multi-sample test (current test uses 1 sample)

---

### fetchngs — Public Data Retrieval

**Status: Alpha — FTP download works, limited accession type support**

Downloads FASTQ from ENA/SRA and generates samplesheets for downstream workflows.

| Feature | Status | Notes |
|---------|--------|-------|
| ENA metadata API | Done | 19 metadata fields |
| FTP download + MD5 check | Done | |
| sratools (fasterq-dump) | Done | No MD5 validation on this path |
| Samplesheet generation | Done | CSV with sample, fastq_1, fastq_2, strandedness |
| Run-level IDs (SRR/ERR/DRR) | Done | |
| Project-level IDs (SRP/PRJNA) | Missing | Needs ID-to-run resolution |
| GEO IDs (GSE/GSM) | Missing | Needs GEO API |
| Aspera download | Missing | |
| S3/GCP mirror fallback | Missing | |
| Input validation | Missing | No accession format checking |
| Tests | Missing | tests/ directory is empty |

**Remaining work to reach beta:**
1. Add project-level ID resolution (SRP/PRJNA/PRJEB → individual SRR/ERR runs)
2. Add accession format validation
3. Fix agent.yaml/main.cwl parameter mismatches (download_method naming, output_format)
4. Write tests with small public dataset
5. Add MD5 validation to sratools path

---

## Conversion Targets

Ranked by GitHub stars (proxy for community adoption). All are released/stable nf-core pipelines.

### Tier 1 — Highest impact, significant tool overlap with rnaseq

| Pipeline | Stars | Domain | Description | Shared tools |
|----------|-------|--------|-------------|--------------|
| **sarek** | 554 | Variant Calling | Germline + somatic variant calling from WGS/WES/targeted. GATK HaplotypeCaller, Mutect2, Strelka2, DeepVariant, Manta, TIDDIT. | fastp, STAR (for RNA), BWA-MEM2, samtools, picard, MultiQC |
| **chipseq** | 233 | Epigenomics | ChIP-seq peak calling and differential binding analysis. BWA, MACS2, DiffBind, Homer. | fastp, samtools, picard, MultiQC, featureCounts |
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
Already done          Shared tooling builds on previous
    │                         │
    ▼                         ▼
1. rnaseq (finish)     fastp, samtools, picard, MultiQC
2. fetchngs (finish)   utility — feeds all pipelines
3. chipseq             + BWA-MEM, MACS2, deepTools
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

New shared tools needed early:
- **bwa-mem2** — chipseq, atacseq, sarek, methylseq
- **deeptools** — chipseq, atacseq (bamCoverage, plotFingerprint, etc.)
- **bedtools** — chipseq, atacseq, sarek, viralrecon
- **bcftools** — sarek, viralrecon
