#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "HiCExplorer hicFindTADs - Find topologically associating domains"
doc: |
  Identify topologically associating domains (TADs) from Hi-C contact
  matrices using HiCExplorer's hicFindTADs. Computes insulation scores
  and calls TAD boundaries with FDR correction.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_find_tads.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          MATRIX="$(inputs.cool_matrix.path)"
          PREFIX="$(inputs.prefix)"
          THREADS=$(runtime.cores)

          hicFindTADs \
            -m "${MATRIX}" \
            --outPrefix "${PREFIX}" \
            --correctForMultipleTesting fdr \
            --numberOfProcessors ${THREADS}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/hicexplorer:3.7.6--pyhdfd78af_0"

baseCommand: [bash, run_find_tads.sh]

inputs:
  cool_matrix:
    type: File
    doc: "Hi-C contact matrix in cooler (.cool) format"

  prefix:
    type: string
    doc: "Output file prefix for TAD results"

outputs:
  tad_boundaries:
    type: File
    outputBinding:
      glob: "*_boundaries.bed"
    doc: "TAD boundary positions in BED format"

  tad_domains:
    type: File
    outputBinding:
      glob: "*_domains.bed"
    doc: "TAD domain regions in BED format"

  tad_scores:
    type: File
    outputBinding:
      glob: "*_score.bedgraph"
    doc: "TAD separation scores in bedGraph format"

  insulation_score:
    type: File
    outputBinding:
      glob: "*_tad_score.bm"
    doc: "Insulation score matrix"
