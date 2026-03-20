#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "hic - Hi-C chromatin conformation capture pipeline"
doc: |
  Hi-C analysis pipeline. Two-step Bowtie2 alignment with chimeric read
  rescue, pairtools-based valid pair extraction and deduplication, and
  cooler contact map generation with ICE normalization.

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  # === Sample reads ===
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (one per sample)"

  fastq_rev:
    type: File[]
    doc: "Reverse read FASTQ files (one per sample)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Reference genome ===
  bowtie2_index_files:
    type: File[]
    doc: "Bowtie2 index files (.1.bt2 through .rev.2.bt2)"

  bowtie2_index_base:
    type: string
    doc: "Bowtie2 index base name"

  chromsizes:
    type: File
    doc: "Chromosome sizes file (tab-separated: chrom<tab>size)"

  # === Hi-C protocol ===
  ligation_site:
    type: string
    doc: "Ligation site sequence (AAGCTAGCTT for HindIII, GATCGATC for MboI/DpnII)"

  # === Contact map parameters ===
  resolution:
    type: int?
    default: 10000
    doc: "Contact map bin resolution in base pairs"

  min_mapq:
    type: int?
    default: 10
    doc: "Minimum mapping quality for valid pairs"

  zoomify_resolutions:
    type: string?
    default: "5000,10000,25000,50000,100000,250000,500000,1000000"
    doc: "Comma-separated list of resolutions for multi-resolution mcool"

steps:
  # =====================
  # FastQC on raw reads
  # =====================
  fastqc:
    run: ../../tools/fastqc.cwl
    scatter: fastq
    in:
      fastq: fastq_fwd
    out: [html_report, zip_report]

  # =====================
  # fastp trimming (per sample)
  # =====================
  fastp:
    run: ../../tools/fastp.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_ids
    out: [trimmed_fwd, trimmed_rev, json_report]

  # =====================
  # Hi-C two-step mapping (per sample)
  # =====================
  hic_mapping:
    run: ../../tools/hic-mapping.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      sample_id: sample_ids
      index_files: bowtie2_index_files
      index_base: bowtie2_index_base
      ligation_site: ligation_site
    out: [namesorted_bam, log_r1, log_r2]

  # =====================
  # pairtools: parse + sort + dedup (per sample)
  # =====================
  pairtools:
    run: ../../tools/pairtools-process.cwl
    scatter: [namesorted_bam, sample_id]
    scatterMethod: dotproduct
    in:
      namesorted_bam: hic_mapping/namesorted_bam
      chromsizes: chromsizes
      sample_id: sample_ids
      min_mapq: min_mapq
    out: [valid_pairs, stats]

  # =====================
  # cooler: generate contact matrices (per sample)
  # =====================
  cooler_cload:
    run: ../../tools/cooler-cload.cwl
    scatter: [valid_pairs, sample_id]
    scatterMethod: dotproduct
    in:
      valid_pairs: pairtools/valid_pairs
      chromsizes: chromsizes
      sample_id: sample_ids
      resolution: resolution
    out: [cool]

  # =====================
  # cooler: multi-resolution zoomify (per sample)
  # =====================
  cooler_zoomify:
    run: ../../tools/cooler-zoomify.cwl
    scatter: [cool, sample_id]
    scatterMethod: dotproduct
    in:
      cool: cooler_cload/cool
      sample_id: sample_ids
      resolutions: zoomify_resolutions
    out: [mcool]

  # =====================
  # MultiQC reporting
  # =====================
  multiqc:
    run: ../../tools/multiqc.cwl
    in:
      report_files:
        source:
          - fastqc/zip_report
          - fastp/json_report
          - hic_mapping/log_r1
          - hic_mapping/log_r2
          - pairtools/stats
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl hic"
    out: [html_report, data_dir]

outputs:
  cool_matrices:
    type: File[]
    outputSource: cooler_cload/cool
    doc: "Single-resolution contact matrices (.cool)"

  mcool_matrices:
    type: File[]
    outputSource: cooler_zoomify/mcool
    doc: "Multi-resolution contact matrices (.mcool)"

  valid_pairs:
    type: File[]
    outputSource: pairtools/valid_pairs
    doc: "Deduplicated valid pairs files"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
