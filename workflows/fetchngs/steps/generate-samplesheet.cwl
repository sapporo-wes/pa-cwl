#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Generate samplesheet from metadata and downloaded files"
doc: |
  Create a samplesheet CSV compatible with downstream pa-cwl workflows
  from ENA metadata and downloaded FASTQ files.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 512
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: generate_samplesheet.py
        entry: |
          #!/usr/bin/env python3
          """Generate samplesheet from ENA metadata and FASTQ files."""
          import csv
          import json
          import os
          import sys
          from pathlib import Path

          def main():
              metadata_file = sys.argv[1]
              fastq_dir = sys.argv[2] if len(sys.argv) > 2 else "."

              with open(metadata_file) as f:
                  records = json.load(f)

              rows = []
              for rec in records:
                  accession = rec.get("run_accession", "")
                  layout = rec.get("library_layout", "SINGLE")
                  organism = rec.get("scientific_name", "")
                  strandedness = "auto"

                  # Find matching FASTQ files
                  ftp_urls = rec.get("fastq_ftp", "").split(";")
                  fastq_basenames = [os.path.basename(u) for u in ftp_urls if u]

                  fastq1 = ""
                  fastq2 = ""
                  if fastq_basenames:
                      fastq1 = fastq_basenames[0]
                      if len(fastq_basenames) > 1 and layout == "PAIRED":
                          fastq2 = fastq_basenames[1]

                  rows.append({
                      "sample": rec.get("sample_alias", accession),
                      "fastq_1": fastq1,
                      "fastq_2": fastq2,
                      "strandedness": strandedness,
                      "run_accession": accession,
                      "experiment_accession": rec.get("experiment_accession", ""),
                      "sample_accession": rec.get("sample_accession", ""),
                      "study_accession": rec.get("study_accession", ""),
                      "library_layout": layout,
                      "library_strategy": rec.get("library_strategy", ""),
                      "scientific_name": organism,
                      "instrument_platform": rec.get("instrument_platform", ""),
                  })

              fieldnames = [
                  "sample", "fastq_1", "fastq_2", "strandedness",
                  "run_accession", "experiment_accession", "sample_accession",
                  "study_accession", "library_layout", "library_strategy",
                  "scientific_name", "instrument_platform"
              ]

              with open("samplesheet.csv", "w", newline="") as f:
                  writer = csv.DictWriter(f, fieldnames=fieldnames)
                  writer.writeheader()
                  writer.writerows(rows)

              print(f"Generated samplesheet with {len(rows)} samples")

          if __name__ == "__main__":
              main()

hints:
  DockerRequirement:
    dockerPull: "python:3.12-slim"

baseCommand: [python3, generate_samplesheet.py]

inputs:
  metadata_json:
    type: File
    inputBinding:
      position: 1
    doc: "JSON metadata from fetch-ena-metadata"

outputs:
  samplesheet:
    type: File
    outputBinding:
      glob: "samplesheet.csv"
    doc: "Samplesheet CSV for downstream workflows"
