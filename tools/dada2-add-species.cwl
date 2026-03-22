#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "DADA2 addSpecies - Species-level taxonomic assignment"
doc: |
  Add species-level taxonomy to ASVs using exact matching against a
  species reference database via DADA2's addSpecies() function.
  This refines genus-level assignments from assignTaxonomy with
  exact-match species-level identification.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: add_species.R
        entry: |
          #!/usr/bin/env Rscript
          args <- commandArgs(trailingOnly = TRUE)
          taxonomy_rds <- args[1]
          seqtab_rds <- args[2]
          species_db <- args[3]
          allow_multiple <- as.logical(args[4])

          library(dada2)

          # Load taxonomy from assignTaxonomy step
          taxa <- readRDS(taxonomy_rds)
          seqtab <- readRDS(seqtab_rds)

          # Add species-level assignments via exact matching
          cat("Adding species-level assignments...\n")
          taxa_species <- addSpecies(
            taxa, species_db,
            allowMultiple = allow_multiple
          )

          cat("Species assigned to", sum(!is.na(taxa_species[, "Species"])),
              "of", nrow(taxa_species), "ASVs\n")

          # Create readable output
          asv_ids <- paste0("ASV", seq_len(ncol(seqtab)))
          taxa_df <- as.data.frame(taxa_species)
          taxa_df$ASV_ID <- asv_ids
          taxa_df$sequence <- colnames(seqtab)

          write.csv(taxa_df, "taxonomy_species.csv", row.names = FALSE)
          saveRDS(taxa_species, "taxonomy_species.rds")

          cat("Done.\n")

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bioconductor-dada2:1.34.0--r44he5774e6_2"

baseCommand: [Rscript, add_species.R]

inputs:
  taxonomy_rds:
    type: File
    doc: "Taxonomy RDS from assignTaxonomy step"

  seqtab_rds:
    type: File
    doc: "DADA2 sequence table RDS from denoise step"

  species_db:
    type: File
    doc: "Species reference FASTA (e.g., silva_species_assignment_v138.1.fa.gz)"

  allow_multiple:
    type: boolean?
    default: false
    doc: "Allow multiple species assignments per ASV"

arguments:
  - position: 1
    valueFrom: $(inputs.taxonomy_rds.path)
  - position: 2
    valueFrom: $(inputs.seqtab_rds.path)
  - position: 3
    valueFrom: $(inputs.species_db.path)
  - position: 4
    valueFrom: '$(inputs.allow_multiple ? "TRUE" : "FALSE")'

outputs:
  taxonomy_species_csv:
    type: File
    outputBinding:
      glob: "taxonomy_species.csv"
    doc: "Taxonomy assignments with species column in CSV format"

  taxonomy_species_rds:
    type: File
    outputBinding:
      glob: "taxonomy_species.rds"
    doc: "Taxonomy with species RDS for downstream R analysis"
