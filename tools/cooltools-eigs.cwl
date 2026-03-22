#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "cooltools eigs-cis - A/B compartment calling"
doc: |
  Compute cis eigenvectors (A/B compartment signal) from a multi-resolution
  Hi-C contact matrix using cooltools eigs-cis. Identifies active (A) and
  inactive (B) chromatin compartments.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_eigs.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          MCOOL="$(inputs.mcool.path)"
          RESOLUTION=$(inputs.resolution)
          N_EIGS=$(inputs.n_eigs)
          PREFIX="$(inputs.prefix)"

          ARGS=""
          if [ "$(inputs.genome_gc)" != "null" ]; then
            ARGS="--phasing-track $(inputs.genome_gc.path)"
          fi

          cooltools eigs-cis \
            --n-eigs ${N_EIGS} \
            ${ARGS} \
            -o "${PREFIX}" \
            "${MCOOL}::resolutions/${RESOLUTION}"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/cooltools:0.7.1--py312hc9302aa_3"

baseCommand: [bash, run_eigs.sh]

inputs:
  mcool:
    type: File
    doc: "Multi-resolution contact matrix (.mcool)"

  resolution:
    type: int?
    default: 100000
    doc: "Resolution to use for compartment calling (bp)"

  n_eigs:
    type: int?
    default: 3
    doc: "Number of eigenvectors to compute"

  genome_gc:
    type: File?
    doc: "Optional GC content track for phasing eigenvectors"

  prefix:
    type: string
    doc: "Output file prefix"

outputs:
  eigenvalues:
    type: File
    outputBinding:
      glob: "*.lam.txt"
    doc: "Eigenvalues in TSV format"

  eigenvectors:
    type: File
    outputBinding:
      glob: "*.cis.vecs.tsv"
    doc: "Eigenvectors per genomic bin (TSV format)"
