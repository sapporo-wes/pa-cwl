#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "scrnaseq - Single-cell RNA-seq quantification pipeline"
doc: |
  Single-cell RNA-seq pipeline using STARsolo. Performs raw read QC,
  genome index building, barcode-aware alignment, UMI deduplication,
  and gene-barcode count matrix generation.

  Supports 10x Chromium v2/v3, Drop-seq, and other barcode-based
  protocols via configurable barcode/UMI parameters.

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  # === Samples ===
  fastq_barcode:
    type: File[]
    doc: "Barcode + UMI reads (R1 for 10x Chromium), one per sample"

  fastq_cdna:
    type: File[]
    doc: "cDNA reads (R2 for 10x Chromium), one per sample"

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

  # === Pre-built index (optional) ===
  star_index:
    type: Directory?
    doc: "Pre-built STAR genome index"

  genome_sa_index_nbases:
    type: int?
    doc: "For small genomes, set to min(14, log2(GenomeLength)/2 - 1)"

  # === Protocol settings ===
  barcode_whitelist:
    type: File
    doc: "Cell barcode whitelist (e.g., 3M-february-2018.txt for 10x v3)"

  cb_len:
    type: int
    default: 16
    doc: "Cell barcode length (16 for 10x v2/v3, 12 for Drop-seq)"

  umi_len:
    type: int
    default: 12
    doc: "UMI length (12 for 10x v3, 10 for v2, 8 for Drop-seq)"

  solo_strand:
    type: string?
    default: "Forward"
    doc: "Read strand (Forward for 10x 3', Reverse for 10x 5')"

  solo_cell_filter:
    type: string?
    default: "CellRanger2_3 3000 0.99 10"
    doc: "Cell filtering method"

steps:
  # =====================
  # STAR genome index (conditional)
  # =====================
  build_star_index:
    run: ../../tools/star-genome-generate.cwl
    when: $(inputs.star_index == null)
    in:
      genome_fasta: genome_fasta
      gtf: gtf
      genome_sa_index_nbases: genome_sa_index_nbases
      star_index: star_index
    out: [index_dir]

  # =====================
  # FastQC on barcode reads
  # =====================
  fastqc_barcode:
    run: ../../tools/fastqc.cwl
    scatter: fastq
    in:
      fastq: fastq_barcode
    out: [html_report, zip_report]

  # =====================
  # FastQC on cDNA reads
  # =====================
  fastqc_cdna:
    run: ../../tools/fastqc.cwl
    scatter: fastq
    in:
      fastq: fastq_cdna
    out: [html_report, zip_report]

  # =====================
  # STARsolo alignment + quantification
  # =====================
  starsolo:
    run: ../../tools/starsolo.cwl
    scatter: [fastq_cdna, fastq_barcode, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_cdna: fastq_cdna
      fastq_barcode: fastq_barcode
      barcode_whitelist: barcode_whitelist
      sample_id: sample_ids
      index_dir:
        source:
          - star_index
          - build_star_index/index_dir
        pickValue: first_non_null
      cb_len: cb_len
      umi_len: umi_len
      solo_strand: solo_strand
      solo_cell_filter: solo_cell_filter
    out: [aligned_bam, solo_out_dir, log_final, log, barcodes_stats]

  # =====================
  # MultiQC reporting
  # =====================
  multiqc:
    run: ../../tools/multiqc.cwl
    in:
      report_files:
        source:
          - fastqc_barcode/zip_report
          - fastqc_cdna/zip_report
          - starsolo/log_final
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl scrnaseq"
    out: [html_report, data_dir]

outputs:
  aligned_bams:
    type: File[]
    outputSource: starsolo/aligned_bam
    doc: "Coordinate-sorted BAM files per sample"

  solo_out_dirs:
    type: Directory[]
    outputSource: starsolo/solo_out_dir
    doc: "STARsolo output directories (Gene/filtered, Gene/raw count matrices)"

  star_logs:
    type: File[]
    outputSource: starsolo/log_final
    doc: "STAR alignment log files"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
