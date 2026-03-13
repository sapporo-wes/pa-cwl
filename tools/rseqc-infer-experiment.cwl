#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "RSeQC infer_experiment - Infer library strandedness"
doc: "Infer RNA-seq library strandedness from a BAM file and gene model"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 2048

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/rseqc:5.0.4--pyhdfd78af_1"

baseCommand: [infer_experiment.py]

inputs:
  bam:
    type: File
    secondaryFiles:
      - ^.bai
    inputBinding:
      prefix: -i
    doc: "Indexed BAM file"

  bed:
    type: File
    inputBinding:
      prefix: -r
    doc: "Gene model in BED12 format"

  sample_id:
    type: string
    doc: "Sample identifier"

stdout: $(inputs.sample_id).infer_experiment.txt

outputs:
  report:
    type: File
    outputBinding:
      glob: "*.infer_experiment.txt"
