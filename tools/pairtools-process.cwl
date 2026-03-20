#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "pairtools - Parse, sort, dedup Hi-C pairs"
doc: |
  Process Hi-C BAM to valid pairs: parse alignments, sort, deduplicate,
  and output valid pairs in 4DN .pairs format.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_pairtools.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          PREFIX="$(inputs.sample_id)"
          CHROMSIZES="$(inputs.chromsizes.path)"
          BAM="$(inputs.namesorted_bam.path)"
          THREADS=$(runtime.cores)
          MIN_MAPQ=$(inputs.min_mapq)

          # Parse: extract Hi-C pairs from name-sorted BAM
          pairtools parse \
            --min-mapq \${MIN_MAPQ} \
            --walks-policy 5unique \
            --max-inter-align-gap 30 \
            --nproc-in $THREADS \
            --nproc-out $THREADS \
            --chroms-path "\${CHROMSIZES}" \
            "\${BAM}" \
          | pairtools sort \
            --nproc $THREADS \
            --tmpdir . \
          | pairtools dedup \
            --nproc-in $THREADS \
            --nproc-out $THREADS \
            --mark-dups \
            --output-stats \${PREFIX}_pairtools_stats.txt \
            --output \${PREFIX}.valid.pairs.gz

          # Index the pairs file
          pairix \${PREFIX}.valid.pairs.gz 2>/dev/null || true

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/pairtools:1.1.3--py310h4e61836_0"

baseCommand: [bash, run_pairtools.sh]

inputs:
  namesorted_bam:
    type: File
    doc: "Name-sorted BAM from Hi-C mapping"

  chromsizes:
    type: File
    doc: "Chromosome sizes file (tab-separated: chrom<tab>size)"

  sample_id:
    type: string
    doc: "Sample identifier"

  min_mapq:
    type: int?
    default: 10
    doc: "Minimum mapping quality for valid pairs"

outputs:
  valid_pairs:
    type: File
    outputBinding:
      glob: "*.valid.pairs.gz"
    doc: "Deduplicated valid pairs (4DN .pairs.gz format)"

  stats:
    type: File
    outputBinding:
      glob: "*_pairtools_stats.txt"
    doc: "Pairtools dedup statistics"
