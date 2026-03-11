#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "rnaseq - RNA-seq quantification pipeline"
doc: |
  RNA-seq analysis pipeline supporting multiple aligners (STAR, HISAT2)
  and quantifiers (Salmon, RSEM, kallisto). Includes QC with FastQC,
  trimming with fastp or Trim Galore, alignment, quantification,
  count matrix aggregation, and MultiQC reporting.

  Workflow paths:
    - STAR + Salmon (default): genome alignment + transcript quantification
    - STAR + RSEM: genome alignment + isoform-level quantification
    - HISAT2 + featureCounts: genome alignment + read counting
    - kallisto (pseudo-alignment only): fast transcript quantification

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  # === Sample inputs ===
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (one per sample)"

  fastq_rev:
    type: File[]?
    doc: "Reverse read FASTQ files (one per sample, omit for single-end)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Reference genome ===
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

  gtf:
    type: File
    doc: "Gene annotation GTF"

  transcriptome_fasta:
    type: File?
    doc: "Transcriptome FASTA (for Salmon/kallisto index building)"

  # === Pre-built indices (optional — built on-the-fly if not provided) ===
  star_index:
    type: Directory?
    doc: "Pre-built STAR genome index"

  hisat2_index_files:
    type: File[]?
    doc: "Pre-built HISAT2 index files"

  salmon_index:
    type: Directory?
    doc: "Pre-built Salmon transcriptome index"

  rsem_reference:
    type: Directory?
    doc: "Pre-built RSEM reference"

  kallisto_index:
    type: File?
    doc: "Pre-built kallisto index"

  # === Tool selection ===
  aligner:
    type:
      type: enum
      symbols: [star, hisat2]
    default: star
    doc: "Alignment tool"

  quantifier:
    type:
      type: enum
      symbols: [salmon, rsem, kallisto]
    default: salmon
    doc: "Quantification tool"

  trimmer:
    type:
      type: enum
      symbols: [fastp, trim_galore, skip]
    default: fastp
    doc: "Read trimming tool"

  strandedness:
    type:
      type: enum
      symbols: [unstranded, forward, reverse]
    default: unstranded
    doc: "Library strandedness"

steps:
  # =====================
  # QC + Trimming (per sample)
  # =====================
  qc_trim:
    run: steps/qc-trim.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_ids
      trimmer: trimmer
    out: [trimmed_fwd, trimmed_rev, fastqc_raw_html, fastqc_raw_zip, fastp_json, trim_report]

  # =====================
  # Index building (conditional, only if pre-built index not provided)
  # =====================
  build_star_index:
    run: ../../tools/star-genome-generate.cwl
    when: $(inputs.aligner == "star" && inputs.star_index == null)
    in:
      genome_fasta: genome_fasta
      gtf: gtf
      aligner: aligner
      star_index: star_index
    out: [index_dir]

  build_hisat2_index:
    run: ../../tools/hisat2-build.cwl
    when: $(inputs.aligner == "hisat2" && inputs.hisat2_index_files == null)
    in:
      genome_fasta: genome_fasta
      aligner: aligner
      hisat2_index_files: hisat2_index_files
    out: [index_files]

  build_salmon_index:
    run: ../../tools/salmon-index.cwl
    when: $(inputs.quantifier == "salmon" && inputs.salmon_index == null)
    in:
      transcriptome_fasta: transcriptome_fasta
      genome_fasta: genome_fasta
      quantifier: quantifier
      salmon_index: salmon_index
    out: [index_dir]

  build_rsem_reference:
    run: ../../tools/rsem-prepare-reference.cwl
    when: $(inputs.quantifier == "rsem" && inputs.rsem_reference == null)
    in:
      genome_fasta: genome_fasta
      gtf: gtf
      quantifier: quantifier
      rsem_reference: rsem_reference
    out: [reference_dir]

  build_kallisto_index:
    run: ../../tools/kallisto-index.cwl
    when: $(inputs.quantifier == "kallisto" && inputs.kallisto_index == null)
    in:
      transcriptome_fasta: transcriptome_fasta
      quantifier: quantifier
      kallisto_index: kallisto_index
    out: [index_file]

  # =====================
  # Alignment: STAR path (per sample)
  # =====================
  align_star:
    run: steps/align-star.cwl
    when: $(inputs.aligner == "star")
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: qc_trim/trimmed_fwd
      fastq_rev: qc_trim/trimmed_rev
      sample_id: sample_ids
      index_dir:
        source:
          - star_index
          - build_star_index/index_dir
        pickValue: all_non_null
        valueFrom: "${return self.length > 0 ? self[0] : null;}"
      aligner: aligner
    out: [aligned_bam, transcriptome_bam, star_log, markdup_metrics]

  # =====================
  # Alignment: HISAT2 path (per sample)
  # =====================
  align_hisat2:
    run: steps/align-hisat2.cwl
    when: $(inputs.aligner == "hisat2")
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: qc_trim/trimmed_fwd
      fastq_rev: qc_trim/trimmed_rev
      sample_id: sample_ids
      index_files:
        source:
          - hisat2_index_files
          - build_hisat2_index/index_files
        pickValue: all_non_null
        valueFrom: "${return self.length > 0 ? self[0] : null;}"
      strandedness: strandedness
      aligner: aligner
    out: [aligned_bam, hisat2_log, markdup_metrics]

  # =====================
  # Quantification: Salmon (from STAR transcriptome BAM)
  # =====================
  quant_salmon:
    run: steps/quantify-salmon.cwl
    when: $(inputs.quantifier == "salmon" && inputs.aligner == "star")
    scatter: [transcriptome_bam, sample_id]
    scatterMethod: dotproduct
    in:
      index_dir:
        source:
          - salmon_index
          - build_salmon_index/index_dir
        pickValue: all_non_null
        valueFrom: "${return self.length > 0 ? self[0] : null;}"
      transcriptome_fasta: transcriptome_fasta
      transcriptome_bam: align_star/transcriptome_bam
      sample_id: sample_ids
      mode:
        default: alignment
      quantifier: quantifier
      aligner: aligner
    out: [quant_dir, quant_sf]

  # =====================
  # Quantification: Salmon mapping-based (standalone, no alignment)
  # =====================
  quant_salmon_mapping:
    run: steps/quantify-salmon.cwl
    when: $(inputs.quantifier == "salmon" && inputs.aligner == "hisat2")
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      index_dir:
        source:
          - salmon_index
          - build_salmon_index/index_dir
        pickValue: all_non_null
        valueFrom: "${return self.length > 0 ? self[0] : null;}"
      fastq_fwd: qc_trim/trimmed_fwd
      fastq_rev: qc_trim/trimmed_rev
      sample_id: sample_ids
      mode:
        default: mapping
      quantifier: quantifier
      aligner: aligner
    out: [quant_dir, quant_sf]

  # =====================
  # Quantification: RSEM (from STAR transcriptome BAM)
  # =====================
  quant_rsem:
    run: steps/quantify-rsem.cwl
    when: $(inputs.quantifier == "rsem")
    scatter: [transcriptome_bam, sample_id]
    scatterMethod: dotproduct
    in:
      transcriptome_bam: align_star/transcriptome_bam
      reference_dir:
        source:
          - rsem_reference
          - build_rsem_reference/reference_dir
        pickValue: all_non_null
        valueFrom: "${return self.length > 0 ? self[0] : null;}"
      sample_id: sample_ids
      quantifier: quantifier
    out: [genes_results, isoforms_results]

  # =====================
  # Quantification: kallisto (pseudo-alignment, no genome alignment needed)
  # =====================
  quant_kallisto:
    run: steps/quantify-kallisto.cwl
    when: $(inputs.quantifier == "kallisto")
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      index_file:
        source:
          - kallisto_index
          - build_kallisto_index/index_file
        pickValue: all_non_null
        valueFrom: "${return self.length > 0 ? self[0] : null;}"
      fastq_fwd: qc_trim/trimmed_fwd
      fastq_rev: qc_trim/trimmed_rev
      sample_id: sample_ids
      quantifier: quantifier
    out: [quant_dir, abundance_tsv]

  # =====================
  # featureCounts (for HISAT2 path without Salmon)
  # =====================
  featurecounts:
    run: steps/featurecounts.cwl
    when: $(inputs.aligner == "hisat2" && inputs.quantifier != "salmon")
    in:
      bams: align_hisat2/aligned_bam
      gtf: gtf
      sample_ids: sample_ids
      aligner: aligner
      quantifier: quantifier
    out: [counts, summaries]

  # =====================
  # Count matrix aggregation
  # =====================
  aggregate_counts:
    run: steps/aggregate-counts.cwl
    in:
      quant_files:
        source:
          - quant_salmon/quant_sf
          - quant_salmon_mapping/quant_sf
          - quant_rsem/genes_results
          - quant_kallisto/abundance_tsv
        pickValue: all_non_null
        valueFrom: "${return self.length > 0 ? self[0] : null;}"
      sample_ids: sample_ids
    out: [gene_counts, gene_tpm]

  # =====================
  # MultiQC reporting
  # =====================
  multiqc:
    run: ../../tools/multiqc.cwl
    in:
      report_files:
        source:
          - qc_trim/fastqc_raw_zip
          - qc_trim/fastp_json
          - align_star/star_log
          - align_star/markdup_metrics
          - align_hisat2/hisat2_log
          - align_hisat2/markdup_metrics
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl rnaseq"
    out: [html_report, data_dir]

outputs:
  gene_counts:
    type: File
    outputSource: aggregate_counts/gene_counts
    doc: "Gene-level raw count matrix (TSV)"

  gene_tpm:
    type: File
    outputSource: aggregate_counts/gene_tpm
    doc: "Gene-level TPM matrix (TSV)"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"

  aligned_bams:
    type: File[]?
    outputSource:
      - align_star/aligned_bam
      - align_hisat2/aligned_bam
    linkMerge: merge_flattened
    pickValue: all_non_null
    doc: "Sorted, deduplicated BAM files per sample"
