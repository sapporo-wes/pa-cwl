#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "juicer_tools pre - Convert pairs to .hic format"
doc: |
  Convert pairs file to Juicer .hic format for visualization in
  JuiceBox and downstream analysis. Generates a multi-resolution
  .hic contact matrix.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 16384
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_juicer_pre.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          PAIRS="$(inputs.pairs_file.path)"
          CHROMSIZES="$(inputs.chrom_sizes.path)"
          OUTPUT="$(inputs.output_name)"
          RESOLUTIONS="$(inputs.resolutions)"

          # juicer_tools pre expects: <pairs> <output.hic> <genome_sizes>
          # -r flag for resolutions
          juicer_tools pre \
            -r "$RESOLUTIONS" \
            "$PAIRS" \
            "$OUTPUT" \
            "$CHROMSIZES"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/juicertools:2.20.00--hdfd78af_0"

baseCommand: [bash, run_juicer_pre.sh]

inputs:
  pairs_file:
    type: File
    doc: "Valid pairs file (.pairs.gz)"

  chrom_sizes:
    type: File
    doc: "Chromosome sizes file (tab-separated: chrom<tab>size)"

  output_name:
    type: string
    doc: "Output .hic file name"

  resolutions:
    type: string?
    default: "1000,5000,10000,25000,50000,100000"
    doc: "Comma-separated list of resolutions for the .hic file"

outputs:
  hic_file:
    type: File
    outputBinding:
      glob: "*.hic"
    doc: "Contact matrix in Juicer .hic format"
