#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "STAR (fusion mode) - RNA-seq alignment with chimeric detection"
doc: |
  Align RNA-seq reads with STAR using chimeric detection parameters
  required for downstream fusion calling with Arriba.
  Outputs unsorted BAM for Arriba and sorted BAM for other analyses.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 32768
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_star_fusion.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          THREADS="$1"
          FWD="$2"
          REV="\${3:-}"
          PREFIX="$4"
          GENOMEDIR="$5"
          SAMPLE_ID="\${6:-sample}"

          # Decompress gzipped FASTQ files
          decompress() {
            local f="$1"
            if [[ "$f" == *.gz ]]; then
              local out
              out="\$(basename "$f" .gz)"
              gunzip -c "$f" > "$out"
              echo "$out"
            else
              echo "$f"
            fi
          }

          FWD_IN=\$(decompress "$FWD")
          READ_FILES="$FWD_IN"
          if [ -n "$REV" ]; then
            REV_IN=\$(decompress "$REV")
            READ_FILES="$FWD_IN $REV_IN"
          fi

          STAR \
            --runThreadN $THREADS \
            --readFilesIn $READ_FILES \
            --outFileNamePrefix $PREFIX \
            --genomeDir $GENOMEDIR \
            --outSAMtype BAM SortedByCoordinate \
            --outSAMunmapped Within \
            --outSAMattributes NH HI AS NM MD \
            --outBAMsortingThreadN $THREADS \
            --outSAMattrRGline ID:$SAMPLE_ID SM:$SAMPLE_ID PL:ILLUMINA LB:$SAMPLE_ID \
            --outFilterMultimapNmax 50 \
            --peOverlapNbasesMin 10 \
            --alignSplicedMateMapLminOverLmate 0.5 \
            --alignSJstitchMismatchNmax 5 -1 5 5 \
            --chimSegmentMin 10 \
            --chimOutType WithinBAM HardClip \
            --chimJunctionOverhangMin 10 \
            --chimScoreDropMax 30 \
            --chimScoreJunctionNonGTAG 0 \
            --chimScoreSeparation 1 \
            --chimSegmentReadGapMax 3 \
            --chimMultimapNmax 50

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/star:2.7.10b--h6b7c446_1"

baseCommand: [bash, run_star_fusion.sh]

inputs:
  index_dir:
    type: Directory
    doc: "STAR genome index directory"

  fastq_fwd:
    type: File
    doc: "Forward read FASTQ"

  fastq_rev:
    type: File?
    doc: "Reverse read FASTQ"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - position: 1
    valueFrom: $(runtime.cores)
  - position: 2
    valueFrom: $(inputs.fastq_fwd.path)
  - position: 3
    valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return inputs.fastq_rev.path;
        }
        return "";
      }
  - position: 4
    valueFrom: $(inputs.sample_id).
  - position: 5
    valueFrom: $(inputs.index_dir.path)
  - position: 6
    valueFrom: $(inputs.sample_id)

outputs:
  aligned_bam:
    type: File
    outputBinding:
      glob: "*.Aligned.sortedByCoord.out.bam"
    doc: "Coordinate-sorted BAM with chimeric reads"

  log_final:
    type: File
    outputBinding:
      glob: "*.Log.final.out"

  log:
    type: File
    outputBinding:
      glob: "*.Log.out"

  chimeric_junctions:
    type: File?
    outputBinding:
      glob: "*.Chimeric.out.junction"
    doc: "Chimeric junction file (if produced)"

  splice_junctions:
    type: File
    outputBinding:
      glob: "*.SJ.out.tab"
