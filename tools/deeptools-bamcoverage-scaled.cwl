#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "deepTools bamCoverage (scaled) - Generate spike-in normalized bigWig"
doc: |
  Generate a bigWig coverage track normalized by a spike-in scale factor.
  Uses --scaleFactor instead of --normalizeUsing for spike-in calibration.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/deeptools:3.5.6--pyhdfd78af_0"

baseCommand: [bamCoverage]

inputs:
  bam:
    type: File
    secondaryFiles:
      - .bai
    inputBinding:
      prefix: --bam
    doc: "Input BAM file (sorted, indexed)"

  sample_id:
    type: string
    doc: "Sample identifier"

  scale_factor:
    type: float
    inputBinding:
      prefix: --scaleFactor
    doc: "Spike-in normalization scale factor"

  bin_size:
    type: int?
    default: 50
    inputBinding:
      prefix: --binSize
    doc: "Bin size in bases"

  extend_reads:
    type: int?
    default: 200
    inputBinding:
      prefix: --extendReads
    doc: "Extend reads to fragment length"

arguments:
  - prefix: -p
    valueFrom: $(runtime.cores)
  - prefix: -o
    valueFrom: $(inputs.sample_id).scaled.bigWig
  - prefix: --normalizeUsing
    valueFrom: "None"
  - --skipNonCoveredRegions

outputs:
  scaled_bigwig:
    type: File
    outputBinding:
      glob: "*.scaled.bigWig"
    doc: "Spike-in normalized bigWig coverage track"
