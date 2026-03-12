#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "MultiQC - Aggregate analysis reports"
doc: "Aggregate results from multiple tools into a single HTML report"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 2048
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/multiqc:1.21--pyhdfd78af_0"

baseCommand: []

inputs:
  report_files:
    type: File[]
    doc: "All QC report files to aggregate"

  title:
    type: string?
    doc: "Report title"

arguments:
  - shellQuote: false
    valueFrom: |
      ${
        var cmd = "";
        for (var i = 0; i < inputs.report_files.length; i++) {
          cmd += "cp " + inputs.report_files[i].path + " . && ";
        }
        cmd += "multiqc .";
        cmd += " --outdir .";
        cmd += " --filename multiqc_report";
        if (inputs.title) {
          cmd += " --title '" + inputs.title + "'";
        }
        cmd += " --force";
        return cmd;
      }

outputs:
  html_report:
    type: File
    outputBinding:
      glob: "multiqc_report.html"

  data_dir:
    type: Directory
    outputBinding:
      glob: "multiqc_report_data"
