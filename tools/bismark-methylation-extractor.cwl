#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "Bismark methylation extractor"
doc: "Extract per-base methylation information from Bismark BAM"

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/bismark:0.24.2--hdfd78af_0"

baseCommand: [bismark_methylation_extractor]

inputs:
  bam:
    type: File
    inputBinding:
      position: 100
    doc: "Bismark-aligned, deduplicated BAM file"

  paired:
    type: boolean?
    default: true
    inputBinding:
      prefix: --paired-end
    doc: "Paired-end data"

  genome_dir:
    type: Directory
    inputBinding:
      prefix: --genome_folder
    doc: "Bismark genome directory"

  no_overlap:
    type: boolean?
    default: true
    inputBinding:
      prefix: --no_overlap
    doc: "Avoid counting overlapping PE reads twice"

arguments:
  - --comprehensive
  - --gzip
  - --bedGraph
  - --parallel
  - "2"
  - --cytosine_report

outputs:
  bedgraph:
    type: File
    outputBinding:
      glob: "*.bedGraph.gz"
    doc: "Methylation bedGraph"

  coverage:
    type: File
    outputBinding:
      glob: "*.cov.gz"
    doc: "Bismark coverage file"

  cytosine_report:
    type: File?
    outputBinding:
      glob: "*.CX_report.txt.gz"
    doc: "Genome-wide cytosine report"

  mbias:
    type: File
    outputBinding:
      glob: "*M-bias.txt"
    doc: "M-bias report"

  splitting_report:
    type: File
    outputBinding:
      glob: "*splitting_report.txt"
    doc: "Methylation extraction splitting report"
