#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "rnafusion - Gene fusion detection pipeline"
doc: |
  Gene fusion detection from RNA-seq data using STAR alignment with
  chimeric detection and Arriba fusion calling.

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
    type: File[]
    doc: "Reverse read FASTQ files (one per sample)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Reference ===
  star_index:
    type: Directory
    doc: "STAR genome index directory"

  reference_fasta:
    type: File
    doc: "Reference genome FASTA"

  gtf:
    type: File
    doc: "Gene annotation GTF file"

  # === Optional Arriba databases ===
  arriba_blacklist:
    type: File?
    doc: "Arriba blacklist of recurrent artifacts"

  arriba_known_fusions:
    type: File?
    doc: "Arriba known fusions for boosting sensitivity"

  arriba_protein_domains:
    type: File?
    doc: "Arriba protein domain annotation (GFF3)"

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
  # Quality trimming with fastp (per sample)
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
  # STAR alignment with chimeric detection (per sample)
  # =====================
  star:
    run: ../../tools/star-align-fusion.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      sample_id: sample_ids
      index_dir: star_index
    out: [aligned_bam, log_final, log, splice_junctions]

  # =====================
  # Arriba fusion detection (per sample)
  # =====================
  arriba:
    run: ../../tools/arriba.cwl
    scatter: [bam, prefix]
    scatterMethod: dotproduct
    in:
      bam: star/aligned_bam
      assembly: reference_fasta
      gtf: gtf
      blacklist: arriba_blacklist
      known_fusions: arriba_known_fusions
      protein_domains: arriba_protein_domains
      prefix: sample_ids
    out: [fusions, discarded_fusions]

  # =====================
  # samtools index (per sample, for BAM output)
  # =====================
  samtools_index:
    run: ../../tools/samtools-index.cwl
    scatter: sorted_bam
    in:
      sorted_bam: star/aligned_bam
    out: [indexed_bam]

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
          - star/log_final
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl rnafusion"
    out: [html_report, data_dir]

outputs:
  fusions:
    type: File[]
    outputSource: arriba/fusions
    doc: "Arriba gene fusion calls per sample"

  discarded_fusions:
    type: File[]
    outputSource: arriba/discarded_fusions
    doc: "Discarded fusion candidates per sample"

  aligned_bams:
    type: File[]
    outputSource: samtools_index/indexed_bam
    doc: "STAR-aligned BAMs with chimeric reads"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
