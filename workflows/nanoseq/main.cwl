#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "nanoseq - Nanopore sequencing analysis pipeline"
doc: |
  Long-read sequencing analysis pipeline for Oxford Nanopore data.
  QC with NanoPlot, alignment with minimap2, and aggregated reporting with MultiQC.

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  # === Samples ===
  fastq:
    type: File[]
    doc: "Nanopore FASTQ files (one per sample)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Reference ===
  reference:
    type: File
    doc: "Reference genome FASTA"

  # === Alignment ===
  minimap2_preset:
    type: string?
    default: map-ont
    doc: "minimap2 preset: map-ont (DNA), splice (RNA), map-pb (PacBio CLR), map-hifi"

steps:
  # =====================
  # NanoPlot QC on raw reads
  # =====================
  nanoplot:
    run: ../../tools/nanoplot.cwl
    scatter: [fastq, sample_id]
    scatterMethod: dotproduct
    in:
      fastq: fastq
      sample_id: sample_ids
    out: [stats_txt, html_report]

  # =====================
  # FastQC on raw reads
  # =====================
  fastqc:
    run: ../../tools/fastqc.cwl
    scatter: fastq
    in:
      fastq: fastq
    out: [html_report, zip_report]

  # =====================
  # minimap2 alignment (per sample)
  # =====================
  minimap2:
    run: ../../tools/minimap2.cwl
    scatter: [reads, sample_id]
    scatterMethod: dotproduct
    in:
      reads: fastq
      reference: reference
      sample_id: sample_ids
      preset: minimap2_preset
    out: [sam]

  # =====================
  # samtools sort + index (per sample)
  # =====================
  samtools_sort:
    run: ../../tools/samtools-sort-index.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: minimap2/sam
      sample_id: sample_ids
    out: [sorted_bam]

  # =====================
  # samtools stats (per sample)
  # =====================
  samtools_stats:
    run: ../../tools/samtools-stats.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: samtools_sort/sorted_bam
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
          - fastqc/zip_report
          - nanoplot/stats_txt
          - samtools_stats/stats
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl nanoseq"
    out: [html_report, data_dir]

outputs:
  sorted_bams:
    type: File[]
    outputSource: samtools_sort/sorted_bam
    doc: "Coordinate-sorted and indexed BAM files"

  nanoplot_reports:
    type: File[]
    outputSource: nanoplot/html_report
    doc: "NanoPlot HTML QC reports per sample"

  nanoplot_stats:
    type: File[]
    outputSource: nanoplot/stats_txt
    doc: "NanoPlot summary statistics per sample"

  samtools_stats_files:
    type: File[]
    outputSource: samtools_stats/stats
    doc: "Samtools alignment statistics per sample"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
