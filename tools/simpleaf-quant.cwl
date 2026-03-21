#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "simpleaf quant"
doc: |
  Single-cell RNA-seq quantification using simpleaf (salmon alevin + alevin-fry).
  Maps reads, generates permit list, and quantifies gene expression per cell.

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

baseCommand: [simpleaf, quant]

inputs:
  index_dir:
    type: Directory
    inputBinding:
      prefix: --index
      valueFrom: $(self.path)/index
    doc: "simpleaf index output directory"

  reads1:
    type: File
    inputBinding:
      prefix: --reads1
    doc: "Barcode + UMI read (R1)"

  reads2:
    type: File
    inputBinding:
      prefix: --reads2
    doc: "cDNA read (R2)"

  chemistry:
    type: string
    default: "10xv3"
    inputBinding:
      prefix: --chemistry
    doc: "Chemistry specification (10xv2, 10xv3, etc.)"

  t2g_map:
    type: File
    inputBinding:
      prefix: --t2g-map
    doc: "Transcript-to-gene mapping file"

  resolution:
    type: string
    default: "cr-like"
    inputBinding:
      prefix: --resolution
    doc: "UMI resolution mode (cr-like, cr-like-em, parsimony)"

  barcode_whitelist:
    type: File?
    inputBinding:
      prefix: --explicit-pl
    doc: "Explicit cell barcode permit list (if not using knee detection)"

  expect_cells:
    type: int?
    inputBinding:
      prefix: --expect-cells
    doc: "Expected number of cells (alternative to explicit permit list)"

  threads:
    type: int
    default: 4
    inputBinding:
      prefix: --threads

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: --output
    valueFrom: $(inputs.sample_id)_alevin_fry
  - "--no-piscem"

outputs:
  quant_dir:
    type: Directory
    outputBinding:
      glob: "*_alevin_fry"
