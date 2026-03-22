#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 FilterMutectCalls"
doc: "Filter somatic SNVs and indels called by Mutect2"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, FilterMutectCalls]

inputs:
  vcf:
    type: File
    secondaryFiles:
      - .tbi
      - .stats
    inputBinding:
      prefix: -V
    doc: "Unfiltered Mutect2 VCF with .tbi and .stats"

  reference:
    type: File
    secondaryFiles:
      - .fai
      - ^.dict
    inputBinding:
      prefix: -R
    doc: "Reference genome FASTA"

  contamination_table:
    type: File?
    inputBinding:
      prefix: --contamination-table
    doc: "Contamination estimate from CalculateContamination"

  segmentation_table:
    type: File?
    inputBinding:
      prefix: --tumor-segmentation
    doc: "Tumor segmentation table from CalculateContamination"

  orientation_model:
    type: File?
    inputBinding:
      prefix: --ob-priors
    doc: "Orientation bias artifact priors from LearnReadOrientationModel"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: -O
    valueFrom: $(inputs.sample_id).mutect2.filtered.vcf.gz

outputs:
  filtered_vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.mutect2.filtered.vcf.gz"
    doc: "Filtered somatic VCF"
