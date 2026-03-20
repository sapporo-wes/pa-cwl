#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Bowtie2 - Short read alignment"
doc: "Align short reads to a reference using Bowtie2."

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_bowtie2.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          THREADS=$(runtime.cores)
          PREFIX="$(inputs.sample_id)"

          # Link index files to working directory
          $(inputs.index_files.map(function(f){ return 'ln -s "' + f.path + '" .'; }).join('\n          '))

          bowtie2 \
            -x $(inputs.index_base) \
            -1 "$(inputs.fastq_fwd.path)" \
            -2 "$(inputs.fastq_rev.path)" \
            --threads $THREADS \
            --very-sensitive \
            --rg-id \${PREFIX} \
            --rg SM:\${PREFIX} \
            --rg PL:ILLUMINA \
            --rg LB:\${PREFIX} \
            2> \${PREFIX}_bowtie2.log \
          | samtools sort -@ $THREADS -o \${PREFIX}.sorted.bam -

          samtools index \${PREFIX}.sorted.bam

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/mulled-v2-ac74a7f02cebcfcc07d8e8d1d750af9c83b4d45a:1744f68fe955578c63054b55309e05b41c37a80d-0"

baseCommand: [bash, run_bowtie2.sh]

inputs:
  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File
    doc: "Reverse read FASTQ"

  index_files:
    type: File[]
    doc: "Bowtie2 index files"

  index_base:
    type: string
    doc: "Bowtie2 index base name"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

outputs:
  sorted_bam:
    type: File
    secondaryFiles:
      - .bai
    outputBinding:
      glob: "*.sorted.bam"
    doc: "Coordinate-sorted BAM with index"

  log:
    type: File
    outputBinding:
      glob: "*_bowtie2.log"
    doc: "Bowtie2 alignment log"
