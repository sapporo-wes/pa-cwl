#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "nanoseq - Nanopore sequencing analysis pipeline"
doc: |
  Long-read sequencing analysis pipeline for Oxford Nanopore data.
  QC with NanoPlot, optional quality filtering with NanoFilt,
  alignment with minimap2, optional transcript assembly with StringTie2,
  optional structural variant calling with Sniffles2, optional variant
  calling with medaka, and aggregated reporting with MultiQC.

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

  # === Quality filtering ===
  run_nanofilt:
    type: boolean?
    default: false
    doc: "Run NanoFilt quality filtering before alignment"

  nanofilt_quality:
    type: int?
    default: 7
    doc: "NanoFilt minimum average read quality score (default: 7)"

  nanofilt_min_length:
    type: int?
    default: 200
    doc: "NanoFilt minimum read length (default: 200)"

  # === Variant calling ===
  call_variants:
    type: boolean?
    default: false
    doc: "Run medaka variant calling (haploid SNP/indel calling)"

  medaka_model:
    type: string?
    default: "r1041_e82_400bps_sup_variant_v4.3.0"
    doc: "Medaka model for variant calling"

  # === Structural variant calling ===
  call_structural_variants:
    type: boolean?
    default: false
    doc: "Run Sniffles2 structural variant calling"

  # === Transcript assembly ===
  run_stringtie:
    type: boolean?
    default: false
    doc: "Run StringTie2 transcript assembly"

  stringtie_annotation:
    type: File?
    doc: "Reference annotation GTF for StringTie2 guided assembly"

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
  # NanoFilt quality filtering (conditional)
  # =====================
  quality_filtering:
    run: steps/quality-filtering.cwl
    when: $(inputs.run_nanofilt == true)
    in:
      fastqs: fastq
      sample_ids: sample_ids
      quality: nanofilt_quality
      min_length: nanofilt_min_length
      run_nanofilt: run_nanofilt
    out: [filtered_fastqs]

  # =====================
  # minimap2 alignment (per sample)
  # =====================
  minimap2:
    run: ../../tools/minimap2.cwl
    scatter: [reads, sample_id]
    scatterMethod: dotproduct
    in:
      reads:
        source:
          - quality_filtering/filtered_fastqs
          - fastq
        pickValue: first_non_null
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
  # Medaka variant calling (conditional)
  # =====================
  variant_calling:
    run: steps/variant-calling.cwl
    when: $(inputs.call_variants == true)
    in:
      bams: samtools_sort/sorted_bam
      reference: reference
      sample_ids: sample_ids
      model: medaka_model
      call_variants: call_variants
    out: [vcfs, stats]

  # =====================
  # StringTie2 transcript assembly (conditional)
  # =====================
  transcript_assembly:
    run: steps/transcript-assembly.cwl
    when: $(inputs.run_stringtie == true)
    in:
      bams: samtools_sort/sorted_bam
      sample_ids: sample_ids
      annotation: stringtie_annotation
      run_stringtie: run_stringtie
    out: [transcript_gtfs]

  # =====================
  # Sniffles2 structural variant calling (conditional)
  # =====================
  structural_variant_calling:
    run: steps/structural-variant-calling.cwl
    when: $(inputs.call_structural_variants == true)
    in:
      bams: samtools_sort/sorted_bam
      sample_ids: sample_ids
      reference: reference
      call_structural_variants: call_structural_variants
    out: [sv_vcfs]

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
          - variant_calling/stats
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

  variant_vcfs:
    type: File[]?
    outputSource: variant_calling/vcfs
    doc: "Medaka variant VCF files per sample (when call_variants=true)"

  bcftools_stats_reports:
    type: File[]?
    outputSource: variant_calling/stats
    doc: "bcftools stats on variant VCFs (when call_variants=true)"

  filtered_fastqs:
    type: File[]?
    outputSource: quality_filtering/filtered_fastqs
    doc: "NanoFilt quality-filtered FASTQ files (when run_nanofilt=true)"

  transcript_gtfs:
    type: File[]?
    outputSource: transcript_assembly/transcript_gtfs
    doc: "StringTie2 assembled transcripts in GTF format (when run_stringtie=true)"

  structural_variant_vcfs:
    type: File[]?
    outputSource: structural_variant_calling/sv_vcfs
    doc: "Sniffles2 structural variant VCF files (when call_structural_variants=true)"
