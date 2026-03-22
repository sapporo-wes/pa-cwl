#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Mutect2 somatic variant calling pipeline"
doc: |
  Full Mutect2 somatic calling pipeline for a single tumor sample:
  Mutect2 → LearnReadOrientationModel → optional GetPileupSummaries
  → optional CalculateContamination → FilterMutectCalls.

requirements:
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  tumor_bam:
    type: File
    secondaryFiles:
      - ^.bai
    doc: "Tumor BAM file (sorted, indexed)"

  normal_bam:
    type: File?
    secondaryFiles:
      - ^.bai
    doc: "Matched normal BAM file (optional)"

  normal_sample_id:
    type: string?
    doc: "Normal sample name (SM tag from read group)"

  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
    doc: "Reference genome FASTA"

  germline_resource:
    type: File?
    secondaryFiles:
      - .tbi
    doc: "Population germline resource (gnomAD af-only VCF)"

  panel_of_normals:
    type: File?
    secondaryFiles:
      - .tbi
    doc: "Panel of normals VCF"

  intervals:
    type: File?
    doc: "Intervals BED file"

  sample_id:
    type: string
    doc: "Tumor sample identifier"

steps:
  # =====================
  # Mutect2 calling
  # =====================
  mutect2:
    run: ../../../tools/gatk4-mutect2.cwl
    in:
      tumor_bam: tumor_bam
      normal_bam: normal_bam
      normal_sample_id: normal_sample_id
      reference: reference
      germline_resource: germline_resource
      panel_of_normals: panel_of_normals
      intervals: intervals
      sample_id: sample_id
    out: [vcf, f1r2_counts]

  # =====================
  # Learn orientation bias model
  # =====================
  learn_orientation:
    run: ../../../tools/gatk4-learnreadorientationmodel.cwl
    in:
      f1r2_counts: mutect2/f1r2_counts
      sample_id: sample_id
    out: [orientation_model]

  # =====================
  # Pileup summaries — tumor (conditional on germline_resource)
  # =====================
  pileup_tumor:
    run: ../../../tools/gatk4-getpileupsummaries.cwl
    when: $(inputs.variants != null)
    in:
      bam: tumor_bam
      variants: germline_resource
      intervals: intervals
      sample_id:
        source: sample_id
        valueFrom: $(self).tumor
    out: [pileup_table]

  # =====================
  # Pileup summaries — normal (conditional on both germline_resource and normal_bam)
  # =====================
  pileup_normal:
    run: ../../../tools/gatk4-getpileupsummaries.cwl
    when: $(inputs.variants != null && inputs.bam != null)
    in:
      bam: normal_bam
      variants: germline_resource
      intervals: intervals
      sample_id:
        source: sample_id
        valueFrom: $(self).normal
    out: [pileup_table]

  # =====================
  # Calculate contamination (conditional on germline_resource)
  # =====================
  calculate_contamination:
    run: ../../../tools/gatk4-calculatecontamination.cwl
    when: $(inputs.tumor_pileups != null)
    in:
      tumor_pileups: pileup_tumor/pileup_table
      normal_pileups: pileup_normal/pileup_table
      sample_id: sample_id
    out: [contamination_table, segmentation_table]

  # =====================
  # Filter Mutect2 calls
  # =====================
  filter:
    run: ../../../tools/gatk4-filtermutectcalls.cwl
    in:
      vcf: mutect2/vcf
      reference: reference
      contamination_table: calculate_contamination/contamination_table
      segmentation_table: calculate_contamination/segmentation_table
      orientation_model: learn_orientation/orientation_model
      sample_id: sample_id
    out: [filtered_vcf]

outputs:
  filtered_vcf:
    type: File
    outputSource: filter/filtered_vcf
    doc: "Filtered somatic VCF"

  unfiltered_vcf:
    type: File
    outputSource: mutect2/vcf
    doc: "Unfiltered Mutect2 VCF (with stats)"

  contamination_table:
    type: File?
    outputSource: calculate_contamination/contamination_table
    doc: "Contamination estimate"
