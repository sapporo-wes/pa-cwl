#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "MaxBin2 - Metagenome binning"
doc: |
  Binning of metagenome contigs using MaxBin2. Can use an abundance
  file (e.g., from MetaBAT2 depth calculation) instead of raw reads.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_maxbin2.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          CONTIGS="$(inputs.contigs.path)"
          ABUND="$(inputs.abundance_file.path)"
          PREFIX="$(inputs.sample_id)"
          THREADS=$(runtime.cores)

          run_MaxBin.pl \
            -contig "$CONTIGS" \
            -abund "$ABUND" \
            -out "${PREFIX}_maxbin" \
            -thread $THREADS

          # Collect bins
          mkdir -p maxbin_bins
          for f in ${PREFIX}_maxbin.*.fasta; do
            if [ -f "$f" ]; then
              NUM=$(echo "$f" | sed "s/.*maxbin\.\([0-9]*\)\.fasta/\1/")
              cp "$f" "maxbin_bins/${PREFIX}_maxbin.${NUM}.fa"
            fi
          done

          # Create summary (MaxBin2 produces a .summary file)
          if [ -f "${PREFIX}_maxbin.summary" ]; then
            cp "${PREFIX}_maxbin.summary" "${PREFIX}_maxbin_summary.tsv"
          else
            echo "No summary produced" > "${PREFIX}_maxbin_summary.tsv"
          fi

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/maxbin2:2.2.7--hdbdd923_5"

baseCommand: [bash, run_maxbin2.sh]

inputs:
  contigs:
    type: File
    doc: "Assembly contigs FASTA"

  abundance_file:
    type: File
    doc: "Abundance/depth file (e.g., from MetaBAT2 jgi_summarize_bam_contig_depths)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

  run_maxbin2:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow"

outputs:
  bins:
    type: File[]
    outputBinding:
      glob: "maxbin_bins/*.fa"
    doc: "MaxBin2 genome bin FASTA files"

  summary:
    type: File
    outputBinding:
      glob: "*_maxbin_summary.tsv"
    doc: "MaxBin2 binning summary"
