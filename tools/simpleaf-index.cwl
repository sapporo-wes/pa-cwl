#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "simpleaf index"
doc: |
  Build a spliced+intronic (splici) reference index for single-cell
  RNA-seq quantification with simpleaf/alevin-fry.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 16384
  InlineJavascriptRequirement: {}
  EnvVarRequirement:
    envDef:
      ALEVIN_FRY_HOME: $(runtime.tmpdir)

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/simpleaf:0.21.1--hd612981_0"

baseCommand: [simpleaf, index]

inputs:
  genome_fasta:
    type: File
    inputBinding:
      prefix: --fasta
    doc: "Reference genome FASTA"

  gtf:
    type: File
    inputBinding:
      prefix: --gtf
    doc: "Gene annotation GTF file"

  rlen:
    type: int
    default: 91
    inputBinding:
      prefix: --rlen
    doc: "Read length for splici reference (typically read length - 1)"

  threads:
    type: int
    default: 4
    inputBinding:
      prefix: --threads

arguments:
  - prefix: --output
    valueFrom: simpleaf_index

outputs:
  index_dir:
    type: Directory
    outputBinding:
      glob: simpleaf_index
  t2g_map:
    type: File
    outputBinding:
      glob: simpleaf_index/index/t2g_3col.tsv
