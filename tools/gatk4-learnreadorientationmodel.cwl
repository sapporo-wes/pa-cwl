#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 LearnReadOrientationModel"
doc: "Learn read orientation artifact priors from F1R2 counts"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, LearnReadOrientationModel]

inputs:
  f1r2_counts:
    type: File
    inputBinding:
      prefix: -I
    doc: "F1R2 read count tar.gz from Mutect2"

  sample_id:
    type: string
    doc: "Sample identifier for output naming"

arguments:
  - prefix: -O
    valueFrom: $(inputs.sample_id).orientation-model.tar.gz

outputs:
  orientation_model:
    type: File
    outputBinding:
      glob: "*.orientation-model.tar.gz"
    doc: "Read orientation artifact prior probabilities"
