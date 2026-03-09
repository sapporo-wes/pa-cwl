#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Aggregate count matrices from quantification outputs"
doc: |
  Merge per-sample quantification results (Salmon quant.sf, RSEM .genes.results,
  or kallisto abundance.tsv) into gene-level and transcript-level count matrices.

requirements:
  DockerRequirement:
    dockerPull: "python:3.12-slim"
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: aggregate.py
        entry: |
          #!/usr/bin/env python3
          """Aggregate per-sample quantification into count matrices."""
          import csv
          import json
          import os
          import sys
          from collections import defaultdict

          def read_salmon_quant(filepath):
              """Read Salmon quant.sf file."""
              genes = {}
              with open(filepath) as f:
                  reader = csv.DictReader(f, delimiter="\t")
                  for row in reader:
                      genes[row["Name"]] = {
                          "tpm": float(row["TPM"]),
                          "count": float(row["NumReads"]),
                          "length": float(row["EffectiveLength"])
                      }
              return genes

          def read_rsem_genes(filepath):
              """Read RSEM .genes.results file."""
              genes = {}
              with open(filepath) as f:
                  reader = csv.DictReader(f, delimiter="\t")
                  for row in reader:
                      genes[row["gene_id"]] = {
                          "tpm": float(row["TPM"]),
                          "count": float(row["expected_count"]),
                          "length": float(row["effective_length"]) if row["effective_length"] != "0.00" else 0
                      }
              return genes

          def read_kallisto_abundance(filepath):
              """Read kallisto abundance.tsv file."""
              genes = {}
              with open(filepath) as f:
                  reader = csv.DictReader(f, delimiter="\t")
                  for row in reader:
                      genes[row["target_id"]] = {
                          "tpm": float(row["tpm"]),
                          "count": float(row["est_counts"]),
                          "length": float(row["eff_length"])
                      }
              return genes

          def main():
              quant_files = sys.argv[1:]
              if not quant_files:
                  print("No quantification files provided", file=sys.stderr)
                  sys.exit(1)

              # Detect format from first file
              with open(quant_files[0]) as f:
                  header = f.readline()

              if "NumReads" in header:
                  reader_fn = read_salmon_quant
                  source = "salmon"
              elif "expected_count" in header:
                  reader_fn = read_rsem_genes
                  source = "rsem"
              elif "est_counts" in header:
                  reader_fn = read_kallisto_abundance
                  source = "kallisto"
              else:
                  print(f"Unknown quantification format: {header[:100]}", file=sys.stderr)
                  sys.exit(1)

              # Read all samples
              all_genes = set()
              samples = {}
              for qf in quant_files:
                  sample_name = os.path.basename(os.path.dirname(qf))
                  if not sample_name or sample_name == ".":
                      sample_name = os.path.splitext(os.path.basename(qf))[0]
                  data = reader_fn(qf)
                  samples[sample_name] = data
                  all_genes.update(data.keys())

              gene_list = sorted(all_genes)
              sample_names = sorted(samples.keys())

              # Write count matrix
              with open("gene_counts.tsv", "w") as f:
                  f.write("gene_id\t" + "\t".join(sample_names) + "\n")
                  for gene in gene_list:
                      counts = [str(samples[s].get(gene, {}).get("count", 0)) for s in sample_names]
                      f.write(gene + "\t" + "\t".join(counts) + "\n")

              # Write TPM matrix
              with open("gene_tpm.tsv", "w") as f:
                  f.write("gene_id\t" + "\t".join(sample_names) + "\n")
                  for gene in gene_list:
                      tpms = [str(samples[s].get(gene, {}).get("tpm", 0)) for s in sample_names]
                      f.write(gene + "\t" + "\t".join(tpms) + "\n")

              print(f"Aggregated {len(gene_list)} genes from {len(sample_names)} samples ({source})")

          if __name__ == "__main__":
              main()

baseCommand: [python3, aggregate.py]

inputs:
  quant_files:
    type: File[]
    inputBinding:
      position: 1
    doc: "Per-sample quantification files (quant.sf, .genes.results, or abundance.tsv)"

outputs:
  gene_counts:
    type: File
    outputBinding:
      glob: "gene_counts.tsv"
    doc: "Gene-level raw count matrix"

  gene_tpm:
    type: File
    outputBinding:
      glob: "gene_tpm.tsv"
    doc: "Gene-level TPM matrix"
