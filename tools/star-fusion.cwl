#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "STAR-Fusion - Fusion gene detection from chimeric junctions"
doc: |
  Detect fusion genes using STAR-Fusion from chimeric junction files
  produced by STAR alignment. Can also accept FASTQ files directly.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 32768
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_star_fusion.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          GENOME_LIB="$1"
          CHIMERIC_JUNCTION="$2"
          OUTPUT_DIR="$3"
          THREADS="$4"

          STAR-Fusion \
            --genome_lib_dir "$GENOME_LIB" \
            -J "$CHIMERIC_JUNCTION" \
            --output_dir "$OUTPUT_DIR" \
            --CPU "$THREADS"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/star-fusion:1.12.0--hdfd78af_1"

baseCommand: [bash, run_star_fusion.sh]

inputs:
  chimeric_junction:
    type: File
    doc: "STAR Chimeric.out.junction file"

  ctat_lib:
    type: Directory
    doc: "CTAT genome library directory"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - position: 1
    valueFrom: $(inputs.ctat_lib.path)
  - position: 2
    valueFrom: $(inputs.chimeric_junction.path)
  - position: 3
    valueFrom: $(inputs.sample_id)_starfusion_out
  - position: 4
    valueFrom: $(runtime.cores)

outputs:
  fusion_predictions:
    type: File
    outputBinding:
      glob: "*_starfusion_out/star-fusion.fusion_predictions.tsv"
    doc: "STAR-Fusion predicted gene fusions"

  fusion_predictions_abridged:
    type: File
    outputBinding:
      glob: "*_starfusion_out/star-fusion.fusion_predictions.abridged.tsv"
    doc: "Abridged STAR-Fusion predicted gene fusions"
