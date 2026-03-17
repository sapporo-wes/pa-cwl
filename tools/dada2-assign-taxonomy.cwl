#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "DADA2 assignTaxonomy - Taxonomic classification of ASVs"
doc: |
  Assign taxonomy to amplicon sequence variants using DADA2's
  naive Bayesian classifier with a reference database (e.g., SILVA, UNITE).

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: assign_taxonomy.R
        entry: |
          #!/usr/bin/env Rscript
          args <- commandArgs(trailingOnly = TRUE)
          seqtab_rds <- args[1]
          ref_db <- args[2]
          threads <- as.integer(args[3])
          min_boot <- as.integer(args[4])

          library(dada2)

          # Load sequence table
          seqtab <- readRDS(seqtab_rds)

          # Assign taxonomy
          cat("Assigning taxonomy...\n")
          taxa <- assignTaxonomy(
            seqtab, ref_db,
            multithread = threads,
            minBoot = min_boot,
            tryRC = TRUE
          )

          # Create readable output
          asv_ids <- paste0("ASV", seq_len(ncol(seqtab)))
          taxa_df <- as.data.frame(taxa)
          taxa_df$ASV_ID <- asv_ids
          taxa_df$sequence <- colnames(seqtab)

          write.csv(taxa_df, "taxonomy.csv", row.names = FALSE)
          saveRDS(taxa, "taxonomy.rds")

          cat("Assigned taxonomy to", nrow(taxa_df), "ASVs\n")
          cat("Done.\n")

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bioconductor-dada2:1.34.0--r44he5774e6_2"

baseCommand: [Rscript, assign_taxonomy.R]

inputs:
  seqtab_rds:
    type: File
    doc: "DADA2 sequence table RDS from denoise step"

  reference_db:
    type: File
    doc: "Taxonomy reference database (e.g., SILVA, UNITE FASTA)"

  min_boot:
    type: int?
    default: 50
    doc: "Minimum bootstrap confidence for taxonomy assignment"

arguments:
  - position: 1
    valueFrom: $(inputs.seqtab_rds.path)
  - position: 2
    valueFrom: $(inputs.reference_db.path)
  - position: 3
    valueFrom: $(runtime.cores)
  - position: 4
    valueFrom: $(inputs.min_boot)

outputs:
  taxonomy_csv:
    type: File
    outputBinding:
      glob: "taxonomy.csv"
    doc: "Taxonomy assignments in CSV format"

  taxonomy_rds:
    type: File
    outputBinding:
      glob: "taxonomy.rds"
    doc: "Taxonomy RDS for downstream R analysis"
