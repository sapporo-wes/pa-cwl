#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "DropletUtils emptyDrops - Empty droplet detection"
doc: |
  Identify empty droplets in single-cell RNA-seq data using the emptyDrops()
  method from the DropletUtils Bioconductor package.

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_emptydrops.R
        entry: |
          library(DropletUtils)
          library(Matrix)

          args <- commandArgs(trailingOnly = TRUE)
          matrix_dir <- args[1]
          fdr_threshold <- as.numeric(args[2])
          sample_id <- args[3]

          # Read 10x-format MEX matrix (barcodes.tsv, features.tsv, matrix.mtx)
          sce <- read10xCounts(matrix_dir)

          # Run emptyDrops
          set.seed(100)
          e_out <- emptyDrops(counts(sce))

          # Identify non-empty droplets
          is_cell <- e_out$FDR <= fdr_threshold & !is.na(e_out$FDR)

          # Write filtered barcodes
          filtered_barcodes <- colData(sce)$Barcode[is_cell]
          writeLines(filtered_barcodes,
                     paste0(sample_id, "_filtered_barcodes.txt"))

          # Write summary statistics
          summary_df <- data.frame(
            sample_id = sample_id,
            total_barcodes = ncol(sce),
            non_empty_droplets = sum(is_cell),
            empty_droplets = sum(!is_cell),
            fdr_threshold = fdr_threshold,
            median_total_counts_cells = median(colSums(counts(sce)[, is_cell])),
            median_total_counts_empty = ifelse(
              sum(!is_cell) > 0,
              median(colSums(counts(sce)[, !is_cell])),
              NA
            )
          )
          write.csv(summary_df,
                    paste0(sample_id, "_emptydrops_summary.csv"),
                    row.names = FALSE)

          cat("emptyDrops complete for sample:", sample_id, "\n")
          cat("  Total barcodes:", summary_df$total_barcodes, "\n")
          cat("  Non-empty droplets:", summary_df$non_empty_droplets, "\n")
          cat("  Empty droplets:", summary_df$empty_droplets, "\n")

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bioconductor-dropletutils:1.22.0--r43hf17093f_0"

baseCommand: [Rscript, run_emptydrops.R]

inputs:
  raw_matrix_dir:
    type: Directory
    inputBinding:
      position: 1
    doc: "Raw count matrix directory in MEX format (barcodes.tsv, features.tsv, matrix.mtx)"

  fdr_threshold:
    type: float
    default: 0.01
    inputBinding:
      position: 2
    doc: "FDR threshold for emptyDrops (default 0.01)"

  sample_id:
    type: string
    inputBinding:
      position: 3
    doc: "Sample identifier for output naming"

  run_empty_drops:
    type: boolean?
    doc: "Passthrough for conditional evaluation in parent workflow (not used by tool)"

  quantifier:
    type: string?
    doc: "Passthrough for conditional evaluation in parent workflow (not used by tool)"

outputs:
  filtered_barcodes:
    type: File
    outputBinding:
      glob: "*_filtered_barcodes.txt"
    doc: "List of barcodes identified as non-empty droplets"

  summary_stats:
    type: File
    outputBinding:
      glob: "*_emptydrops_summary.csv"
    doc: "Summary statistics of empty droplet detection"
