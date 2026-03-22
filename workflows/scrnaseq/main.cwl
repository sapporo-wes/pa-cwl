#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "scrnaseq - Single-cell RNA-seq quantification pipeline"
doc: |
  Single-cell RNA-seq pipeline supporting multiple quantification methods:
  STARsolo, Alevin-Fry, Kallisto+BUStools, and Smart-seq2 (plate-based).

  Performs raw read QC, index building, barcode-aware alignment/mapping,
  UMI deduplication, and gene-barcode count matrix generation.

  Supports 10x Chromium v2/v3, Drop-seq, and other barcode-based
  protocols via configurable barcode/UMI parameters.
  Smart-seq2 mode processes plate-based data without barcodes.

  Optional empty droplet detection via DropletUtils emptyDrops()
  for droplet-based protocols (STARsolo, Alevin-Fry, Kallisto).

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  # === Samples (droplet-based protocols) ===
  fastq_barcode:
    type: File[]?
    doc: "Barcode + UMI reads (R1 for 10x Chromium), one per sample. Not used for smartseq2."

  fastq_cdna:
    type: File[]?
    doc: "cDNA reads (R2 for 10x Chromium), one per sample. Not used for smartseq2."

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Samples (Smart-seq2 plate-based) ===
  fastq_fwd:
    type: File[]
    default: []
    doc: "Forward reads for Smart-seq2, one per sample/well"

  fastq_rev:
    type: File[]
    default: []
    doc: "Reverse reads for Smart-seq2, one per sample/well"

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
    type: File?
    doc: "Cell barcode whitelist (e.g., 3M-february-2018.txt for 10x v3). Not needed for smartseq2."

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
    doc: "Quantification method: starsolo, alevin_fry, kallisto, or smartseq2"

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

  # === Kallisto+BUStools options ===
  kallisto_chemistry:
    type: string?
    default: "10xv3"
    doc: "Single-cell technology string for kb count (10xv2, 10xv3, etc.)"

  # === Smart-seq2 options ===
  smartseq2_strandedness:
    type: int?
    default: 0
    doc: "Strand-specificity for featureCounts (0=unstranded, 1=forward, 2=reverse)"

  # === Empty droplet detection ===
  run_empty_drops:
    type: boolean?
    default: false
    doc: "Run DropletUtils emptyDrops on raw count matrices (droplet-based protocols only)"

  empty_drops_fdr:
    type: float?
    default: 0.01
    doc: "FDR threshold for emptyDrops"

steps:
  # =====================
  # FastQC on barcode reads (droplet-based only)
  # =====================
  fastqc_barcode:
    run: ../../tools/fastqc.cwl
    scatter: fastq
    when: $(inputs.fastq != null)
    in:
      fastq: fastq_barcode
    out: [html_report, zip_report]

  # =====================
  # FastQC on cDNA reads (droplet-based only)
  # =====================
  fastqc_cdna:
    run: ../../tools/fastqc.cwl
    scatter: fastq
    when: $(inputs.fastq != null)
    in:
      fastq: fastq_cdna
    out: [html_report, zip_report]

  # =====================
  # FastQC on Smart-seq2 forward reads
  # =====================
  fastqc_smartseq2_fwd:
    run: ../../tools/fastqc.cwl
    scatter: fastq
    when: $(inputs.fastq != null && inputs.fastq.length > 0)
    in:
      fastq: fastq_fwd
    out: [html_report, zip_report]

  # =====================
  # FastQC on Smart-seq2 reverse reads
  # =====================
  fastqc_smartseq2_rev:
    run: ../../tools/fastqc.cwl
    scatter: fastq
    when: $(inputs.fastq != null && inputs.fastq.length > 0)
    in:
      fastq: fastq_rev
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
  # Kallisto+BUStools quantification (conditional)
  # =====================
  quantify_kallisto:
    run: steps/quantify-kallisto.cwl
    when: $(inputs.quantifier == "kallisto")
    in:
      genome_fasta: genome_fasta
      gtf: gtf
      fastq_barcode: fastq_barcode
      fastq_cdna: fastq_cdna
      chemistry: kallisto_chemistry
      quantifier: quantifier
    out: [count_dir, bus_file]

  # =====================
  # Smart-seq2 quantification (conditional)
  # =====================
  quantify_smartseq2:
    run: steps/quantify-smartseq2.cwl
    when: $(inputs.quantifier == "smartseq2")
    in:
      genome_fasta: genome_fasta
      gtf: gtf
      star_index: star_index
      genome_sa_index_nbases: genome_sa_index_nbases
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_ids: sample_ids
      strandedness: smartseq2_strandedness
      quantifier: quantifier
    out: [aligned_bams, star_logs, count_matrices, count_summaries]

  # =====================
  # Empty droplet detection (conditional, after STARsolo)
  # =====================
  empty_drops:
    run: ../../tools/droplet-utils.cwl
    when: $(inputs.run_empty_drops && inputs.quantifier == "starsolo" && inputs.raw_matrix_dir != null)
    scatter: [raw_matrix_dir, sample_id]
    scatterMethod: dotproduct
    in:
      raw_matrix_dir: quantify_starsolo/solo_out_dirs
      fdr_threshold: empty_drops_fdr
      sample_id: sample_ids
      run_empty_drops: run_empty_drops
      quantifier: quantifier
    out: [filtered_barcodes, summary_stats]

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
          - fastqc_smartseq2_fwd/zip_report
          - fastqc_smartseq2_rev/zip_report
          - quantify_starsolo/star_logs
          - quantify_smartseq2/star_logs
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

  kallisto_count_dir:
    type: Directory?
    outputSource: quantify_kallisto/count_dir
    doc: "Kallisto+BUStools output directory with count matrices"

  kallisto_bus_file:
    type: File?
    outputSource: quantify_kallisto/bus_file
    doc: "BUS format file from kallisto"

  smartseq2_aligned_bams:
    type: File[]?
    outputSource: quantify_smartseq2/aligned_bams
    doc: "STAR aligned BAM files per sample (Smart-seq2 only)"

  smartseq2_star_logs:
    type: File[]?
    outputSource: quantify_smartseq2/star_logs
    doc: "STAR alignment logs (Smart-seq2 only)"

  smartseq2_count_matrices:
    type: File[]?
    outputSource: quantify_smartseq2/count_matrices
    doc: "featureCounts count matrices per sample (Smart-seq2 only)"

  smartseq2_count_summaries:
    type: File[]?
    outputSource: quantify_smartseq2/count_summaries
    doc: "featureCounts summary statistics per sample (Smart-seq2 only)"

  empty_drops_filtered_barcodes:
    type: File[]?
    outputSource: empty_drops/filtered_barcodes
    doc: "Filtered barcode lists from emptyDrops (non-empty droplets)"

  empty_drops_summary:
    type: File[]?
    outputSource: empty_drops/summary_stats
    doc: "emptyDrops summary statistics per sample"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
