#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "MultiQC - Aggregate analysis reports"
doc: "Aggregate results from multiple tools into a single HTML report"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 2048
  InitialWorkDirRequirement:
    listing: $(inputs.report_files)

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/multiqc:1.21--pyhdfd78af_0"

baseCommand: [multiqc]

inputs:
  report_files:
    type: File[]
    doc: "All QC report files to aggregate"

  title:
    type: string?
    inputBinding:
      prefix: --title
    doc: "Report title"

arguments:
  - "."
  - prefix: --outdir
    valueFrom: "."
  - prefix: --filename
    valueFrom: "multiqc_report"
  - "--force"

outputs:
  html_report:
    type: File
    outputBinding:
      glob: "multiqc_report.html"

  data_dir:
    type: Directory
    outputBinding:
      glob: "multiqc_report_data"
