#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "MetaBAT2 - Metagenome binning"
doc: |
  Adaptive binning of metagenome contigs using coverage depth
  and tetranucleotide frequency. Includes depth calculation step.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_metabat2.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          CONTIGS="$(inputs.contigs.path)"
          MIN_CONTIG=$(inputs.min_contig_len)
          THREADS=$(runtime.cores)

          # Build BAM list for depth calculation
          BAM_FILES="$(inputs.bams.map(function(f){ return f.path; }).join(' '))"

          # Calculate contig depths
          jgi_summarize_bam_contig_depths \
            --outputDepth depth.txt \
            $BAM_FILES

          # Run MetaBAT2
          mkdir -p bins
          metabat2 \
            -i "$CONTIGS" \
            -a depth.txt \
            -o bins/bin \
            -m $MIN_CONTIG \
            -t $THREADS

          # Create bin summary
          echo -e "bin\tcontigs\ttotal_length" > bin_summary.tsv
          for f in bins/bin.*.fa; do
            if [ -f "$f" ]; then
              BIN=\$(basename "$f" .fa)
              NCONTIGS=\$(grep -c ">" "$f")
              TOTAL_LEN=\$(grep -v ">" "$f" | tr -d '\n' | wc -c | tr -d ' ')
              echo -e "\${BIN}\t\${NCONTIGS}\t\${TOTAL_LEN}" >> bin_summary.tsv
            fi
          done

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/metabat2:2.17--h6f16272_1"

baseCommand: [bash, run_metabat2.sh]

inputs:
  contigs:
    type: File
    doc: "Assembly contigs FASTA"

  bams:
    type: File[]
    secondaryFiles:
      - .bai
    doc: "Sorted BAM files (with .bai index) for depth calculation"

  min_contig_len:
    type: int?
    default: 1500
    doc: "Minimum contig length for binning"

outputs:
  bins:
    type: File[]
    outputBinding:
      glob: "bins/bin.*.fa"
    doc: "Genome bin FASTA files"

  depth_file:
    type: File
    outputBinding:
      glob: "depth.txt"
    doc: "Contig depth profile"

  bin_summary:
    type: File
    outputBinding:
      glob: "bin_summary.tsv"
    doc: "Bin summary statistics"
