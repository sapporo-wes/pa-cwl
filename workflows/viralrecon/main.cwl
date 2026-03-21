#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "viralrecon - Viral genome variant calling and consensus pipeline"
doc: |
  Viral genome analysis pipeline for amplicon or whole-genome sequencing.
  Performs QC, trimming, alignment, optional primer trimming, variant
  calling (iVar + optional bcftools), consensus generation, and
  optional Pangolin lineage assignment.

  Designed for SARS-CoV-2 surveillance but works with any viral reference.

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  # === Samples ===
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (one per sample)"

  fastq_rev:
    type: File[]?
    doc: "Reverse read FASTQ files (one per sample)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Reference genome ===
  genome_fasta:
    type: File
    doc: "Viral reference genome FASTA"

  # === Pre-built index (optional) ===
  bwa_index:
    type: File?
    secondaryFiles:
      - pattern: ".0123"
      - pattern: .amb
      - pattern: .ann
      - pattern: .bwt.2bit.64
      - pattern: .pac
    doc: "Pre-built BWA-MEM2 index (genome FASTA with sidecar files)"

  # === Amplicon settings ===
  primer_bed:
    type: File?
    doc: "BED file with primer coordinates (required for amplicon mode)"

  # === Tool options ===
  trimmer:
    type:
      type: enum
      symbols: [fastp, trim_galore, skip]
    default: fastp
    doc: "Read trimming tool"

  min_depth:
    type: int?
    default: 10
    doc: "Minimum read depth for variant/consensus calling"

  run_bcftools:
    type: boolean?
    default: false
    doc: "Also call variants with bcftools mpileup+call (produces VCF output)"

  run_pangolin:
    type: boolean?
    default: false
    doc: "Run Pangolin lineage assignment on consensus sequences"

steps:
  # =====================
  # BWA-MEM2 index (conditional)
  # =====================
  build_bwa_index:
    run: ../../tools/bwa-mem2-index.cwl
    when: $(inputs.bwa_index == null)
    in:
      genome_fasta: genome_fasta
      bwa_index: bwa_index
    out: [genome_with_index]

  # =====================
  # Reference FASTA index (.fai) for ivar
  # =====================
  samtools_faidx:
    run: ../../tools/samtools-faidx.cwl
    in:
      fasta: genome_fasta
    out: [indexed_fasta]

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
    out: [trimmed_fwd, trimmed_rev, fastqc_raw_zip, fastp_json]

  # =====================
  # Alignment (per sample)
  # =====================
  align:
    run: steps/align-bwa.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: qc_trim/trimmed_fwd
      fastq_rev: qc_trim/trimmed_rev
      sample_id: sample_ids
      genome_fasta:
        source:
          - bwa_index
          - build_bwa_index/genome_with_index
        pickValue: first_non_null
    out: [aligned_bam, markdup_metrics]

  # =====================
  # Primer trimming (conditional, amplicon mode only)
  # =====================
  ivar_trim:
    run: ../../tools/ivar-trim.cwl
    when: $(inputs.primer_bed != null)
    scatter: [bam, prefix]
    scatterMethod: dotproduct
    in:
      bam: align/aligned_bam
      primer_bed: primer_bed
      prefix: sample_ids
    out: [trimmed_bam]

  # =====================
  # Sort + index trimmed BAMs (for ivar)
  # =====================
  sort_trimmed:
    run: ../../tools/samtools-sort-index.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam:
        source:
          - ivar_trim/trimmed_bam
          - align/aligned_bam
        pickValue: first_non_null
      sample_id: sample_ids
    out: [sorted_bam]

  # =====================
  # Variant calling (per sample)
  # =====================
  ivar_variants:
    run: ../../tools/ivar-variants.cwl
    scatter: [bam, prefix]
    scatterMethod: dotproduct
    in:
      bam: sort_trimmed/sorted_bam
      reference: samtools_faidx/indexed_fasta
      prefix: sample_ids
      min_depth: min_depth
    out: [variants_tsv]

  # =====================
  # Consensus generation (per sample)
  # =====================
  ivar_consensus:
    run: ../../tools/ivar-consensus.cwl
    scatter: [bam, prefix]
    scatterMethod: dotproduct
    in:
      bam: sort_trimmed/sorted_bam
      reference: samtools_faidx/indexed_fasta
      prefix: sample_ids
      min_depth: min_depth
    out: [consensus_fasta, consensus_qual]

  # =====================
  # bcftools variant calling (conditional)
  # =====================
  bcftools_variants:
    run: steps/bcftools-variant-calling.cwl
    when: $(inputs.run_bcftools == true)
    in:
      bams: sort_trimmed/sorted_bam
      reference: samtools_faidx/indexed_fasta
      sample_ids: sample_ids
      run_bcftools: run_bcftools
    out: [vcfs, stats]

  # =====================
  # Pangolin lineage assignment (conditional)
  # =====================
  pangolin_lineage:
    run: steps/pangolin-lineage.cwl
    when: $(inputs.run_pangolin == true)
    in:
      consensus_fastas: ivar_consensus/consensus_fasta
      sample_ids: sample_ids
      run_pangolin: run_pangolin
    out: [lineage_reports]

  # =====================
  # Alignment stats (per sample)
  # =====================
  samtools_stats:
    run: ../../tools/samtools-stats.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: sort_trimmed/sorted_bam
      sample_id: sample_ids
    out: [stats]

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
          - align/markdup_metrics
          - samtools_stats/stats
          - bcftools_variants/stats
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl viralrecon"
    out: [html_report, data_dir]

outputs:
  consensus_fastas:
    type: File[]
    outputSource: ivar_consensus/consensus_fasta
    doc: "Consensus FASTA sequences per sample"

  variants_tsvs:
    type: File[]
    outputSource: ivar_variants/variants_tsv
    doc: "Variant calls in TSV format per sample"

  aligned_bams:
    type: File[]
    outputSource: sort_trimmed/sorted_bam
    doc: "Sorted BAM files (primer-trimmed if amplicon mode)"

  bcftools_vcfs:
    type: File[]?
    outputSource: bcftools_variants/vcfs
    doc: "bcftools variant calls in VCF format (when run_bcftools=true)"

  pangolin_reports:
    type: File[]?
    outputSource: pangolin_lineage/lineage_reports
    doc: "Pangolin lineage assignment reports (when run_pangolin=true)"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
