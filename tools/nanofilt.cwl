#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "NanoFilt - Quality filtering for Nanopore reads"
doc: |
  Filter Nanopore reads by quality score and/or read length.
  Reads from stdin and writes filtered reads to stdout.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 2048
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/nanofilt:2.8.0--py_0"

baseCommand: [NanoFilt]

stdin: $(inputs.fastq.path)
stdout: $(inputs.sample_id).filtered.fastq

inputs:
  fastq:
    type: File
    doc: "Input FASTQ file (Nanopore reads)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

  quality:
    type: int?
    default: 7
    inputBinding:
      prefix: -q
    doc: "Minimum average read quality score to keep (default: 7)"

  min_length:
    type: int?
    default: 200
    inputBinding:
      prefix: -l
    doc: "Minimum read length to keep (default: 200)"

  max_length:
    type: int?
    inputBinding:
      prefix: --maxlength
    doc: "Maximum read length to keep"

  headcrop:
    type: int?
    inputBinding:
      prefix: --headcrop
    doc: "Trim N nucleotides from the start of each read"

  tailcrop:
    type: int?
    inputBinding:
      prefix: --tailcrop
    doc: "Trim N nucleotides from the end of each read"

outputs:
  filtered_fastq:
    type: File
    outputBinding:
      glob: "*.filtered.fastq"
    doc: "Quality-filtered FASTQ file"
