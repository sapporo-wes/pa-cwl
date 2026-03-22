#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Bowtie2 spike-in alignment - Count E. coli spike-in reads"
doc: |
  Align reads to a spike-in reference genome (e.g., E. coli) and count
  the number of aligned reads. Used for CUT&RUN spike-in calibration
  to compute normalization scale factors.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_spikein_align.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          THREADS=$(runtime.cores)
          PREFIX="$(inputs.sample_id)"

          # Link index files to working directory
          $(inputs.spikein_index_files.map(function(f){ return 'ln -s "' + f.path + '" .'; }).join('\n          '))

          # Align to spike-in genome and count aligned reads
          bowtie2 \
            -x $(inputs.spikein_index_base) \
            -1 "$(inputs.fastq_fwd.path)" \
            -2 "$(inputs.fastq_rev.path)" \
            --threads $THREADS \
            --very-sensitive \
            --no-mixed \
            --no-discordant \
            --no-unal \
            2> \${PREFIX}_spikein_bowtie2.log \
          | samtools view -@ $THREADS -bS -F 4 - \
          | samtools sort -@ $THREADS -o \${PREFIX}.spikein.sorted.bam -

          # Count aligned read pairs
          SPIKEIN_COUNT=$(samtools view -c -F 260 \${PREFIX}.spikein.sorted.bam)

          # Write stats file
          echo -e "sample_id\tspikein_read_count" > \${PREFIX}_spikein_stats.tsv
          echo -e "\${PREFIX}\t\${SPIKEIN_COUNT}" >> \${PREFIX}_spikein_stats.tsv

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/mulled-v2-ac74a7f02cebcfcc07d8e8d1d750af9c83b4d45a:1744f68fe955578c63054b55309e05b41c37a80d-0"

baseCommand: [bash, run_spikein_align.sh]

inputs:
  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File
    doc: "Reverse read FASTQ"

  spikein_index_files:
    type: File[]
    doc: "Bowtie2 index files for spike-in genome (e.g., E. coli)"

  spikein_index_base:
    type: string
    doc: "Bowtie2 index base name for spike-in genome"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

outputs:
  spikein_stats:
    type: File
    outputBinding:
      glob: "*_spikein_stats.tsv"
    doc: "Spike-in alignment count (TSV with sample_id and read count)"

  spikein_log:
    type: File
    outputBinding:
      glob: "*_spikein_bowtie2.log"
    doc: "Bowtie2 spike-in alignment log"
