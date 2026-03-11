#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "STAR - Spliced-aware RNA-seq aligner"
doc: "Align RNA-seq reads to a reference genome using STAR"

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 32768
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_star.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          THREADS="$1"
          FWD="$2"
          REV="\${3:-}"
          PREFIX="$4"
          GENOMEDIR="$5"
          QUANTMODE="\${6:-}"
          SAMPLE_ID="\${7:-sample}"

          # Decompress gzipped FASTQ files (STAR --readFilesCommand is
          # unreliable on some platforms, e.g. macOS ARM64 conda builds)
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

          STAR_CMD="STAR --runThreadN $THREADS"
          STAR_CMD="$STAR_CMD --readFilesIn $READ_FILES"
          STAR_CMD="$STAR_CMD --outFileNamePrefix $PREFIX"
          STAR_CMD="$STAR_CMD --outSAMtype BAM SortedByCoordinate"
          STAR_CMD="$STAR_CMD --outSAMunmapped Within"
          STAR_CMD="$STAR_CMD --outSAMattributes NH HI AS NM MD"
          STAR_CMD="$STAR_CMD --outBAMsortingThreadN $THREADS"
          STAR_CMD="$STAR_CMD --genomeDir $GENOMEDIR"
          STAR_CMD="$STAR_CMD --outSAMattrRGline ID:$SAMPLE_ID SM:$SAMPLE_ID PL:ILLUMINA LB:$SAMPLE_ID"

          if [ -n "$QUANTMODE" ]; then
            STAR_CMD="$STAR_CMD --quantMode $QUANTMODE"
          fi

          eval $STAR_CMD

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/star:2.7.10b--h6b7c446_1"

baseCommand: [bash, run_star.sh]

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

  quantmode:
    type: string?
    default: "TranscriptomeSAM"
    doc: "Quantification mode (TranscriptomeSAM for Salmon/RSEM)"

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
    valueFrom: |
      ${
        if (inputs.quantmode) {
          return inputs.quantmode;
        }
        return "";
      }
  - position: 7
    valueFrom: $(inputs.sample_id)

outputs:
  aligned_bam:
    type: File
    outputBinding:
      glob: "*.Aligned.sortedByCoord.out.bam"

  transcriptome_bam:
    type: File?
    outputBinding:
      glob: "*.Aligned.toTranscriptome.out.bam"

  log_final:
    type: File
    outputBinding:
      glob: "*.Log.final.out"

  log:
    type: File
    outputBinding:
      glob: "*.Log.out"

  splice_junctions:
    type: File
    outputBinding:
      glob: "*.SJ.out.tab"
