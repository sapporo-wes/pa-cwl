#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "kb count - Kallisto BUStools single-cell quantification"
doc: |
  Pseudoalign single-cell RNA-seq reads and generate gene-barcode count
  matrices using kallisto bus and bustools via kb-python.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 16384
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_kb_count.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          INDEX="$1"
          T2G="$2"
          CHEMISTRY="$3"
          THREADS="$4"
          shift 4

          # Remaining arguments are interleaved barcode and cDNA FASTQs
          kb count \
            -i "$INDEX" \
            -g "$T2G" \
            -x "$CHEMISTRY" \
            -o kb_output \
            -t "$THREADS" \
            "$@"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/kb-python:0.28.2--pyhdfd78af_2"

baseCommand: [bash, run_kb_count.sh]

inputs:
  index:
    type: File
    doc: "Kallisto index file"

  t2g:
    type: File
    doc: "Transcript-to-gene mapping file"

  chemistry:
    type: string
    default: "10xv3"
    doc: "Single-cell technology string (10xv2, 10xv3, etc.)"

  fastq_barcode:
    type: File[]
    doc: "Barcode + UMI reads (R1 for 10x Chromium)"

  fastq_cdna:
    type: File[]
    doc: "cDNA reads (R2 for 10x Chromium)"

arguments:
  - position: 1
    valueFrom: $(inputs.index.path)
  - position: 2
    valueFrom: $(inputs.t2g.path)
  - position: 3
    valueFrom: $(inputs.chemistry)
  - position: 4
    valueFrom: $(runtime.cores)
  # Interleave barcode and cDNA FASTQs for kb count
  - position: 5
    valueFrom: |
      ${
        var args = [];
        for (var i = 0; i < inputs.fastq_barcode.length; i++) {
          args.push(inputs.fastq_barcode[i].path);
          args.push(inputs.fastq_cdna[i].path);
        }
        return args;
      }

outputs:
  count_dir:
    type: Directory
    outputBinding:
      glob: kb_output
    doc: "Kallisto BUStools output directory with count matrices"

  bus_file:
    type: File
    outputBinding:
      glob: kb_output/output.bus
    doc: "BUS format file"
