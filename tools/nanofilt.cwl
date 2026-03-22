#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "NanoFilt - Quality filtering for Nanopore reads"
doc: |
  Filter Nanopore reads by quality score and/or read length.
  Reads from stdin and writes filtered reads to stdout.
  Handles both gzipped and uncompressed FASTQ input.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 2048
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_nanofilt.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          INPUT="$1"
          SAMPLE_ID="$2"
          shift 2

          # Detect gzipped input and decompress if needed
          case "$INPUT" in
            *.gz) gunzip -c "$INPUT" | NanoFilt "$@" > "$SAMPLE_ID.filtered.fastq" ;;
            *)    NanoFilt "$@" < "$INPUT" > "$SAMPLE_ID.filtered.fastq" ;;
          esac

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/nanofilt:2.8.0--py_0"

baseCommand: [bash, run_nanofilt.sh]

arguments:
  - position: 1
    valueFrom: $(inputs.fastq.path)
  - position: 2
    valueFrom: $(inputs.sample_id)

inputs:
  fastq:
    type: File
    doc: "Input FASTQ file (Nanopore reads, gzipped or uncompressed)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

  quality:
    type: int?
    default: 7
    inputBinding:
      prefix: -q
      position: 10
    doc: "Minimum average read quality score to keep (default: 7)"

  min_length:
    type: int?
    default: 200
    inputBinding:
      prefix: -l
      position: 10
    doc: "Minimum read length to keep (default: 200)"

  max_length:
    type: int?
    inputBinding:
      prefix: --maxlength
      position: 10
    doc: "Maximum read length to keep"

  headcrop:
    type: int?
    inputBinding:
      prefix: --headcrop
      position: 10
    doc: "Trim N nucleotides from the start of each read"

  tailcrop:
    type: int?
    inputBinding:
      prefix: --tailcrop
      position: 10
    doc: "Trim N nucleotides from the end of each read"

outputs:
  filtered_fastq:
    type: File
    outputBinding:
      glob: "*.filtered.fastq"
    doc: "Quality-filtered FASTQ file"
