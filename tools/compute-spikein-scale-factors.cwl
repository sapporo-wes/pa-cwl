#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Compute spike-in scale factors"
doc: |
  Read spike-in alignment count files and compute normalization scale
  factors. The sample with the fewest spike-in reads is used as the
  reference (scale factor = 1.0). Other samples are scaled down
  proportionally (minCount / sampleCount).

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 512
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: compute_scale_factors.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          # Read all spike-in count files and extract counts
          declare -a COUNTS
          declare -a SAMPLES
          IDX=0
          for f in "$@"; do
            SAMPLE=$(tail -1 "$f" | cut -f1)
            COUNT=$(tail -1 "$f" | cut -f2)
            SAMPLES[$IDX]="$SAMPLE"
            COUNTS[$IDX]="$COUNT"
            IDX=$((IDX + 1))
          done

          # Find minimum count
          MIN=${COUNTS[0]}
          for c in "${COUNTS[@]}"; do
            if [ "$c" -lt "$MIN" ] && [ "$c" -gt 0 ]; then
              MIN=$c
            fi
          done

          # Compute and output scale factors (one per line)
          echo -e "sample_id\tspikein_count\tscale_factor" > spikein_scale_factors.tsv
          for i in $(seq 0 $((IDX - 1))); do
            if [ "${COUNTS[$i]}" -gt 0 ]; then
              FACTOR=$(echo "scale=10; $MIN / ${COUNTS[$i]}" | bc -l)
            else
              FACTOR="1.0"
            fi
            echo -e "${SAMPLES[$i]}\t${COUNTS[$i]}\t${FACTOR}" >> spikein_scale_factors.tsv
            echo "$FACTOR"
          done > scale_factors.txt

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/mulled-v2-ac74a7f02cebcfcc07d8e8d1d750af9c83b4d45a:1744f68fe955578c63054b55309e05b41c37a80d-0"

baseCommand: [bash, compute_scale_factors.sh]

inputs:
  spikein_stats:
    type: File[]
    inputBinding:
      position: 1
    doc: "Spike-in alignment stats files (TSV with sample_id and read count)"

outputs:
  scale_factors_table:
    type: File
    outputBinding:
      glob: spikein_scale_factors.tsv
    doc: "Table of spike-in counts and scale factors per sample"

  scale_factors_list:
    type: File
    outputBinding:
      glob: scale_factors.txt
    doc: "Scale factors as plain text, one per line"
