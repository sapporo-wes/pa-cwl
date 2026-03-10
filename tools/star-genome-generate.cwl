#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "STAR genomeGenerate - Build STAR genome index"
doc: "Generate STAR genome index from reference FASTA and GTF"

requirements:
  ResourceRequirement:
    coresMin: 8
    ramMin: 32768
  InitialWorkDirRequirement:
    listing:
      - entryname: star_index
        writable: true
        entry: "$({class: 'Directory', listing: []})"

hints:
  DockerRequirement:
    dockerPull: "quay.io/biocontainers/star:2.7.11b--h43eeafb_0"

baseCommand: [STAR, --runMode, genomeGenerate]

inputs:
  genome_fasta:
    type: File
    inputBinding:
      prefix: --genomeFastaFiles
    doc: "Reference genome FASTA"

  gtf:
    type: File
    inputBinding:
      prefix: --sjdbGTFfile
    doc: "Gene annotation GTF"

  sjdb_overhang:
    type: int?
    default: 100
    inputBinding:
      prefix: --sjdbOverhang
    doc: "Read length - 1 for splice junction database"

arguments:
  - prefix: --runThreadN
    valueFrom: $(runtime.cores)
  - prefix: --genomeDir
    valueFrom: star_index

outputs:
  index_dir:
    type: Directory
    outputBinding:
      glob: star_index
