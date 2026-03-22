#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "FusionInspector - In silico validation of fusion gene predictions"
doc: |
  Validate predicted gene fusions by realigning reads to fusion contigs.
  FusionInspector is part of the Trinity Cancer Transcriptomics toolkit
  and is typically used downstream of STAR-Fusion or Arriba.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 32768
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_fusion_inspector.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          FUSIONS="$1"
          GENOME_LIB="$2"
          LEFT_FQ="$3"
          RIGHT_FQ="$4"
          OUT_DIR="$5"
          THREADS="$6"

          FusionInspector \
            --fusions "$FUSIONS" \
            --genome_lib_dir "$GENOME_LIB" \
            --left_fq "$LEFT_FQ" \
            --right_fq "$RIGHT_FQ" \
            --out_dir "$OUT_DIR" \
            --CPU "$THREADS" \
            --vis

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/star-fusion:1.12.0--hdfd78af_1"

baseCommand: [bash, run_fusion_inspector.sh]

inputs:
  fusions_file:
    type: File
    doc: "Fusion predictions TSV (from STAR-Fusion or converted Arriba output)"

  ctat_lib:
    type: Directory
    doc: "CTAT genome library directory"

  fastq_fwd:
    type: File
    doc: "Forward read FASTQ file"

  fastq_rev:
    type: File
    doc: "Reverse read FASTQ file"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - position: 1
    valueFrom: $(inputs.fusions_file.path)
  - position: 2
    valueFrom: $(inputs.ctat_lib.path)
  - position: 3
    valueFrom: $(inputs.fastq_fwd.path)
  - position: 4
    valueFrom: $(inputs.fastq_rev.path)
  - position: 5
    valueFrom: $(inputs.sample_id)_inspector_out
  - position: 6
    valueFrom: $(runtime.cores)

outputs:
  validated_fusions:
    type: File
    outputBinding:
      glob: "*_inspector_out/finspector.FusionInspector.fusions.tsv"
    doc: "Validated fusion predictions"

  evidence_bam:
    type: File
    outputBinding:
      glob: "*_inspector_out/finspector.consolidated.bam"
    doc: "Evidence BAM with reads supporting fusions"
