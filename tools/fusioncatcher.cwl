#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "FusionCatcher - Fusion gene detection from RNA-seq"
doc: |
  Detect fusion genes from paired-end RNA-seq data using FusionCatcher.
  Uses an ensemble of methods for high sensitivity and specificity.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 32768
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_fusioncatcher.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          DATA_DIR="$1"
          FWD="$2"
          REV="$3"
          OUTPUT_DIR="$4"
          THREADS="$5"

          mkdir -p input_dir
          ln -s "$FWD" input_dir/reads_1.fq.gz
          ln -s "$REV" input_dir/reads_2.fq.gz

          fusioncatcher \
            -d "$DATA_DIR" \
            -i input_dir \
            -o "$OUTPUT_DIR" \
            -p "$THREADS"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/fusioncatcher:1.33--hdfd78af_5"

baseCommand: [bash, run_fusioncatcher.sh]

inputs:
  fastq_fwd:
    type: File
    doc: "Forward read FASTQ file"

  fastq_rev:
    type: File
    doc: "Reverse read FASTQ file"

  data_dir:
    type: Directory
    doc: "FusionCatcher data directory (organism database)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - position: 1
    valueFrom: $(inputs.data_dir.path)
  - position: 2
    valueFrom: $(inputs.fastq_fwd.path)
  - position: 3
    valueFrom: $(inputs.fastq_rev.path)
  - position: 4
    valueFrom: $(inputs.sample_id)_fusioncatcher_out
  - position: 5
    valueFrom: $(runtime.cores)

outputs:
  final_fusions:
    type: File
    outputBinding:
      glob: "*_fusioncatcher_out/final-list_candidate-fusion-genes.txt"
    doc: "Final list of candidate fusion genes"

  summary:
    type: File
    outputBinding:
      glob: "*_fusioncatcher_out/summary_candidate_fusions.txt"
    doc: "Summary of candidate fusion genes"
