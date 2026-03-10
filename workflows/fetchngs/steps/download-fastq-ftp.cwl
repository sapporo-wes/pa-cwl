#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Download FASTQ via FTP"
doc: "Download FASTQ files from ENA FTP and verify checksums"

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 2048
  NetworkAccess:
    networkAccess: true
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: download_ftp.py
        entry: |
          #!/usr/bin/env python3
          """Download FASTQ files from ENA FTP with md5 verification."""
          import hashlib
          import json
          import os
          import sys
          import urllib.request

          def download_file(url, output_path):
              """Download a file with progress reporting."""
              if not url.startswith("ftp://") and not url.startswith("http"):
                  url = "ftp://" + url
              print(f"Downloading: {url}")
              urllib.request.urlretrieve(url, output_path)
              size_mb = os.path.getsize(output_path) / (1024 * 1024)
              print(f"  Downloaded: {output_path} ({size_mb:.1f} MB)")

          def verify_md5(filepath, expected_md5):
              """Verify file MD5 checksum."""
              md5 = hashlib.md5()
              with open(filepath, "rb") as f:
                  for chunk in iter(lambda: f.read(8192), b""):
                      md5.update(chunk)
              actual = md5.hexdigest()
              if actual != expected_md5:
                  print(f"WARNING: MD5 mismatch for {filepath}: expected {expected_md5}, got {actual}",
                        file=sys.stderr)
                  return False
              print(f"  MD5 verified: {filepath}")
              return True

          def download_record(record):
              """Download FASTQ files for a single record."""
              ftp_urls = record.get("fastq_ftp", "").split(";")
              md5sums = record.get("fastq_md5", "").split(";")
              accession = record.get("run_accession", "unknown")

              if not ftp_urls or not ftp_urls[0]:
                  print(f"No FTP URLs found for {accession}", file=sys.stderr)
                  return

              for i, url in enumerate(ftp_urls):
                  if not url:
                      continue
                  filename = os.path.basename(url)
                  download_file(url, filename)
                  if i < len(md5sums) and md5sums[i]:
                      verify_md5(filename, md5sums[i])

              print(f"Completed download for {accession}: {len(ftp_urls)} file(s)")

          def main():
              with open(sys.argv[1]) as f:
                  metadata = json.load(f)

              records = metadata if isinstance(metadata, list) else [metadata]
              for record in records:
                  download_record(record)

          if __name__ == "__main__":
              main()

hints:
  DockerRequirement:
    dockerPull: "python:3.12-slim"

baseCommand: [python3, download_ftp.py]

inputs:
  metadata_json:
    type: File
    inputBinding:
      position: 1
    doc: "JSON metadata for a single accession (from fetch-ena-metadata)"

outputs:
  fastq_files:
    type: File[]
    outputBinding:
      glob: "*.fastq.gz"
    doc: "Downloaded FASTQ files"
