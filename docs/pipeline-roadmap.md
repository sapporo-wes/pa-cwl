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

**Status: 2.0 — Germline HaplotypeCaller + somatic Mutect2, optional VEP annotation**

Germline and somatic variant calling with GATK best practices. Germline: HaplotypeCaller with optional BQSR, interval scatter, joint calling, hard filtering. Somatic: Mutect2 tumor-normal calling with orientation bias learning, contamination estimation, and FilterMutectCalls. Optional Ensembl VEP functional annotation in either mode.

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
| BQSR (BaseRecalibrator + ApplyBQSR) | Done v1.1 | Conditional on known_sites input |
| Joint calling (GenomicsDBImport + GenotypeGVCFs) | Done v1.1 | Conditional on emit_gvcf=true |
| samtools stats | Done | Alignment QC for MultiQC |
| bcftools stats | Done | VCF QC for MultiQC |
| MultiQC | Done | Integrates FastQC, fastp, Picard, samtools, bcftools |
| Somatic calling (Mutect2) | Done v2.0 | Tumor-normal pairs with contamination estimation |
| VEP annotation | Done v2.0 | Conditional Ensembl VEP in germline or somatic mode |
| Scatter-gather (HaplotypeCaller) | Done v1.1 | Interval-based HaplotypeCaller scatter |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| Germline (no BQSR, no dbSNP) | Pass |
| Germline + BQSR (yeast, known sites VCF) | Pass |
| Joint calling (yeast, 2 samples) | Pass |

---

### methylseq — Bisulfite Sequencing Methylation

**Status: 1.1 — Bismark and bwa-meth paths, RRBS mode**

Bisulfite sequencing analysis with dual aligner support: Bismark or bwa-meth + MethylDackel. RRBS mode skips deduplication.

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
| bwa-meth + MethylDackel path | Done v1.1 | Conditional on aligner="bwameth"; index + align + markdup + extract |
| MultiQC | Done | Integrates FastQC, Bismark reports |
| RRBS mode (skip dedup) | Done v1.1 | Conditional deduplication skip |

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

**Status: 1.1 — STARsolo, Alevin-Fry, Kallisto/BUStools, Smart-seq2**

Single-cell RNA-seq quantification with four paths: STARsolo, Alevin-Fry/simpleaf, Kallisto/BUStools, and Smart-seq2 (plate-based). Optional emptyDrops QC.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | Both barcode (R1) and cDNA (R2) reads |
| STAR genome index | Done | Reused from rnaseq pipeline |
| STARsolo alignment + quant | Done | CB_UMI_Simple mode |
| Gene count matrix (raw) | Done | MEX format: barcodes.tsv, features.tsv, matrix.mtx |
| GeneFull count matrix | Done | Includes intronic reads (useful for snRNA-seq) |
| Cell filtering | Done | CellRanger2_3, EmptyDrops_CR, TopCells, or None |
| Alevin-Fry path (simpleaf) | Done v1.1 | Conditional on quantifier="alevin-fry"; splici index + quant |
| MultiQC | Done | Integrates FastQC + STAR logs |
| 10x Chromium v2/v3 | Done | Via cb_len/umi_len parameters |
| Drop-seq | Done | cb_len=12, umi_len=8 |
| Kallisto+BUStools path | Done v1.1 | Conditional on quantifier="kallisto"; kb-ref + kb-count |
| CellRanger path | Not planned | Licensing constraints |
| Smart-seq2 (plate-based) | Done v1.1 | Conditional on quantifier="smartseq2"; STAR + featureCounts |
| Empty droplet detection (R) | Done v1.1 | dropletUtils::emptyDrops; conditional on run_emptydrops=true |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| STARsolo (10x v3 format, yeast) | Pass |

---

### ampliseq — 16S/ITS Amplicon Sequencing

**Status: 1.1 — DADA2 path tested, single-end mode, species assignment, QIIME2 diversity**

Amplicon sequencing analysis with Cutadapt primer trimming and DADA2 for ASV inference, chimera removal, taxonomy/species assignment. Supports paired-end and single-end data. Optional QIIME2 diversity analysis.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| Cutadapt primer trimming | Done | 5'-anchored primer removal, per-sample scatter |
| DADA2 filterAndTrim | Done | Quality filtering with configurable truncation |
| DADA2 learnErrors | Done | Error model learned across all samples |
| DADA2 dada + mergePairs | Done | ASV inference and pair merging (PE only) |
| DADA2 removeBimeraDenovo | Done | Chimera removal |
| DADA2 assignTaxonomy | Done | Naive Bayesian classifier (SILVA, UNITE) |
| ASV count table | Done | Samples x ASVs CSV |
| Representative sequences | Done | FASTA of unique ASVs |
| Single-end mode | Done v1.1 | Optional fastq_rev/primer_rev; DADA2 skips pair merging |
| MultiQC | Done | Integrates FastQC + Cutadapt |
| QIIME2 diversity | Done v1.1 | Conditional on run_qiime2=true; Shannon, observed features, Bray-Curtis, UniFrac |
| Species-level assignment | Done v1.1 | Conditional on species_db; DADA2 addSpecies |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| 16S V4 paired-end (simulated, 3 ASVs) | Pass |

---

### viralrecon — Viral Variant Calling and Consensus

**Status: 1.1 — iVar + bcftools, Pangolin, Nextclade, Kraken2 host filtering**

Viral genome variant calling and consensus generation. Primary iVar path plus optional bcftools, Pangolin lineage, Nextclade annotation, and Kraken2 host read filtering.

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
| bcftools variant calling path | Done v1.1 | Conditional on run_bcftools=true; mpileup+call+stats |
| Pangolin lineage assignment | Done v1.1 | Conditional on run_pangolin=true |
| samtools stats | Done | Alignment QC for MultiQC |
| MultiQC | Done | Integrates FastQC, fastp, Picard, samtools, bcftools stats |
| Nextclade annotation | Done v1.1 | Conditional on run_nextclade=true; multi-pathogen support |
| Kraken2 host filtering | Done v1.1 | Conditional on kraken2_db input; pre-alignment host removal |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| Amplicon (iVar, simulated viral genome) | Pass |

---

### mag — Metagenome-Assembled Genomes

**Status: 1.1 — SPAdes + MetaBAT2/MaxBin2, DAS Tool, BUSCO, GTDB-Tk, Prokka**

Metagenome assembly with SPAdes, contig binning with MetaBAT2 and optional MaxBin2, optional bin refinement with DAS Tool, optional bin quality assessment with BUSCO, optional taxonomic classification with GTDB-Tk, optional functional annotation with Prokka, gene prediction with Prodigal. Optional host read removal with Bowtie2.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| fastp trimming | Done | |
| SPAdes (metaSPAdes) assembly | Done | Co-assembly mode |
| MEGAHIT assembly | Done (CWL) | Binary crashes on ARM Mac; works on x86 Linux |
| QUAST assembly QC | Done | N50, total length, # contigs |
| Bowtie2 read mapping | Done | Map reads back to contigs for coverage |
| MetaBAT2 binning | Done (CWL) | jgi_summarize_bam_contig_depths + metabat2 |
| DAS Tool bin refinement | Done v1.1 | Conditional on run_das_tool=true; scaffolds2bin + DAS_Tool |
| BUSCO bin quality | Done v1.1 | Conditional on busco_lineage input; scattered per bin |
| Prodigal gene prediction | Done | Metagenome mode |
| MultiQC | Done | Integrates FastQC, fastp, Bowtie2 |
| Host read removal | Done v1.1 | Conditional on host_index_files; Bowtie2 against host reference |
| MaxBin2 | Done v1.1 | Conditional on run_maxbin2=true; alternative binner |
| GTDB-Tk | Done v1.1 | Conditional on gtdbtk_db; bin taxonomic classification |
| Prokka | Done v1.1 | Conditional on run_prokka=true; bin functional annotation |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| SPAdes + Bowtie2 + Prodigal (simulated, 3 genomes) | Pass |
| MetaBAT2 binning (Docker) | Fail (x86 binary, ARM Mac) |

---

### taxprofiler — Taxonomic Profiling

**Status: 1.1 — Kraken2 + Bracken, MetaPhlAn, Centrifuge, Krona, Taxpasta**

Taxonomic classification with Kraken2/Bracken, optional MetaPhlAn marker-gene profiling, optional Centrifuge FM-index classification, optional Krona visualization, and optional Taxpasta profile merging.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| fastp trimming | Done | |
| Kraken2 classification | Done | k-mer based, paired-end support |
| Bracken abundance | Done | Bayesian re-estimation from Kraken2 reports |
| MetaPhlAn | Done v1.1 | Conditional on metaphlan_db input; marker-gene profiling |
| MultiQC | Done | Integrates FastQC, fastp, Kraken2 |
| Centrifuge | Done v1.1 | Conditional on centrifuge_db; FM-index based classification |
| Krona visualization | Done v1.1 | Conditional on run_krona=true; interactive taxonomy plots |
| Taxpasta | Done v1.1 | Conditional on run_taxpasta=true; standardized output format |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| Kraken2 + Bracken (viral DB, simulated reads) | Pass |

---

### nanoseq — Nanopore Long-Read Sequencing

**Status: 1.1 — minimap2, NanoPlot, medaka, NanoFilt, StringTie2, Sniffles2**

Nanopore long-read sequencing analysis with NanoPlot QC, optional NanoFilt quality filtering, minimap2 alignment, optional medaka variant calling, optional Sniffles2 structural variant calling, and optional StringTie2 transcript assembly.

| Feature | Status | Notes |
|---------|--------|-------|
| NanoPlot QC | Done | Read length distributions, quality scores |
| FastQC | Done | General QC |
| minimap2 alignment | Done | map-ont (DNA), splice (RNA) presets |
| samtools sort/index | Done | |
| samtools stats | Done | Alignment statistics for MultiQC |
| Variant calling (medaka) | Done v1.1 | Conditional on call_variants=true; inference+vcf+annotate pipeline |
| MultiQC | Done | Integrates NanoStat, FastQC, samtools |
| NanoFilt quality filtering | Done v1.1 | Conditional on run_nanofilt=true; length and quality filtering |
| StringTie2 transcript assembly | Done v1.1 | Conditional on run_stringtie=true; for RNA mode |
| Structural variants (Sniffles2) | Done v1.1 | Conditional on run_sniffles=true; SV detection |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| DNA (map-ont, simulated 500 reads) | Pass |

---

### rnafusion — Gene Fusion Detection

**Status: 1.1 — Arriba, STAR-Fusion, FusionCatcher, FusionInspector**

Gene fusion detection from RNA-seq data. Four detection methods: Arriba, STAR-Fusion, FusionCatcher, and FusionInspector for validation. Arriba visualization for publication-ready figures.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| fastp trimming | Done | |
| STAR alignment (chimeric mode) | Done | chimSegmentMin, chimOutType WithinBAM |
| Arriba fusion detection | Done | Blacklist auto-disabled when not provided |
| samtools index | Done | |
| MultiQC | Done | Integrates FastQC, fastp, STAR |
| STAR-Fusion | Done v1.1 | Conditional on run_star_fusion=true; CTAT resource bundle |
| FusionCatcher | Done v1.1 | Conditional on run_fusioncatcher=true |
| FusionInspector | Done v1.1 | Conditional on run_fusion_inspector=true; post-processing validation |
| Arriba visualization | Done v1.1 | Conditional on run_arriba_viz=true; draw_fusions.R |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| Arriba (simulated GENEA-GENEB fusion, 499 reads) | Pass |

---

### raredisease — Rare Disease Variant Calling and Annotation

**Status: 1.1 — sarek + VEP + DeepVariant, Manta, CADD, GENMOD, ExpansionHunter**

Extends the sarek germline variant calling pipeline with Ensembl VEP annotation, optional DeepVariant, optional Manta SV calling, optional CADD annotation, optional GENMOD pedigree ranking, and optional ExpansionHunter repeat expansion detection. Includes joint calling via GenomicsDBImport + GenotypeGVCFs.

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
| DeepVariant | Done v1.1 | Conditional on run_deepvariant=true |
| Joint calling | Done v1.1 | GenomicsDBImport + GenotypeGVCFs scatter subworkflow |
| SV calling (Manta) | Done v1.1 | Conditional on run_manta=true |
| CADD scores | Done v1.1 | Conditional on cadd_resources; bcftools annotate |
| GENMOD ranking | Done v1.1 | Conditional on run_genmod=true; pedigree-aware ranking |
| ExpansionHunter | Done v1.1 | Conditional on variant_catalog; repeat expansion detection |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| VEP annotation (GFF3 mode, synthetic genome) | Pass |

---

### cutandrun — CUT&RUN/CUT&TAG Peak Calling

**Status: 1.1 — MACS2, SEACR, spike-in normalization, fragment size QC**

CUT&RUN and CUT&TAG analysis with Bowtie2 alignment, MACS2 peak calling (--nomodel), optional SEACR peak calling, optional E. coli spike-in normalization, and fragment size distribution QC.

| Feature | Status | Notes |
|---------|--------|-------|
| FastQC | Done | |
| fastp trimming | Done | |
| Bowtie2 alignment | Done | With read group tags |
| Picard MarkDuplicates | Done | |
| samtools filter | Done | -F 1804 -f 2 -q 1 |
| samtools index | Done | |
| MACS2 --nomodel peak calling | Done | Narrow (TF) or broad (histone) modes |
| SEACR peak calling | Done v1.1 | Conditional on run_seacr=true; bedtools genomecov + SEACR |
| deepTools bamCoverage | Done | Normalized bigWig generation |
| Optional IgG control | Done | Optional control inputs in workflow |
| MultiQC | Done | Integrates FastQC, fastp, Bowtie2, Picard |
| Spike-in normalization | Done v1.1 | Conditional on spikein_index_files; E. coli spike-in calibration |
| Fragment size QC | Done v1.1 | Conditional on run_fragment_qc=true; deepTools bamPEFragmentSize |

**Tested pathway matrix:**

| Mode | Local |
|------|-------|
| Narrow peaks (no control, yeast) | Pass |

---

### hic — Hi-C Chromatin Conformation Capture

**Status: 1.1 — Contact maps, TAD calling, A/B compartments, Juicer .hic**

Hi-C chromatin interaction analysis with two-step Bowtie2 alignment, pairtools valid pair extraction and deduplication, cooler contact map generation with ICE normalization, optional TAD calling, A/B compartment analysis, and Juicer .hic format conversion.

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
| TAD calling (HiCExplorer) | Done v1.1 | Conditional on run_tads=true; hicFindTADs |
| A/B compartments (cooltools) | Done v1.1 | Conditional on run_compartments=true; eigenvector decomposition |
| Juicer .hic conversion | Done v1.1 | Conditional on run_juicer=true; juicertools pre |

**Tested pathway matrix:**

| Mode | Docker |
|------|--------|
| MboI/DpnII (simulated 500 reads, 3 chromosomes) | Pass |

---

## v1.1 Roadmap — Additional Pathways and Tools (Complete)

All v1.1 enhancements implemented. 44 features across 12 pipelines, adding alternative tool paths, specialized modes, and downstream analysis features on top of the v1.0 core.

### Variant Calling & Clinical

| Pipeline | Feature | Status | Description |
|----------|---------|--------|-------------|
| sarek | BQSR | **Done** | Base quality score recalibration (requires known sites VCFs) |
| sarek | Joint calling | **Done** | GenomicsDBImport + GenotypeGVCFs for multi-sample cohorts |
| sarek | Scatter-gather | **Done** | Interval-based HaplotypeCaller parallelization |
| sarek | Mutect2 | **Done** | Somatic variant calling (tumor-normal pairs) |
| sarek | VEP annotation | **Done** | Ensembl VEP functional variant annotation |
| raredisease | DeepVariant | **Done** | Alternative SNV caller |
| raredisease | Joint calling | **Done** | GenomicsDBImport + GenotypeGVCFs |
| raredisease | SV calling (Manta) | **Done** | Structural variant detection |
| raredisease | CADD scores | **Done** | Pathogenicity scoring |
| raredisease | GENMOD ranking | **Done** | Pedigree-aware variant ranking |
| raredisease | ExpansionHunter | **Done** | Repeat expansion detection |
| viralrecon | Pangolin | **Done** | SARS-CoV-2 lineage assignment |
| viralrecon | Nextclade | **Done** | Multi-pathogen annotation |
| viralrecon | bcftools path | **Done** | Alternative to iVar variant calling |
| viralrecon | Kraken2 host filtering | **Done** | Remove host reads before alignment |

### Transcriptomics & Single-Cell

| Pipeline | Feature | Status | Description |
|----------|---------|--------|-------------|
| scrnaseq | Alevin-Fry | **Done** | Salmon-based pseudo-alignment path (simpleaf) |
| scrnaseq | Kallisto+BUStools | **Done** | Alternative quantification path |
| scrnaseq | Smart-seq2 | **Done** | Plate-based mode (no barcode demux) |
| scrnaseq | Empty droplet detection | **Done** | dropletUtils::emptyDrops (R) |
| rnafusion | STAR-Fusion | **Done** | CTAT resource bundle required |
| rnafusion | FusionCatcher | **Done** | Alternative fusion caller |
| rnafusion | FusionInspector | **Done** | Post-processing validation |
| rnafusion | Arriba visualization | **Done** | draw_fusions.R |

### Epigenomics & 3D Genomics

| Pipeline | Feature | Status | Description |
|----------|---------|--------|-------------|
| methylseq | bwa-meth + MethylDackel | **Done** | Alternative aligner path |
| methylseq | RRBS mode | **Done** | Skip deduplication for reduced representation |
| cutandrun | SEACR | **Done** | Alternative peak caller for CUT&RUN |
| cutandrun | Spike-in normalization | **Done** | E. coli spike-in calibration |
| cutandrun | Fragment size QC | **Done** | CUT&RUN diagnostic plots |
| hic | TAD calling | **Done** | HiCExplorer |
| hic | A/B compartments | **Done** | cooltools eigenvector decomposition |
| hic | Juicer .hic | **Done** | Convert cooler to .hic format |

### Metagenomics & Long-Read

| Pipeline | Feature | Status | Description |
|----------|---------|--------|-------------|
| ampliseq | QIIME2 diversity | **Done** | Phylogenetic diversity, ordination |
| ampliseq | Single-end mode | **Done** | Optional reverse reads; DADA2 skips pair merging |
| ampliseq | Species-level assignment | **Done** | addSpecies with exact matching |
| mag | Host read removal | **Done** | Bowtie2 against host reference |
| mag | MaxBin2 | **Done** | Alternative binner |
| mag | DAS Tool | **Done** | Bin refinement (conditional) |
| mag | BUSCO | **Done** | Bin completeness assessment (conditional) |
| mag | GTDB-Tk | **Done** | Bin taxonomic classification |
| mag | Prokka | **Done** | Bin functional annotation |
| taxprofiler | MetaPhlAn | **Done** | Marker-gene based profiling (conditional) |
| taxprofiler | Centrifuge | **Done** | FM-index based classification |
| taxprofiler | Krona | **Done** | Interactive taxonomy visualization |
| taxprofiler | Taxpasta | **Done** | Standardized output format |
| nanoseq | NanoFilt | **Done** | Quality filtering |
| nanoseq | StringTie2 | **Done** | Transcript assembly (RNA mode) |
| nanoseq | medaka | **Done** | Short variant calling from Nanopore |
| nanoseq | Sniffles2 | **Done** | Structural variant detection |

### v2.0 (Complete)

| Pipeline | Feature | Status | Description |
|----------|---------|--------|-------------|
| sarek | Mutect2 | **Done** | Somatic variant calling (tumor-normal pairs) |
| sarek | VEP annotation | **Done** | Ensembl VEP functional variant annotation |

---

## Pipelines Not Targeted

| Pipeline | Stars | Why skip |
|----------|-------|---------|
| eager | 200 | Ancient DNA — very niche audience |
| pangenome | 104 | Specialized graph genome tools |
| funcscan | 103 | AMR/AMP screening — narrow use case |
| proteinfold | 99 | GPU-dependent (AlphaFold2) — poor fit for CWL/WES |
| smrnaseq | 98 | Small RNA — low demand |

---

## Conversion History

All 16 pipelines completed in priority order, building tool reuse incrementally:

| # | Pipeline | New Tools Introduced |
|---|----------|---------------------|
| 1 | rnaseq | fastp, STAR, samtools, picard, featureCounts, RSeQC, MultiQC |
| 2 | fetchngs | ENA API client, fasterq-dump |
| 3 | chipseq | BWA-MEM2, MACS2, deepTools, samtools-filter |
| 4 | atacseq | (shared with chipseq) |
| 5 | sarek | GATK4 HaplotypeCaller, VariantFiltration, bcftools |
| 6 | methylseq | Bismark (genome-prep, align, dedup, methylation-extractor) |
| 7 | scrnaseq | STARsolo |
| 8 | viralrecon | iVar (trim, variants, consensus) |
| 9 | ampliseq | Cutadapt, DADA2 (denoise + taxonomy) |
| 10 | mag | SPAdes, MEGAHIT, Bowtie2, MetaBAT2, Prodigal, QUAST |
| 11 | taxprofiler | Kraken2, Bracken |
| 12 | nanoseq | minimap2, NanoPlot |
| 13 | rnafusion | STAR (chimeric mode), Arriba |
| 14 | raredisease | Ensembl VEP |
| 15 | cutandrun | (shared: Bowtie2, MACS2, deepTools) |
| 16 | hic | hic-mapping, pairtools, cooler (cload + zoomify) |

---

## Tool Reuse Matrix

124 tools in `tools/`, shared across 16 pipelines. Core shared tools:

| Tool | Pipelines using it |
|------|--------------------|
| fastqc | all 16 (except fetchngs) |
| multiqc | all 16 (except fetchngs) |
| fastp | rnaseq, chipseq, atacseq, sarek, methylseq, scrnaseq, viralrecon, mag, taxprofiler, cutandrun, hic |
| samtools-sort | rnaseq, chipseq, atacseq, sarek, methylseq, viralrecon, nanoseq |
| samtools-index | rnaseq, chipseq, atacseq, sarek, methylseq, viralrecon, nanoseq, cutandrun |
| picard-markduplicates | rnaseq, chipseq, atacseq, sarek, methylseq, viralrecon, cutandrun |
| bwa-mem2 (index + align) | chipseq, atacseq, sarek, viralrecon |
| bowtie2 (build + align) | mag, cutandrun, hic |
| macs2-callpeak | chipseq, atacseq, cutandrun |
| deeptools-bamcoverage | chipseq, atacseq, cutandrun |
| samtools-filter | chipseq, atacseq, cutandrun |
| samtools-stats | sarek, viralrecon, nanoseq |
| bcftools-stats | sarek, raredisease |
| star-genome-generate | rnaseq, scrnaseq |
| trim-galore | rnaseq, chipseq, atacseq, methylseq |
| pigz | rnaseq, chipseq, atacseq, sarek, methylseq, scrnaseq, viralrecon |
| featurecounts | rnaseq, chipseq, atacseq |

v1.1 tools added to reuse matrix:

| Tool | Pipelines using it |
|------|--------------------|
| gatk4-baserecalibrator | sarek |
| gatk4-applybqsr | sarek |
| gatk4-genomicsdbimport | sarek, raredisease |
| gatk4-genotypegvcfs | sarek, raredisease |
| gatk4-split-intervals | sarek |
| gatk4-merge-vcfs | sarek |
| medaka-variant | nanoseq |
| simpleaf-index | scrnaseq |
| simpleaf-quant | scrnaseq |
| metaphlan | taxprofiler |
| bwameth-index | methylseq |
| bwameth-align | methylseq |
| methyldackel-extract | methylseq |
| bcftools-call | viralrecon |
| pangolin | viralrecon |
| bedtools-genomecov | cutandrun |
| seacr | cutandrun |
| busco | mag |
| das-tool | mag |
| nanofilt | nanoseq |
| stringtie | nanoseq |
| sniffles | nanoseq |
| dada2-add-species | ampliseq |
| qiime2-diversity | ampliseq |
| nextclade | viralrecon |
| kraken2-filter | viralrecon |
| centrifuge | taxprofiler |
| centrifuge-kreport | taxprofiler |
| krona | taxprofiler |
| taxpasta | taxprofiler |
| bowtie2-spikein | cutandrun |
| compute-spikein-scale-factors | cutandrun |
| deeptools-bamcoverage-scaled | cutandrun |
| deeptools-bampe-fragmentsize | cutandrun |
| hicexplorer-find-tads | hic |
| cooltools-eigs | hic |
| juicertools-pre | hic |
| bowtie2-host-filter | mag |
| maxbin2 | mag |
| gtdbtk | mag |
| prokka | mag |
| deepvariant | raredisease |
| manta | raredisease |
| bcftools-annotate-cadd | raredisease |
| genmod | raredisease |
| expansionhunter | raredisease |
| kb-ref | scrnaseq |
| kb-count | scrnaseq |
| droplet-utils | scrnaseq |
| star-fusion | rnafusion |
| fusioncatcher | rnafusion |
| fusion-inspector | rnafusion |
| arriba-visualization | rnafusion |
| gatk4-mutect2 | sarek |
| gatk4-getpileupsummaries | sarek |
| gatk4-calculatecontamination | sarek |
| gatk4-learnreadorientationmodel | sarek |
| gatk4-filtermutectcalls | sarek |
| ensembl-vep | sarek, raredisease |

Pipeline-specific tools: STARsolo, Cutadapt, DADA2, SPAdes, MEGAHIT, MetaBAT2, Prodigal, QUAST, Kraken2, Bracken, minimap2, NanoPlot, Arriba, star-align-fusion, Ensembl VEP, iVar, Bismark, hic-mapping, pairtools, cooler, medaka, simpleaf, MetaPhlAn, bwa-meth, MethylDackel, Pangolin, SEACR, BUSCO, DAS Tool, NanoFilt, StringTie, Sniffles, STAR-Fusion, FusionCatcher, FusionInspector, Nextclade, Centrifuge, Krona, Taxpasta, DeepVariant, Manta, GENMOD, ExpansionHunter, Kallisto/BUStools, QIIME2.
