#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "RSEM prepare-reference - Build RSEM reference"
doc: "Prepare reference for RSEM quantification"

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 16384
  InitialWorkDirRequirement:
    listing:
      - entryname: rsem_ref
        writable: true
        entry: "$({class: 'Directory', listing: []})"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/rsem:1.3.3--pl5321h077b44d_12"

baseCommand: [rsem-prepare-reference]

inputs:
  genome_fasta:
    type: File
    inputBinding:
      position: 1
    doc: "Reference genome FASTA"

  gtf:
    type: File
    inputBinding:
      prefix: --gtf
    doc: "Gene annotation GTF"

arguments:
  - prefix: --num-threads
    valueFrom: $(runtime.cores)
  - position: 2
    valueFrom: "rsem_ref/rsem"

outputs:
  reference_dir:
    type: Directory
    outputBinding:
      glob: rsem_ref
