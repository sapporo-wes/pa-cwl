#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "STARsolo - Single-cell RNA-seq alignment and quantification"
doc: |
  Align single-cell RNA-seq reads and generate gene-barcode count matrices
  using STARsolo. Supports 10x Chromium v2/v3, Drop-seq, and other
  barcode-based protocols.

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 32768
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_starsolo.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          THREADS=$(runtime.cores)
          CDNA_FQ="$(inputs.fastq_cdna.path)"
          BARCODE_FQ="$(inputs.fastq_barcode.path)"
          WHITELIST="$(inputs.barcode_whitelist.path)"
          GENOMEDIR="$(inputs.index_dir.path)"
          PREFIX="$(inputs.sample_id)."
          CB_LEN=$(inputs.cb_len)
          UMI_LEN=$(inputs.umi_len)
          STRAND="$(inputs.solo_strand)"
          SOLO_FEATURES="$(inputs.solo_features)"
          SOLO_CELL_FILTER="$(inputs.solo_cell_filter)"

          # Decompress gzipped files (STAR --readFilesCommand is
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

          CDNA_IN=\$(decompress "$CDNA_FQ")
          BC_IN=\$(decompress "$BARCODE_FQ")

          # Decompress whitelist if gzipped
          if [[ "$WHITELIST" == *.gz ]]; then
            WL_OUT="\$(basename "$WHITELIST" .gz)"
            gunzip -c "$WHITELIST" > "$WL_OUT"
            WHITELIST="$WL_OUT"
          fi

          UMI_START=\$((CB_LEN + 1))

          STAR \
            --runThreadN $THREADS \
            --genomeDir $GENOMEDIR \
            --readFilesIn $CDNA_IN $BC_IN \
            --outFileNamePrefix $PREFIX \
            --soloType CB_UMI_Simple \
            --soloCBwhitelist $WHITELIST \
            --soloCBstart 1 --soloCBlen $CB_LEN \
            --soloUMIstart $UMI_START --soloUMIlen $UMI_LEN \
            --soloFeatures $SOLO_FEATURES \
            --soloStrand $STRAND \
            --soloCellFilter $SOLO_CELL_FILTER \
            --outSAMtype BAM SortedByCoordinate \
            --outSAMattributes NH HI nM AS CR UR CB UB GX GN sS sQ sM \
            --outBAMsortingThreadN $THREADS

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/star:2.7.10b--h6b7c446_1"

baseCommand: [bash, run_starsolo.sh]

inputs:
  index_dir:
    type: Directory
    doc: "STAR genome index directory"

  fastq_cdna:
    type: File
    doc: "cDNA reads FASTQ (R2 for 10x Chromium)"

  fastq_barcode:
    type: File
    doc: "Barcode + UMI reads FASTQ (R1 for 10x Chromium)"

  barcode_whitelist:
    type: File
    doc: "Cell barcode whitelist (e.g., 3M-february-2018.txt for 10x v3)"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

  cb_len:
    type: int
    default: 16
    doc: "Cell barcode length (16 for 10x v2/v3, 12 for Drop-seq)"

  umi_len:
    type: int
    default: 12
    doc: "UMI length (12 for 10x v3, 10 for v2, 8 for Drop-seq)"

  solo_strand:
    type: string?
    default: "Forward"
    doc: "Read strand (Forward for 10x 3', Reverse for 10x 5')"

  solo_features:
    type: string?
    default: "Gene GeneFull"
    doc: "STARsolo feature types (Gene, GeneFull, SJ, Velocyto)"

  solo_cell_filter:
    type: string?
    default: "CellRanger2_3 3000 0.99 10"
    doc: "Cell filtering method (CellRanger2_3, EmptyDrops_CR, TopCells N, None)"

outputs:
  aligned_bam:
    type: File
    outputBinding:
      glob: "*.Aligned.sortedByCoord.out.bam"

  solo_out_dir:
    type: Directory
    outputBinding:
      glob: "*.Solo.out"
    doc: "STARsolo output directory (Gene/filtered, Gene/raw, etc.)"

  log_final:
    type: File
    outputBinding:
      glob: "*.Log.final.out"

  log:
    type: File
    outputBinding:
      glob: "*.Log.out"

  barcodes_stats:
    type: File
    outputBinding:
      glob: "*.Solo.out/Barcodes.stats"
