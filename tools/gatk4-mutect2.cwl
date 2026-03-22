#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 Mutect2"
doc: "Call somatic SNVs and indels via local assembly of haplotypes"

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 8192
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, Mutect2]

inputs:
  tumor_bam:
    type: File
    secondaryFiles:
      - ^.bai
    inputBinding:
      prefix: -I
    doc: "Tumor BAM file (sorted, indexed)"

  normal_bam:
    type: File?
    secondaryFiles:
      - ^.bai
    inputBinding:
      prefix: -I
    doc: "Matched normal BAM file (optional)"

  normal_sample_id:
    type: string?
    inputBinding:
      prefix: -normal
    doc: "Normal sample name (SM tag from BAM read group)"

  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
    inputBinding:
      prefix: -R
    doc: "Reference genome FASTA with .fai and .dict"

  germline_resource:
    type: File?
    secondaryFiles:
      - .tbi
    inputBinding:
      prefix: --germline-resource
    doc: "Population germline resource (e.g., gnomAD af-only VCF)"

  panel_of_normals:
    type: File?
    secondaryFiles:
      - .tbi
    inputBinding:
      prefix: --panel-of-normals
    doc: "Panel of normals VCF"

  intervals:
    type: File?
    inputBinding:
      prefix: -L
    doc: "Intervals BED file (for WES/targeted)"

  sample_id:
    type: string
    doc: "Tumor sample identifier for output naming"

arguments:
  - prefix: -O
    valueFrom: $(inputs.sample_id).mutect2.vcf.gz
  - prefix: --f1r2-tar-gz
    valueFrom: $(inputs.sample_id).f1r2.tar.gz

outputs:
  vcf:
    type: File
    secondaryFiles:
      - .tbi
      - .stats
    outputBinding:
      glob: "*.mutect2.vcf.gz"
    doc: "Unfiltered somatic VCF with stats"

  f1r2_counts:
    type: File
    outputBinding:
      glob: "*.f1r2.tar.gz"
    doc: "F1R2 read counts for orientation bias model"
