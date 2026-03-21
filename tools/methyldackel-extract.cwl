#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "MethylDackel extract"
doc: "Extract methylation metrics from bisulfite-aligned BAM files"

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/methyldackel:0.6.1--hdbdd923_2"

baseCommand: [MethylDackel, extract]

inputs:
  bam:
    type: File
    secondaryFiles:
      - .bai
    inputBinding:
      position: 2
    doc: "Sorted, indexed BAM file from bisulfite alignment"

  reference:
    type: File
    secondaryFiles:
      - .fai
    inputBinding:
      position: 1
    doc: "Reference genome FASTA with .fai index"

  sample_id:
    type: string
    doc: "Sample identifier"

  merge_context:
    type: boolean?
    default: true
    inputBinding:
      prefix: --mergeContext
    doc: "Merge CpG context (combine top/bottom strand)"

  min_depth:
    type: int?
    default: 1
    inputBinding:
      prefix: --minDepth
    doc: "Minimum read depth for reporting"

arguments:
  - prefix: -o
    valueFrom: $(inputs.sample_id)
  - prefix: -@
    valueFrom: $(runtime.cores)

outputs:
  bedgraph:
    type: File
    outputBinding:
      glob: "*.bedGraph"
    doc: "Methylation bedGraph (CpG context)"
