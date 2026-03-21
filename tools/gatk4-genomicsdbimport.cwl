#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "GATK4 GenomicsDBImport"
doc: "Import single-sample gVCFs into GenomicsDB for joint genotyping"

requirements:
  ResourceRequirement:
    coresMin: 2
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing: []

hints:
  DockerRequirement:
    dockerPull: "broadinstitute/gatk:4.5.0.0"

baseCommand: [gatk, GenomicsDBImport]

inputs:
  gvcfs:
    type: File[]
    secondaryFiles:
      - .tbi
    doc: "Per-sample gVCF files from HaplotypeCaller"

  intervals:
    type: File?
    inputBinding:
      prefix: -L
    doc: "Intervals BED file (required for GenomicsDBImport)"

  interval_string:
    type: string?
    inputBinding:
      prefix: -L
    doc: "Interval string (e.g. chr1:1-1000000) if no BED provided"

  cohort_id:
    type: string
    default: "cohort"
    doc: "Cohort identifier for the GenomicsDB workspace"

arguments:
  - valueFrom: |
      ${
        var args = [];
        for (var i = 0; i < inputs.gvcfs.length; i++) {
          args.push("-V");
          args.push(inputs.gvcfs[i].path);
        }
        return args;
      }
  - prefix: --genomicsdb-workspace-path
    valueFrom: $(inputs.cohort_id)_genomicsdb
  - prefix: --merge-input-intervals
    valueFrom: "true"

outputs:
  genomicsdb_workspace:
    type: Directory
    outputBinding:
      glob: "*_genomicsdb"
