#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 CalculateContamination"
doc: "Estimate cross-sample contamination from pileup summaries"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, CalculateContamination]

inputs:
  tumor_pileups:
    type: File
    inputBinding:
      prefix: -I
    doc: "Tumor pileup summary table from GetPileupSummaries"

  normal_pileups:
    type: File?
    inputBinding:
      prefix: -matched
    doc: "Matched normal pileup summary table (optional)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: -O
    valueFrom: $(inputs.sample_id).contamination.table
  - prefix: --tumor-segmentation
    valueFrom: $(inputs.sample_id).segments.table

outputs:
  contamination_table:
    type: File
    outputBinding:
      glob: "*.contamination.table"
    doc: "Contamination estimate table"

  segmentation_table:
    type: File
    outputBinding:
      glob: "*.segments.table"
    doc: "Tumor segmentation table"
