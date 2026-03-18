#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Bowtie2-build - Build Bowtie2 index"
doc: "Build a Bowtie2 index from a reference FASTA."

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.reference)
        writable: false

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bowtie2:2.5.4--he20e202_2"

baseCommand: [bowtie2-build]

inputs:
  reference:
    type: File
    inputBinding:
      position: 1
    doc: "Reference FASTA to index"

arguments:
  - position: 2
    valueFrom: bt2_index
  - prefix: --threads
    valueFrom: $(runtime.cores)

outputs:
  index_dir:
    type: File[]
    outputBinding:
      glob: "bt2_index*.bt2*"
    doc: "Bowtie2 index files"

  index_base:
    type: string
    outputBinding:
      outputEval: $("bt2_index")
    doc: "Index base name for bowtie2 alignment"
