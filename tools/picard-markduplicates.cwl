#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Picard MarkDuplicates - Mark PCR duplicates"
doc: "Identify and mark duplicate reads in BAM files"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 8192

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/picard:3.1.1--hdfd78af_0"

baseCommand: [picard, MarkDuplicates]

inputs:
  sorted_bam:
    type: File
    inputBinding:
      prefix: INPUT=
      separate: false
    doc: "Coordinate-sorted BAM file"

  sample_id:
    type: string
    doc: "Sample identifier"

arguments:
  - prefix: OUTPUT=
    separate: false
    valueFrom: $(inputs.sample_id).markdup.bam
  - prefix: METRICS_FILE=
    separate: false
    valueFrom: $(inputs.sample_id).markdup_metrics.txt
  - "REMOVE_DUPLICATES=false"
  - "VALIDATION_STRINGENCY=LENIENT"
  - "CREATE_INDEX=true"

outputs:
  markdup_bam:
    type: File
    secondaryFiles:
      - ^.bai
    outputBinding:
      glob: "*.markdup.bam"

  metrics:
    type: File
    outputBinding:
      glob: "*.markdup_metrics.txt"
