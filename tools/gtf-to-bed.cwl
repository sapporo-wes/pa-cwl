#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Convert GTF to BED12"
doc: "Convert GTF gene annotation to BED12 format for RSeQC"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 1024
  ShellCommandRequirement: {}
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: gtf2bed.py
        entry: |
          #!/usr/bin/env python3
          """Convert GTF to BED12 format."""
          import sys
          from collections import defaultdict

          def main():
              gtf_file = sys.argv[1]
              transcripts = defaultdict(lambda: {
                  "chrom": "", "strand": "", "exons": [],
                  "gene_id": "", "transcript_id": ""
              })

              with open(gtf_file) as f:
                  for line in f:
                      if line.startswith("#"):
                          continue
                      fields = line.strip().split("\t")
                      if len(fields) < 9:
                          continue
                      if fields[2] != "exon":
                          continue

                      chrom = fields[0]
                      start = int(fields[3]) - 1
                      end = int(fields[4])
                      strand = fields[6]
                      attrs = fields[8]

                      tid = ""
                      for attr in attrs.split(";"):
                          attr = attr.strip()
                          if attr.startswith("transcript_id"):
                              tid = attr.split('"')[1] if '"' in attr else attr.split()[1]
                              break
                      if not tid:
                          continue

                      transcripts[tid]["chrom"] = chrom
                      transcripts[tid]["strand"] = strand
                      transcripts[tid]["transcript_id"] = tid
                      transcripts[tid]["exons"].append((start, end))

              with open("genes.bed", "w") as out:
                  for tid, data in transcripts.items():
                      if not data["exons"]:
                          continue
                      exons = sorted(data["exons"])
                      chrom = data["chrom"]
                      strand = data["strand"]
                      tx_start = exons[0][0]
                      tx_end = exons[-1][1]
                      block_count = len(exons)
                      block_sizes = ",".join(str(e[1] - e[0]) for e in exons)
                      block_starts = ",".join(str(e[0] - tx_start) for e in exons)

                      out.write(f"{chrom}\t{tx_start}\t{tx_end}\t{tid}\t0\t{strand}\t"
                                f"{tx_start}\t{tx_end}\t0\t{block_count}\t"
                                f"{block_sizes}\t{block_starts}\n")

              print(f"Converted {len(transcripts)} transcripts to BED12", file=sys.stderr)

          if __name__ == "__main__":
              main()

hints:
  DockerRequirement:
    dockerPull: "python:3.12-slim"

baseCommand: [python3, gtf2bed.py]

inputs:
  gtf:
    type: File
    inputBinding:
      position: 1
    doc: "GTF annotation file"

outputs:
  bed:
    type: File
    outputBinding:
      glob: "genes.bed"
