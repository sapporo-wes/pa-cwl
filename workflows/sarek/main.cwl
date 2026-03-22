#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "sarek - Germline variant calling pipeline"
doc: |
  Germline variant calling pipeline based on GATK best practices.
  Performs QC, trimming, BWA-MEM2 alignment, duplicate marking,
  optional BQSR, GATK HaplotypeCaller, optional joint calling
  (GenomicsDBImport + GenotypeGVCFs), hard filtering, and QC reporting.

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
    doc: "Reference genome FASTA"

  # === Pre-built BWA index (optional) ===
  bwa_index:
    type: File?
    secondaryFiles:
      - pattern: ".0123"
      - pattern: .amb
      - pattern: .ann
      - pattern: .bwt.2bit.64
      - pattern: .pac
    doc: "Pre-built BWA-MEM2 indexed genome FASTA"

  # === Variant calling options ===
  dbsnp:
    type: File?
    secondaryFiles:
      - .tbi
    doc: "dbSNP VCF for HaplotypeCaller annotation"

  intervals:
    type: File?
    doc: "Intervals BED file for WES/targeted sequencing"

  emit_gvcf:
    type: boolean?
    default: false
    doc: "Emit per-sample gVCF and run joint calling via GenomicsDBImport + GenotypeGVCFs"

  cohort_id:
    type: string?
    default: "cohort"
    doc: "Cohort identifier for joint calling output naming (used when emit_gvcf=true)"

  # === BQSR (optional) ===
  known_sites:
    type: File[]?
    secondaryFiles:
      - .tbi
    doc: "Known variant sites VCFs for BQSR (dbSNP, Mills indels). BQSR is skipped if not provided."

  # === Scatter-gather parallelism ===
  scatter_count:
    type: int?
    default: 1
    doc: "Number of genomic interval shards for scatter-gather HaplotypeCaller (1 = no scatter)"

  # === Tool options ===
  trimmer:
    type:
      type: enum
      symbols: [fastp, trim_galore, skip]
    default: fastp
    doc: "Read trimming tool"

steps:
  # =====================
  # Reference preparation (faidx + dict)
  # =====================
  prepare_reference:
    run: ../../tools/prepare-gatk-reference.cwl
    in:
      genome_fasta: genome_fasta
    out: [reference]

  # =====================
  # BWA-MEM2 index building (conditional)
  # =====================
  build_bwa_index:
    run: ../../tools/bwa-mem2-index.cwl
    when: $(inputs.bwa_index == null)
    in:
      genome_fasta: genome_fasta
      bwa_index: bwa_index
    out: [genome_with_index]

  # =====================
  # QC + Trimming
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
  # Alignment + sort + markdup
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
  # Alignment QC
  # =====================
  samtools_stats:
    run: ../../tools/samtools-stats.cwl
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: align/aligned_bam
      sample_id: sample_ids
    out: [stats]

  # =====================
  # BQSR (conditional — skipped when known_sites not provided)
  # =====================
  bqsr:
    run: steps/bqsr.cwl
    when: $(inputs.known_sites != null && inputs.known_sites.length > 0)
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: align/aligned_bam
      reference: prepare_reference/reference
      known_sites: known_sites
      intervals: intervals
      sample_id: sample_ids
    out: [recalibrated_bam, recalibration_table]

  # =====================
  # Select BAM (BQSR-recalibrated or original)
  # =====================
  select_bam:
    run:
      class: ExpressionTool
      requirements:
        InlineJavascriptRequirement: {}
      inputs:
        bqsr_bams:
          type: Any
        align_bams:
          type: File[]
      outputs:
        bams:
          type: File[]
      expression: |
        ${
          var bqsr = inputs.bqsr_bams;
          if (bqsr !== null && Array.isArray(bqsr) && bqsr.length > 0 && bqsr[0] !== null) {
            return {bams: bqsr};
          }
          return {bams: inputs.align_bams};
        }
    in:
      bqsr_bams: bqsr/recalibrated_bam
      align_bams: align/aligned_bam
    out: [bams]

  # =====================
  # Split intervals for scatter-gather (conditional)
  # =====================
  split_intervals:
    run: ../../tools/gatk4-split-intervals.cwl
    when: $(inputs.scatter_count != null && inputs.scatter_count > 1)
    in:
      reference: prepare_reference/reference
      intervals: intervals
      scatter_count: scatter_count
    out: [interval_files]

  # =====================
  # GATK HaplotypeCaller — direct (when scatter disabled)
  # =====================
  haplotypecaller:
    run: ../../tools/gatk4-haplotypecaller.cwl
    when: $(inputs.scatter_count == null || inputs.scatter_count <= 1)
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: select_bam/bams
      reference: prepare_reference/reference
      dbsnp: dbsnp
      intervals: intervals
      sample_id: sample_ids
      emit_gvcf: emit_gvcf
      scatter_count: scatter_count
    out: [vcf]

  # =====================
  # GATK HaplotypeCaller — scatter-gather (when scatter enabled)
  # =====================
  haplotypecaller_scatter:
    run: steps/haplotypecaller-scatter.cwl
    when: $(inputs.scatter_count != null && inputs.scatter_count > 1)
    scatter: [bam, sample_id]
    scatterMethod: dotproduct
    in:
      bam: select_bam/bams
      reference: prepare_reference/reference
      dbsnp: dbsnp
      interval_files: split_intervals/interval_files
      sample_id: sample_ids
      emit_gvcf: emit_gvcf
      scatter_count: scatter_count
    out: [vcf]

  # =====================
  # Select VCF (from direct or scatter HaplotypeCaller)
  # =====================
  select_vcf:
    run:
      class: ExpressionTool
      requirements:
        InlineJavascriptRequirement: {}
      inputs:
        direct_vcfs:
          type: Any
        scatter_vcfs:
          type: Any
      outputs:
        vcfs:
          type: File[]
      expression: |
        ${
          var direct = inputs.direct_vcfs;
          if (direct !== null && Array.isArray(direct) && direct.length > 0 && direct[0] !== null) {
            return {vcfs: direct};
          }
          var scatter = inputs.scatter_vcfs;
          if (scatter !== null && Array.isArray(scatter) && scatter.length > 0 && scatter[0] !== null) {
            return {vcfs: scatter};
          }
          return {vcfs: []};
        }
    in:
      direct_vcfs: haplotypecaller/vcf
      scatter_vcfs: haplotypecaller_scatter/vcf
    out: [vcfs]

  # =====================
  # Joint calling (conditional — runs when emit_gvcf=true)
  # =====================
  joint_calling:
    run: steps/joint-calling.cwl
    when: $(inputs.emit_gvcf == true)
    in:
      gvcfs: select_vcf/vcfs
      reference: prepare_reference/reference
      dbsnp: dbsnp
      intervals: intervals
      cohort_id: cohort_id
      emit_gvcf: emit_gvcf
    out: [joint_vcf]

  # =====================
  # Joint VCF hard filtering (conditional)
  # =====================
  joint_variant_filtration:
    run: ../../tools/gatk4-variantfiltration.cwl
    when: $(inputs.vcf != null)
    in:
      vcf: joint_calling/joint_vcf
      reference: prepare_reference/reference
      sample_id: cohort_id
    out: [filtered_vcf]

  # =====================
  # Joint VCF QC (conditional)
  # =====================
  joint_bcftools_stats:
    run: ../../tools/bcftools-stats.cwl
    when: $(inputs.vcf != null)
    in:
      vcf: joint_variant_filtration/filtered_vcf
      sample_id: cohort_id
    out: [stats]

  # =====================
  # Hard filtering (per-sample)
  # =====================
  variant_filtration:
    run: ../../tools/gatk4-variantfiltration.cwl
    scatter: [vcf, sample_id]
    scatterMethod: dotproduct
    in:
      vcf: select_vcf/vcfs
      reference: prepare_reference/reference
      sample_id: sample_ids
    out: [filtered_vcf]

  # =====================
  # VCF QC
  # =====================
  bcftools_stats:
    run: ../../tools/bcftools-stats.cwl
    scatter: [vcf, sample_id]
    scatterMethod: dotproduct
    in:
      vcf: variant_filtration/filtered_vcf
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
          - bqsr/recalibration_table
          - bcftools_stats/stats
          - joint_bcftools_stats/stats
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl sarek"
    out: [html_report, data_dir]

outputs:
  filtered_vcfs:
    type: File[]
    outputSource: variant_filtration/filtered_vcf
    doc: "Filtered VCF files per sample"

  raw_vcfs:
    type: File[]
    outputSource: select_vcf/vcfs
    doc: "Raw HaplotypeCaller VCF files per sample"

  aligned_bams:
    type: File[]
    outputSource: align/aligned_bam
    doc: "Marked-duplicate BAM files per sample"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"

  samtools_stats_reports:
    type: File[]
    outputSource: samtools_stats/stats
    doc: "samtools stats reports"

  bcftools_stats_reports:
    type: File[]
    outputSource: bcftools_stats/stats
    doc: "bcftools stats on filtered VCFs"

  joint_vcf:
    type: File?
    outputSource: joint_calling/joint_vcf
    doc: "Joint-called multi-sample VCF (when emit_gvcf=true)"

  joint_filtered_vcf:
    type: File?
    outputSource: joint_variant_filtration/filtered_vcf
    doc: "Filtered joint-called VCF (when emit_gvcf=true)"
