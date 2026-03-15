#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "samtools view - Filter BAM reads"
doc: "Filter BAM to remove duplicates, unmapped, secondary, and low-MAPQ reads"

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1"

baseCommand: [samtools, view]

inputs:
  bam:
    type: File
    inputBinding:
      position: 100
    doc: "Input BAM file (sorted, marked duplicates)"

  sample_id:
    type: string
    doc: "Sample identifier"

  min_mapq:
    type: int?
    default: 1
    inputBinding:
      prefix: -q
    doc: "Minimum mapping quality"

  paired:
    type: boolean?
    default: true
    doc: "Paired-end data (adds proper-pair filter)"

arguments:
  - -b
  - -h
  - prefix: -@
    valueFrom: $(runtime.cores)
  - prefix: -o
    valueFrom: $(inputs.sample_id).filtered.bam
  # -F 1804: exclude unmapped(4), mate unmapped(8), secondary(256), failQC(512), duplicate(1024)
  # -f 2: require proper pair (PE only)
  - prefix: -F
    valueFrom: "1804"
  - valueFrom: |
      ${
        if (inputs.paired) return ["-f", "2"];
        return [];
      }

outputs:
  filtered_bam:
    type: File
    outputBinding:
      glob: "*.filtered.bam"
