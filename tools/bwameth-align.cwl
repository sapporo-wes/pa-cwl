#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "bwa-meth align"
doc: "Bisulfite-aware alignment using bwa-meth"

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 16384
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bwameth:0.2.7--pyhdfd78af_1"

baseCommand: [bwameth.py]

stdout: $(inputs.sample_id).bwameth.sam

inputs:
  genome_fasta:
    type: File
    secondaryFiles:
      - .bwameth.c2t
      - .bwameth.c2t.amb
      - .bwameth.c2t.ann
      - .bwameth.c2t.bwt
      - .bwameth.c2t.pac
      - .bwameth.c2t.sa
    inputBinding:
      prefix: --reference
    doc: "bwa-meth indexed reference FASTA"

  fastq_fwd:
    type: File
    inputBinding:
      position: 100
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    inputBinding:
      position: 101
    doc: "Reverse read FASTQ"

  sample_id:
    type: string
    doc: "Sample identifier"

arguments:
  - prefix: --threads
    valueFrom: $(runtime.cores)
  - prefix: --read-group
    valueFrom: "@RG\\tID:$(inputs.sample_id)\\tSM:$(inputs.sample_id)"

outputs:
  sam:
    type: File
    outputBinding:
      glob: "*.bwameth.sam"
