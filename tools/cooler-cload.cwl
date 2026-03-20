#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "cooler cload - Load pairs into contact matrix"
doc: |
  Create a cooler (.cool) contact matrix from pairs file at specified
  bin resolution. Uses cooler cload pairs for indexed pairs files.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_cooler.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          PREFIX="$(inputs.sample_id)"
          CHROMSIZES="$(inputs.chromsizes.path)"
          PAIRS="$(inputs.valid_pairs.path)"
          RESOLUTION=$(inputs.resolution)

          # Create bins
          cooler makebins "\${CHROMSIZES}" \${RESOLUTION} > bins.bed

          # Load pairs into cooler format
          cooler cload pairs \
            -c1 2 -p1 3 -c2 4 -p2 5 \
            "\${CHROMSIZES}:\${RESOLUTION}" \
            "\${PAIRS}" \
            \${PREFIX}_\${RESOLUTION}.cool

          # Balance (ICE normalization)
          cooler balance \${PREFIX}_\${RESOLUTION}.cool 2>&1 || true

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/cooler:0.10.3--pyhdfd78af_0"

baseCommand: [bash, run_cooler.sh]

inputs:
  valid_pairs:
    type: File
    doc: "Valid pairs file (.pairs.gz)"

  chromsizes:
    type: File
    doc: "Chromosome sizes file"

  sample_id:
    type: string
    doc: "Sample identifier"

  resolution:
    type: int?
    default: 10000
    doc: "Bin resolution in base pairs"

outputs:
  cool:
    type: File
    outputBinding:
      glob: "*.cool"
    doc: "Contact matrix in cooler format"
