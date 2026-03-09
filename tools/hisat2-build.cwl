#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "HISAT2-build - Build HISAT2 genome index"
doc: "Generate HISAT2 genome index from reference FASTA"

requirements:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/hisat2:2.2.1--h87f3376_4"
  ResourceRequirement:
    coresMin: 8
    ramMin: 8192

baseCommand: [hisat2-build]

inputs:
  genome_fasta:
    type: File
    inputBinding:
      position: 1
    doc: "Reference genome FASTA"

  index_basename:
    type: string?
    default: "hisat2_index"
    inputBinding:
      position: 2
    doc: "Basename for index files"

arguments:
  - prefix: -p
    valueFrom: $(runtime.cores)

outputs:
  index_files:
    type: File[]
    outputBinding:
      glob: "hisat2_index.*.ht2"
