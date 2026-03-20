#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Hi-C two-step Bowtie2 mapping"
doc: |
  Two-step mapping strategy for Hi-C data. First aligns reads end-to-end,
  then trims unmapped reads at ligation junctions and re-aligns.
  Produces a paired-end BAM file with chimeric reads properly handled.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_hic_mapping.sh
        entry: |
          #!/bin/bash
          set -euo pipefail
          THREADS=$(runtime.cores)
          PREFIX="$(inputs.sample_id)"
          FQ1="$(inputs.fastq_fwd.path)"
          FQ2="$(inputs.fastq_rev.path)"
          LIGATION="$(inputs.ligation_site)"

          # Link index files to working directory
          $(inputs.index_files.map(function(f){ return 'ln -s "' + f.path + '" .'; }).join('\n          '))

          # Step 1: Global end-to-end alignment
          bowtie2 --end-to-end --very-sensitive \
            -x $(inputs.index_base) \
            --threads $THREADS \
            --reorder \
            --rg-id \${PREFIX} \
            --rg SM:\${PREFIX} \
            --rg PL:ILLUMINA \
            --rg LB:\${PREFIX} \
            -U "\${FQ1}" 2> \${PREFIX}_R1_bowtie2.log \
          | samtools view -@ $THREADS -bS - > \${PREFIX}_R1.bam

          bowtie2 --end-to-end --very-sensitive \
            -x $(inputs.index_base) \
            --threads $THREADS \
            --reorder \
            --rg-id \${PREFIX} \
            --rg SM:\${PREFIX} \
            --rg PL:ILLUMINA \
            --rg LB:\${PREFIX} \
            -U "\${FQ2}" 2> \${PREFIX}_R2_bowtie2.log \
          | samtools view -@ $THREADS -bS - > \${PREFIX}_R2.bam

          # Step 2: Extract unmapped reads, trim at ligation site, re-align
          # Get unmapped reads from R1
          samtools view -@ $THREADS -f 4 \${PREFIX}_R1.bam \
          | awk '{OFS="\t"; print "@"$1"\n"$10"\n+\n"$11}' > \${PREFIX}_R1_unmapped.fastq

          # Trim at ligation site
          if [ -s \${PREFIX}_R1_unmapped.fastq ]; then
            awk -v site="\${LIGATION}" 'BEGIN{FS="\t"; OFS="\n"} {
              if(NR%4==2) {
                idx = index($0, site)
                if(idx > 0) $0 = substr($0, 1, idx-1)
              }
              if(NR%4==0) {
                idx_prev = idx
                if(idx_prev > 0) $0 = substr($0, 1, idx_prev-1)
              }
              print
            }' \${PREFIX}_R1_unmapped.fastq > \${PREFIX}_R1_trimmed.fastq

            bowtie2 --end-to-end --very-sensitive \
              -x $(inputs.index_base) \
              --threads $THREADS \
              --reorder \
              -U \${PREFIX}_R1_trimmed.fastq 2>> \${PREFIX}_R1_bowtie2.log \
            | samtools view -@ $THREADS -bS - > \${PREFIX}_R1_rescue.bam

            # Merge first-pass mapped + rescue mapped
            samtools view -@ $THREADS -F 4 \${PREFIX}_R1.bam -b > \${PREFIX}_R1_mapped.bam
            samtools merge -@ $THREADS \${PREFIX}_R1_final.bam \${PREFIX}_R1_mapped.bam \${PREFIX}_R1_rescue.bam
          else
            samtools view -@ $THREADS -F 4 \${PREFIX}_R1.bam -b > \${PREFIX}_R1_final.bam
          fi

          # Repeat for R2
          samtools view -@ $THREADS -f 4 \${PREFIX}_R2.bam \
          | awk '{OFS="\t"; print "@"$1"\n"$10"\n+\n"$11}' > \${PREFIX}_R2_unmapped.fastq

          if [ -s \${PREFIX}_R2_unmapped.fastq ]; then
            awk -v site="\${LIGATION}" 'BEGIN{FS="\t"; OFS="\n"} {
              if(NR%4==2) {
                idx = index($0, site)
                if(idx > 0) $0 = substr($0, 1, idx-1)
              }
              if(NR%4==0) {
                idx_prev = idx
                if(idx_prev > 0) $0 = substr($0, 1, idx_prev-1)
              }
              print
            }' \${PREFIX}_R2_unmapped.fastq > \${PREFIX}_R2_trimmed.fastq

            bowtie2 --end-to-end --very-sensitive \
              -x $(inputs.index_base) \
              --threads $THREADS \
              --reorder \
              -U \${PREFIX}_R2_trimmed.fastq 2>> \${PREFIX}_R2_bowtie2.log \
            | samtools view -@ $THREADS -bS - > \${PREFIX}_R2_rescue.bam

            samtools view -@ $THREADS -F 4 \${PREFIX}_R2.bam -b > \${PREFIX}_R2_mapped.bam
            samtools merge -@ $THREADS \${PREFIX}_R2_final.bam \${PREFIX}_R2_mapped.bam \${PREFIX}_R2_rescue.bam
          else
            samtools view -@ $THREADS -F 4 \${PREFIX}_R2.bam -b > \${PREFIX}_R2_final.bam
          fi

          # Add paired-end flags for pairtools compatibility
          # R1: add 0x41 (paired + first-in-pair = 65)
          samtools view -h \${PREFIX}_R1_final.bam \
          | awk 'BEGIN{OFS="\t"} /^@/{print; next} {$2=$2+65; print}' \
          | samtools view -@ $THREADS -bS - > \${PREFIX}_R1_flagged.bam

          # R2: add 0x81 (paired + second-in-pair = 129)
          samtools view -h \${PREFIX}_R2_final.bam \
          | awk 'BEGIN{OFS="\t"} /^@/{print; next} {$2=$2+129; print}' \
          | samtools view -@ $THREADS -bS - > \${PREFIX}_R2_flagged.bam

          # Sort both BAMs by read name for pairtools
          samtools sort -@ $THREADS -n -o \${PREFIX}_R1_sorted.bam \${PREFIX}_R1_flagged.bam
          samtools sort -@ $THREADS -n -o \${PREFIX}_R2_sorted.bam \${PREFIX}_R2_flagged.bam

          # Combine R1 and R2 into a single paired BAM (name-sorted)
          samtools merge -@ $THREADS -n \${PREFIX}.bam \${PREFIX}_R1_sorted.bam \${PREFIX}_R2_sorted.bam
          samtools sort -@ $THREADS -n -o \${PREFIX}_namesorted.bam \${PREFIX}.bam

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/mulled-v2-ac74a7f02cebcfcc07d8e8d1d750af9c83b4d45a:1744f68fe955578c63054b55309e05b41c37a80d-0"

baseCommand: [bash, run_hic_mapping.sh]

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

  ligation_site:
    type: string
    doc: "Ligation site sequence (e.g. AAGCTAGCTT for HindIII, GATCGATC for MboI/DpnII)"

outputs:
  namesorted_bam:
    type: File
    outputBinding:
      glob: "*_namesorted.bam"
    doc: "Name-sorted BAM with chimeric reads rescued"

  log_r1:
    type: File
    outputBinding:
      glob: "*_R1_bowtie2.log"
    doc: "Bowtie2 alignment log (R1)"

  log_r2:
    type: File
    outputBinding:
      glob: "*_R2_bowtie2.log"
    doc: "Bowtie2 alignment log (R2)"
