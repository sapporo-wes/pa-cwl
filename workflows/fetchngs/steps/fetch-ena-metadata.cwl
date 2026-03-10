#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Fetch ENA metadata for SRA/ENA/DDBJ accessions"
doc: |
  Query the ENA REST API to retrieve metadata for sequencing run
  accessions. Resolves SRA/DDBJ accessions to ENA metadata including
  FTP download URLs and md5 checksums.

requirements:
  DockerRequirement:
    dockerPull: "python:3.12-slim"
  ResourceRequirement:
    coresMin: 1
    ramMin: 1024
  NetworkAccess:
    networkAccess: true
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: fetch_metadata.py
        entry: |
          #!/usr/bin/env python3
          """Fetch metadata from ENA for given accessions."""
          import csv
          import json
          import sys
          import urllib.request
          import urllib.parse
          import urllib.error

          ENA_API = "https://www.ebi.ac.uk/ena/portal/api/filereport"
          FIELDS = [
              "run_accession", "experiment_accession", "sample_accession",
              "study_accession", "library_layout", "library_strategy",
              "library_source", "library_selection", "instrument_platform",
              "instrument_model", "read_count", "base_count",
              "fastq_ftp", "fastq_md5", "fastq_bytes",
              "experiment_title", "sample_title", "sample_alias",
              "tax_id", "scientific_name"
          ]

          def fetch_single(accession):
              params = urllib.parse.urlencode({
                  "accession": accession,
                  "result": "read_run",
                  "fields": ",".join(FIELDS),
                  "format": "json",
                  "limit": "0"
              })
              url = f"{ENA_API}?{params}"
              try:
                  req = urllib.request.Request(url)
                  with urllib.request.urlopen(req, timeout=30) as resp:
                      data = json.loads(resp.read().decode())
                      return data if data else []
              except (urllib.error.URLError, json.JSONDecodeError) as e:
                  print(f"Warning: Failed to fetch {accession}: {e}", file=sys.stderr)
                  return []

          def main():
              with open(sys.argv[1]) as f:
                  accessions = [line.strip() for line in f if line.strip()]

              all_records = []
              for acc in accessions:
                  records = fetch_single(acc)
                  if records:
                      all_records.extend(records)
                  else:
                      print(f"Warning: No records found for {acc}", file=sys.stderr)

              with open("metadata.json", "w") as f:
                  json.dump(all_records, f, indent=2)

              if all_records:
                  with open("metadata.tsv", "w", newline="") as f:
                      writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t",
                                              extrasaction="ignore")
                      writer.writeheader()
                      for rec in all_records:
                          writer.writerow(rec)

              print(f"Fetched metadata for {len(all_records)} runs from {len(accessions)} accessions")

          if __name__ == "__main__":
              main()
      - entryname: accessions.txt
        entry: $(inputs.accessions.join("\n"))

baseCommand: [python3, fetch_metadata.py, accessions.txt]

inputs:
  accessions:
    type: string[]
    doc: "SRA/ENA/DDBJ run accessions"

outputs:
  metadata_json:
    type: File
    outputBinding:
      glob: "metadata.json"
    doc: "JSON file with all run metadata"

  metadata_tsv:
    type: File
    outputBinding:
      glob: "metadata.tsv"
    doc: "TSV file with all run metadata"
