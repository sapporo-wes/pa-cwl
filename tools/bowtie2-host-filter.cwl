#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Bowtie2 host read filter"
doc: |
  Filter out host reads by aligning against a host genome index with Bowtie2.
  Keeps only read pairs where both mates are unaligned (--un-conc-gz).

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_host_filter.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          THREADS=$(runtime.cores)
          PREFIX="$(inputs.sample_id)"

          # Link index files to working directory
          $(inputs.host_index_files.map(function(f){ return 'ln -s "' + f.path + '" .'; }).join('\n          '))

          bowtie2 \
            -x $(inputs.host_index_base) \
            -1 "$(inputs.fastq_fwd.path)" \
            -2 "$(inputs.fastq_rev.path)" \
            --threads $THREADS \
            --very-sensitive \
            --un-conc-gz \${PREFIX}_filtered_R%.fastq.gz \
            2> \${PREFIX}_host_filter.log \
          | samtools view -bS - > /dev/null

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/mulled-v2-ac74a7f02cebcfcc07d8e8d1d750af9c83b4d45a:1744f68fe955578c63054b55309e05b41c37a80d-0"

baseCommand: [bash, run_host_filter.sh]

inputs:
  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File
    doc: "Reverse read FASTQ"

  host_index_files:
    type: File[]
    doc: "Bowtie2 index files for the host genome"

  host_index_base:
    type: string
    doc: "Bowtie2 index base name for the host genome"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

outputs:
  filtered_fwd:
    type: File
    outputBinding:
      glob: "*_filtered_R1.fastq.gz"
    doc: "Forward reads with host reads removed"

  filtered_rev:
    type: File
    outputBinding:
      glob: "*_filtered_R2.fastq.gz"
    doc: "Reverse reads with host reads removed"

  log:
    type: File
    outputBinding:
      glob: "*_host_filter.log"
    doc: "Host filtering alignment log"
