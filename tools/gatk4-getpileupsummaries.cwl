#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 GetPileupSummaries"
doc: "Tabulate pileup metrics at known variant sites for contamination estimation"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, GetPileupSummaries]

inputs:
  bam:
    type: File
    secondaryFiles:
      - ^.bai
    inputBinding:
      prefix: -I
    doc: "Input BAM file (sorted, indexed)"

  variants:
    type: File
    secondaryFiles:
      - .tbi
    inputBinding:
      prefix: -V
    doc: "Population germline variants for pileup (e.g., gnomAD biallelic sites)"

  intervals:
    type: File?
    inputBinding:
      prefix: -L
    doc: "Intervals to restrict pileup"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: -L
    valueFrom: $(inputs.variants.path)
  - prefix: -O
    valueFrom: $(inputs.sample_id).pileups.table

outputs:
  pileup_table:
    type: File
    outputBinding:
      glob: "*.pileups.table"
    doc: "Pileup summary table"
