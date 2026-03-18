#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "mag - Metagenome-Assembled Genomes pipeline"
doc: |
  Metagenome assembly and binning pipeline. Performs QC, trimming,
  assembly with MEGAHIT, contig binning with MetaBAT2, gene prediction
  with Prodigal, and assembly quality assessment with QUAST.

  Part of the pa-cwl (Pretty Agentic CWL) collection.

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  # === Samples ===
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (one per sample)"

  fastq_rev:
    type: File[]
    doc: "Reverse read FASTQ files (one per sample)"

  sample_ids:
    type: string[]
    doc: "Sample identifiers (same order as FASTQ files)"

  # === Assembly parameters ===
  min_contig_len:
    type: int?
    default: 1000
    doc: "Minimum contig length for assembly output"

steps:
  # =====================
  # FastQC on raw reads
  # =====================
  fastqc:
    run: ../../tools/fastqc.cwl
    scatter: fastq
    in:
      fastq: fastq_fwd
    out: [html_report, zip_report]

  # =====================
  # Quality trimming with fastp (per sample)
  # =====================
  fastp:
    run: ../../tools/fastp.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      sample_id: sample_ids
    out: [trimmed_fwd, trimmed_rev, json_report]

  # =====================
  # Metagenome assembly (co-assembly)
  # =====================
  assembly:
    run: ../../tools/spades.cwl
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      min_contig_len: min_contig_len
    out: [contigs, spades_log]

  # =====================
  # Assembly QC with QUAST
  # =====================
  quast:
    run: ../../tools/quast.cwl
    in:
      contigs: assembly/contigs
    out: [report_tsv, report_html]

  # =====================
  # Build Bowtie2 index from contigs
  # =====================
  bowtie2_build:
    run: ../../tools/bowtie2-build.cwl
    in:
      reference: assembly/contigs
    out: [index_dir, index_base]

  # =====================
  # Map reads back to contigs (per sample)
  # =====================
  bowtie2_align:
    run: ../../tools/bowtie2-align.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      index_files: bowtie2_build/index_dir
      index_base: bowtie2_build/index_base
      sample_id: sample_ids
    out: [sorted_bam, log]

  # =====================
  # MetaBAT2 binning
  # =====================
  metabat2:
    run: ../../tools/metabat2.cwl
    in:
      contigs: assembly/contigs
      bams: bowtie2_align/sorted_bam
    out: [bins, depth_file, bin_summary]

  # =====================
  # Gene prediction with Prodigal
  # =====================
  prodigal:
    run: ../../tools/prodigal.cwl
    in:
      input_fasta: assembly/contigs
      prefix:
        default: "assembly"
    out: [gene_annotations, protein_sequences, gene_sequences]

  # =====================
  # MultiQC reporting
  # =====================
  multiqc:
    run: ../../tools/multiqc.cwl
    in:
      report_files:
        source:
          - fastqc/zip_report
          - fastp/json_report
          - bowtie2_align/log
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl mag"
    out: [html_report, data_dir]

outputs:
  contigs:
    type: File
    outputSource: assembly/contigs
    doc: "Assembled metagenome contigs"

  bins:
    type: File[]
    outputSource: metabat2/bins
    doc: "Genome bin FASTA files"

  bin_summary:
    type: File
    outputSource: metabat2/bin_summary
    doc: "Bin summary statistics"

  gene_annotations:
    type: File
    outputSource: prodigal/gene_annotations
    doc: "Predicted gene annotations (GFF)"

  protein_sequences:
    type: File
    outputSource: prodigal/protein_sequences
    doc: "Predicted protein sequences (FAA)"

  quast_report:
    type: File
    outputSource: quast/report_tsv
    doc: "Assembly quality statistics"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"
