#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Check mirror latency"
doc: |
  Measures network latency to DDBJ, ENA, and NCBI FTP/HTTPS endpoints
  and outputs the preferred download source. Used by the aria2 download
  method to pick the fastest mirror automatically.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 512
  NetworkAccess:
    networkAccess: true
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: check_latency.py
        entry: |
          #!/usr/bin/env python3
          """Measure latency to SRA mirrors and pick the fastest."""
          import json
          import time
          import urllib.request

          MIRRORS = {
              "ddbj": {
                  "label": "DDBJ (Japan)",
                  "test_url": "https://ddbj.nig.ac.jp/public/ddbj_database/dra/",
                  "ftp_base": "ftp.ddbj.nig.ac.jp",
              },
              "ena": {
                  "label": "ENA (Europe)",
                  "test_url": "https://www.ebi.ac.uk/ena/portal/api/",
                  "ftp_base": "ftp.sra.ebi.ac.uk",
              },
              "ncbi": {
                  "label": "NCBI (US)",
                  "test_url": "https://www.ncbi.nlm.nih.gov/sra/",
                  "ftp_base": "ftp-trace.ncbi.nlm.nih.gov",
              },
          }

          def measure_latency(url, attempts=3, timeout=10):
              """Measure average time-to-first-byte (seconds)."""
              times = []
              for _ in range(attempts):
                  try:
                      req = urllib.request.Request(url, method="HEAD")
                      start = time.monotonic()
                      with urllib.request.urlopen(req, timeout=timeout) as resp:
                          _ = resp.status
                      elapsed = time.monotonic() - start
                      times.append(elapsed)
                  except Exception:
                      times.append(timeout)
              return sum(times) / len(times) if times else timeout

          def main():
              results = {}
              for name, mirror in MIRRORS.items():
                  latency = measure_latency(mirror["test_url"])
                  results[name] = {
                      "label": mirror["label"],
                      "latency_seconds": round(latency, 3),
                  }
                  print(f"{mirror['label']}: {latency:.3f}s")

              fastest = min(results, key=lambda k: results[k]["latency_seconds"])
              print(f"\nFastest mirror: {results[fastest]['label']} ({results[fastest]['latency_seconds']}s)")

              output = {
                  "preferred_source": fastest,
                  "latencies": results,
              }
              with open("mirror_latency.json", "w") as f:
                  json.dump(output, f, indent=2)

              with open("preferred_source.txt", "w") as f:
                  f.write(fastest)

          if __name__ == "__main__":
              main()

hints:
  DockerRequirement:
    dockerPull: "python:3.12-slim"

baseCommand: [python3, check_latency.py]

inputs: []

outputs:
  mirror_latency:
    type: File
    outputBinding:
      glob: "mirror_latency.json"
    doc: "JSON with latency measurements for all mirrors"

  preferred_source:
    type: string
    outputBinding:
      glob: "preferred_source.txt"
      loadContents: true
      outputEval: $(self[0].contents.trim())
    doc: "Fastest mirror: ddbj, ena, or ncbi"
