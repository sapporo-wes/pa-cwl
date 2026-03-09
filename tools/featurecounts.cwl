#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "featureCounts - Read counting"
doc: "Count reads mapped to genomic features using Subread featureCounts"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/subread:2.0.6--he4a0461_1"
  ResourceRequirement:
    coresMin: 4
    ramMin: 4096

baseCommand: [featureCounts]

inputs:
  bam:
    type: File
    inputBinding:
      position: 100
    doc: "Aligned BAM file"

  gtf:
    type: File
    inputBinding:
      prefix: -a
    doc: "Gene annotation GTF"

  sample_id:
    type: string
    doc: "Sample identifier"

  paired:
    type: boolean?
    default: true
    inputBinding:
      prefix: -p
    doc: "Count fragments instead of reads (paired-end)"

  strandedness:
    type: int?
    default: 0
    inputBinding:
      prefix: -s
    doc: "Strand-specificity: 0=unstranded, 1=forward, 2=reverse"

arguments:
  - prefix: -T
    valueFrom: $(runtime.cores)
  - prefix: -o
    valueFrom: $(inputs.sample_id)_featureCounts.txt
  - "-B"
  - "-C"

outputs:
  counts:
    type: File
    outputBinding:
      glob: "*_featureCounts.txt"

  summary:
    type: File
    outputBinding:
      glob: "*_featureCounts.txt.summary"
