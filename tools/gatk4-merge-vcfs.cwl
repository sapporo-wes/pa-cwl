#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 MergeVcfs"
doc: "Merge multiple VCF files into a single VCF"

requirements:
  ResourceRequirement:
    coresMin: 1
    ramMin: 4096
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, MergeVcfs]

inputs:
  vcfs:
    type: File[]
    secondaryFiles:
      - .tbi
    doc: "Input VCF files to merge"

  output_name:
    type: string
    doc: "Output file name (without extension)"

arguments:
  - valueFrom: |
      ${
        var args = [];
        for (var i = 0; i < inputs.vcfs.length; i++) {
          args.push("-I");
          args.push(inputs.vcfs[i].path);
        }
        return args;
      }
  - prefix: -O
    valueFrom: $(inputs.output_name).vcf.gz

outputs:
  merged_vcf:
    type: File
    secondaryFiles:
      - .tbi
    outputBinding:
      glob: "*.vcf.gz"
