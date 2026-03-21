#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "DADA2 denoise - Amplicon sequence variant inference"
doc: |
  Run the full DADA2 pipeline: quality filtering, error learning,
  denoising, pair merging (PE only), chimera removal. Outputs an ASV
  count table and representative sequences FASTA.
  Supports both paired-end and single-end amplicon data.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: dada2_denoise.R
        entry: |
          #!/usr/bin/env Rscript
          args <- commandArgs(trailingOnly = TRUE)
          fwd_files <- strsplit(args[1], ",")[[1]]
          rev_arg <- args[2]
          paired <- nchar(rev_arg) > 0
          if (paired) {
            rev_files <- strsplit(rev_arg, ",")[[1]]
          }
          sample_ids <- strsplit(args[3], ",")[[1]]
          trunc_len_f <- as.integer(args[4])
          trunc_len_r <- as.integer(args[5])
          min_len <- as.integer(args[6])
          threads <- as.integer(args[7])

          library(dada2)

          # Filter and trim
          filt_fwd <- file.path("filtered", paste0(sample_ids, "_F_filt.fastq.gz"))
          dir.create("filtered", showWarnings = FALSE)

          if (paired) {
            filt_rev <- file.path("filtered", paste0(sample_ids, "_R_filt.fastq.gz"))
            filt_out <- filterAndTrim(
              fwd_files, filt_fwd,
              rev_files, filt_rev,
              truncLen = c(trunc_len_f, trunc_len_r),
              minLen = min_len,
              maxN = 0, maxEE = c(2, 2), truncQ = 2,
              rm.phix = TRUE, compress = TRUE, multithread = threads
            )
          } else {
            trunc_vec <- if (trunc_len_f > 0) trunc_len_f else 0
            filt_out <- filterAndTrim(
              fwd_files, filt_fwd,
              truncLen = trunc_vec,
              minLen = min_len,
              maxN = 0, maxEE = 2, truncQ = 2,
              rm.phix = TRUE, compress = TRUE, multithread = threads
            )
          }

          # Check which samples passed filtering
          keep <- filt_out[, "reads.out"] > 0
          filt_fwd <- filt_fwd[keep]
          if (paired) filt_rev <- filt_rev[keep]
          sample_ids <- sample_ids[keep]

          if (length(filt_fwd) == 0) {
            stop("No reads passed filtering")
          }

          # Learn error rates
          cat("Learning error rates (forward)...\n")
          errF <- learnErrors(filt_fwd, multithread = threads)

          # Denoise forward
          cat("Denoising forward reads...\n")
          dadaFs <- dada(filt_fwd, err = errF, multithread = threads)

          if (paired) {
            cat("Learning error rates (reverse)...\n")
            errR <- learnErrors(filt_rev, multithread = threads)
            cat("Denoising reverse reads...\n")
            dadaRs <- dada(filt_rev, err = errR, multithread = threads)

            # Merge pairs
            cat("Merging pairs...\n")
            merged <- mergePairs(dadaFs, filt_fwd, dadaRs, filt_rev)
            seqtab <- makeSequenceTable(merged)
          } else {
            # Single-end: sequence table from forward reads only
            seqtab <- makeSequenceTable(dadaFs)
          }

          # Remove chimeras
          cat("Removing chimeras...\n")
          seqtab_nochim <- removeBimeraDenovo(seqtab, method = "consensus",
                                               multithread = threads)

          cat("ASVs:", ncol(seqtab_nochim), "\n")
          cat("Reads retained:", sum(seqtab_nochim), "/", sum(seqtab), "\n")

          # Save ASV count table (samples x ASVs)
          rownames(seqtab_nochim) <- sample_ids[seq_len(nrow(seqtab_nochim))]
          write.csv(seqtab_nochim, "asv_counts.csv", row.names = TRUE)

          # Save representative sequences
          asv_seqs <- colnames(seqtab_nochim)
          asv_ids <- paste0("ASV", seq_along(asv_seqs))
          writeLines(paste0(">", asv_ids, "\n", asv_seqs), "asv_seqs.fasta")

          # Save RDS for downstream use
          saveRDS(seqtab_nochim, "seqtab_nochim.rds")

          # Save tracking table
          track <- data.frame(
            sample = sample_ids[seq_len(nrow(filt_out[keep, , drop = FALSE]))],
            input = filt_out[keep, "reads.in"],
            filtered = filt_out[keep, "reads.out"]
          )
          write.csv(track, "dada2_tracking.csv", row.names = FALSE)

          cat("Done.\n")

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bioconductor-dada2:1.34.0--r44he5774e6_2"

baseCommand: [Rscript, dada2_denoise.R]

inputs:
  fastq_fwd:
    type: File[]
    doc: "Trimmed forward read FASTQ files (all samples)"

  fastq_rev:
    type: File[]?
    doc: "Trimmed reverse read FASTQ files (all samples, omit for single-end)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers"

  trunc_len_fwd:
    type: int?
    default: 0
    doc: "Truncation length for forward reads (0 = no truncation)"

  trunc_len_rev:
    type: int?
    default: 0
    doc: "Truncation length for reverse reads (0 = no truncation)"

  min_len:
    type: int?
    default: 50
    doc: "Minimum read length after filtering"

arguments:
  - position: 1
    valueFrom: |
      ${
        return inputs.fastq_fwd.map(function(f) { return f.path; }).join(",");
      }
  - position: 2
    valueFrom: |
      ${
        if (inputs.fastq_rev) {
          return inputs.fastq_rev.map(function(f) { return f.path; }).join(",");
        }
        return "";
      }
  - position: 3
    valueFrom: |
      ${
        return inputs.sample_ids.join(",");
      }
  - position: 4
    valueFrom: $(inputs.trunc_len_fwd)
  - position: 5
    valueFrom: $(inputs.trunc_len_rev)
  - position: 6
    valueFrom: $(inputs.min_len)
  - position: 7
    valueFrom: $(runtime.cores)

outputs:
  asv_counts:
    type: File
    outputBinding:
      glob: "asv_counts.csv"
    doc: "ASV count table (samples x ASVs)"

  asv_seqs:
    type: File
    outputBinding:
      glob: "asv_seqs.fasta"
    doc: "Representative ASV sequences"

  seqtab_rds:
    type: File
    outputBinding:
      glob: "seqtab_nochim.rds"
    doc: "Sequence table RDS for downstream R analysis"

  tracking:
    type: File
    outputBinding:
      glob: "dada2_tracking.csv"
    doc: "Read tracking through DADA2 pipeline"
