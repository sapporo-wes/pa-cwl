#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "SEACR - Peak calling for CUT&RUN"
doc: |
  Sparse Enrichment Analysis for CUT&RUN. Identifies enriched regions
  from CUT&RUN/CUT&TAG bedGraph data. Supports control-based or
  threshold-based peak calling.

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/seacr:1.3--hdfd78af_2"

baseCommand: [SEACR_1.3.sh]

inputs:
  target_bedgraph:
    type: File
    inputBinding:
      position: 1
    doc: "Target sample bedGraph file"

  control_bedgraph:
    type: File?
    doc: "IgG control bedGraph file (mutually exclusive with threshold)"

  threshold:
    type: float?
    default: 0.01
    doc: "Numeric threshold (0-1) for peak calling when no control is provided"

  normalize:
    type: string?
    default: "non"
    inputBinding:
      position: 3
    doc: "Normalization mode: norm (normalize) or non (no normalization)"

  mode:
    type: string?
    default: "stringent"
    inputBinding:
      position: 4
    doc: "Peak calling stringency: stringent or relaxed"

  sample_id:
    type: string
    doc: "Sample identifier for output prefix"

arguments:
  - position: 2
    valueFrom: |
      ${
        if (inputs.control_bedgraph) {
          return inputs.control_bedgraph.path;
        }
        return inputs.threshold.toString();
      }
  - position: 5
    valueFrom: $(inputs.sample_id)

outputs:
  peaks:
    type: File
    outputBinding:
      glob: |
        ${
          return inputs.sample_id + "." + inputs.mode + ".bed";
        }
    doc: "Peak calls in BED format"
