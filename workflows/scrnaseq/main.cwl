#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "scrnaseq - Single-cell RNA-seq quantification pipeline"
doc: |
  Single-cell RNA-seq pipeline with STARsolo or Alevin-Fry quantification.
  Performs raw read QC, index building, barcode-aware alignment/mapping,
  UMI deduplication, and gene-barcode count matrix generation.

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

  # === Quantification method ===
  quantifier:
    type: string
    default: starsolo
    doc: "Quantification method: starsolo (alignment-based) or alevin_fry (pseudo-alignment)"

  # === Alevin-Fry options ===
  alevin_fry_chemistry:
    type: string?
    default: "10xv3"
    doc: "simpleaf chemistry string (10xv2, 10xv3, etc.)"

  alevin_fry_resolution:
    type: string?
    default: "cr-like"
    doc: "UMI resolution mode (cr-like, cr-like-em, parsimony)"

  alevin_fry_rlen:
    type: int?
    default: 91
    doc: "Read length for splici index (typically read length - 1)"

steps:
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
  # STARsolo quantification (conditional)
  # =====================
  quantify_starsolo:
    run: steps/quantify-starsolo.cwl
    when: $(inputs.quantifier == "starsolo")
    in:
      genome_fasta: genome_fasta
      gtf: gtf
      star_index: star_index
      genome_sa_index_nbases: genome_sa_index_nbases
      fastq_barcode: fastq_barcode
      fastq_cdna: fastq_cdna
      sample_ids: sample_ids
      barcode_whitelist: barcode_whitelist
      cb_len: cb_len
      umi_len: umi_len
      solo_strand: solo_strand
      solo_cell_filter: solo_cell_filter
      quantifier: quantifier
    out: [aligned_bams, solo_out_dirs, star_logs]

  # =====================
  # Alevin-Fry quantification (conditional)
  # =====================
  quantify_alevin_fry:
    run: steps/quantify-alevin-fry.cwl
    when: $(inputs.quantifier == "alevin_fry")
    in:
      genome_fasta: genome_fasta
      gtf: gtf
      fastq_barcode: fastq_barcode
      fastq_cdna: fastq_cdna
      sample_ids: sample_ids
      chemistry: alevin_fry_chemistry
      resolution: alevin_fry_resolution
      barcode_whitelist: barcode_whitelist
      expect_cells:
        default: null
      rlen: alevin_fry_rlen
      quantifier: quantifier
    out: [quant_dirs]

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
          - quantify_starsolo/star_logs
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl scrnaseq"
    out: [html_report, data_dir]

outputs:
  aligned_bams:
    type: File[]?
    outputSource: quantify_starsolo/aligned_bams
    doc: "Coordinate-sorted BAM files per sample (STARsolo only)"

  solo_out_dirs:
    type: Directory[]?
    outputSource: quantify_starsolo/solo_out_dirs
    doc: "STARsolo output directories (Gene/filtered, Gene/raw count matrices)"

  star_logs:
    type: File[]?
    outputSource: quantify_starsolo/star_logs
    doc: "STAR alignment log files (STARsolo only)"

  alevin_fry_quant_dirs:
    type: Directory[]?
    outputSource: quantify_alevin_fry/quant_dirs
    doc: "Alevin-Fry quantification output directories"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
