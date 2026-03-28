#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "prepare-references - Build genome indices for analysis workflows"
doc: |
  Conditionally builds genome indices based on boolean flags.
  Always indexes the reference FASTA with samtools faidx.
  Optionally builds STAR, BWA-MEM2, Bowtie2, and/or HISAT2 indices
  depending on which flags are set to true.

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  genome_fasta:
    type: File
    doc: "Reference genome FASTA"

  gtf:
    type: File?
    doc: "Gene annotation GTF (required for STAR index)"

  build_star:
    type: boolean
    default: false
    doc: "Build STAR genome index"

  build_bwa:
    type: boolean
    default: false
    doc: "Build BWA-MEM2 genome index"

  build_bowtie2:
    type: boolean
    default: false
    doc: "Build Bowtie2 genome index"

  build_hisat2:
    type: boolean
    default: false
    doc: "Build HISAT2 genome index"

  genome_sa_index_nbases:
    type: int?
    doc: "For small genomes, set to min(14, log2(GenomeLength)/2 - 1). Passed to STAR genomeGenerate."

steps:
  samtools_faidx:
    run: ../../tools/samtools-faidx.cwl
    in:
      fasta: genome_fasta
    out: [indexed_fasta]

  star_genome_generate:
    run: ../../tools/star-genome-generate.cwl
    when: $(inputs.build_star)
    in:
      genome_fasta: genome_fasta
      gtf: gtf
      genome_sa_index_nbases: genome_sa_index_nbases
      build_star: build_star
    out: [index_dir]

  bwa_mem2_index:
    run: ../../tools/bwa-mem2-index.cwl
    when: $(inputs.build_bwa)
    in:
      genome_fasta: genome_fasta
      build_bwa: build_bwa
    out: [genome_with_index, index_files]

  bowtie2_build:
    run: ../../tools/bowtie2-build.cwl
    when: $(inputs.build_bowtie2)
    in:
      reference: genome_fasta
      build_bowtie2: build_bowtie2
    out: [index_dir]

  hisat2_build:
    run: ../../tools/hisat2-build.cwl
    when: $(inputs.build_hisat2)
    in:
      genome_fasta: genome_fasta
      build_hisat2: build_hisat2
    out: [index_files]

outputs:
  indexed_fasta:
    type: File
    outputSource: samtools_faidx/indexed_fasta
    doc: "Reference FASTA with .fai index"

  star_index:
    type: Directory?
    outputSource: star_genome_generate/index_dir
    doc: "STAR genome index directory"

  bwa_index:
    type: File?
    outputSource: bwa_mem2_index/genome_with_index
    doc: "BWA-MEM2 indexed genome with secondary index files"

  bowtie2_index:
    type: File[]?
    outputSource: bowtie2_build/index_dir
    doc: "Bowtie2 index files"

  hisat2_index:
    type: File[]?
    outputSource: hisat2_build/index_files
    doc: "HISAT2 index files"
