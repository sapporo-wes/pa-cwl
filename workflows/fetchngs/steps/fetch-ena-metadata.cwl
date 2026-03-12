#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Fetch ENA metadata for SRA/ENA/DDBJ accessions"
doc: |
  Query the ENA REST API to retrieve metadata for sequencing accessions.
  Accepts run (SRR/ERR/DRR), experiment (SRX/ERX/DRX), sample (SRS/ERS/DRS),
  study (SRP/ERP/DRP), BioProject (PRJNA/PRJEB/PRJDB), BioSample (SAMN/SAME/SAMD),
  and GEO (GSE/GSM) accessions. Validates formats and resolves project/GEO IDs
  to individual runs.

requirements:
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
          import re
          import sys
          import urllib.request
          import urllib.parse
          import urllib.error

          ENA_API = "https://www.ebi.ac.uk/ena/portal/api/filereport"
          NCBI_EUTILS = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
          FIELDS = [
              "run_accession", "experiment_accession", "sample_accession",
              "study_accession", "library_layout", "library_strategy",
              "library_source", "library_selection", "instrument_platform",
              "instrument_model", "read_count", "base_count",
              "fastq_ftp", "fastq_md5", "fastq_bytes",
              "experiment_title", "sample_title", "sample_alias",
              "tax_id", "scientific_name"
          ]

          ACCESSION_PATTERNS = {
              "run": re.compile(r"^[SED]RR\d+$"),
              "experiment": re.compile(r"^[SED]RX\d+$"),
              "sample": re.compile(r"^[SED]RS\d+$"),
              "study": re.compile(r"^[SED]RP\d+$"),
              "bioproject": re.compile(r"^PRJ[A-Z]{1,2}\d+$"),
              "biosample": re.compile(r"^SAM[A-Z]{1,2}\d+$"),
              "geo_series": re.compile(r"^GSE\d+$"),
              "geo_sample": re.compile(r"^GSM\d+$"),
          }

          def classify_accession(acc):
              for acc_type, pattern in ACCESSION_PATTERNS.items():
                  if pattern.match(acc):
                      return acc_type
              return None

          def resolve_geo(geo_id):
              """Resolve GEO accession (GSE/GSM) to SRA accessions via NCBI eutils."""
              db = "gds" if geo_id.startswith("GSE") else "gds"
              search_url = f"{NCBI_EUTILS}/esearch.fcgi?db={db}&term={geo_id}&retmode=json"
              try:
                  with urllib.request.urlopen(search_url, timeout=30) as resp:
                      data = json.loads(resp.read().decode())
                  ids = data.get("esearchresult", {}).get("idlist", [])
                  if not ids:
                      return []

                  sra_accs = []
                  for gds_id in ids:
                      link_url = (f"{NCBI_EUTILS}/elink.fcgi?dbfrom=gds&db=sra"
                                  f"&id={gds_id}&retmode=json")
                      with urllib.request.urlopen(link_url, timeout=30) as resp:
                          link_data = json.loads(resp.read().decode())
                      linksets = link_data.get("linksets", [])
                      for ls in linksets:
                          for ldb in ls.get("linksetdbs", []):
                              if ldb.get("dbto") == "sra":
                                  sra_ids = [l["id"] for l in ldb.get("links", [])]
                                  for sra_id in sra_ids:
                                      fetch_url = (f"{NCBI_EUTILS}/efetch.fcgi?db=sra"
                                                   f"&id={sra_id}&rettype=runinfo&retmode=text")
                                      with urllib.request.urlopen(fetch_url, timeout=30) as resp:
                                          text = resp.read().decode()
                                      for line in text.strip().split("\n")[1:]:
                                          if line.strip():
                                              run_acc = line.split(",")[0]
                                              if re.match(r"^[SED]RR\d+$", run_acc):
                                                  sra_accs.append(run_acc)
                  return sra_accs
              except Exception as e:
                  print(f"Warning: Failed to resolve GEO {geo_id}: {e}", file=sys.stderr)
                  return []

          def fetch_ena(accession):
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

              invalid = []
              for acc in accessions:
                  if classify_accession(acc) is None:
                      invalid.append(acc)
              if invalid:
                  print(f"ERROR: Unrecognized accession format: {', '.join(invalid)}",
                        file=sys.stderr)
                  print("Supported formats: SRR/ERR/DRR (run), SRX/ERX/DRX (experiment), "
                        "SRS/ERS/DRS (sample), SRP/ERP/DRP (study), "
                        "PRJNA/PRJEB/PRJDB (bioproject), SAMN/SAME/SAMD (biosample), "
                        "GSE (GEO series), GSM (GEO sample)", file=sys.stderr)
                  sys.exit(1)

              resolved = []
              for acc in accessions:
                  acc_type = classify_accession(acc)
                  if acc_type in ("geo_series", "geo_sample"):
                      print(f"Resolving GEO accession {acc}...")
                      sra_accs = resolve_geo(acc)
                      if sra_accs:
                          print(f"  Resolved {acc} to {len(sra_accs)} run(s): {', '.join(sra_accs[:5])}"
                                + (f"... (+{len(sra_accs)-5} more)" if len(sra_accs) > 5 else ""))
                          resolved.extend(sra_accs)
                      else:
                          print(f"Warning: No SRA runs found for {acc}", file=sys.stderr)
                  else:
                      resolved.append(acc)

              all_records = []
              seen_runs = set()
              for acc in resolved:
                  records = fetch_ena(acc)
                  for rec in records:
                      run_id = rec.get("run_accession", "")
                      if run_id and run_id not in seen_runs:
                          seen_runs.add(run_id)
                          all_records.append(rec)
                  if not records:
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
              else:
                  with open("metadata.tsv", "w") as f:
                      f.write("\t".join(FIELDS) + "\n")

              print(f"Fetched metadata for {len(all_records)} runs from {len(accessions)} accessions")

          if __name__ == "__main__":
              main()
      - entryname: accessions.txt
        entry: $(inputs.accessions.join("\n") + "\n")

hints:
  DockerRequirement:
    dockerPull: "python:3.12-slim"

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
