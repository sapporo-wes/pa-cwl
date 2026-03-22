#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "Spike-in normalization subworkflow"
doc: |
  Align reads to a spike-in reference genome (e.g., E. coli), compute
  normalization scale factors from spike-in read counts, and generate
  scaled bigWig coverage tracks. Used for CUT&RUN calibration where
  E. coli carry-over DNA serves as an internal standard.

requirements:
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  StepInputExpressionRequirement: {}
  SubworkflowFeatureRequirement: {}

inputs:
  fastq_fwd:
    type: File[]
    doc: "Forward read FASTQ files (trimmed)"
  fastq_rev:
    type: File[]
    doc: "Reverse read FASTQ files (trimmed)"
  bams:
    type: File[]
    doc: "Filtered, indexed BAM files for bigWig generation"
  sample_ids:
    type: string[]
    doc: "Sample identifiers"
  spikein_index_files:
    type: File[]
    doc: "Bowtie2 index files for spike-in genome"
  spikein_index_base:
    type: string
    doc: "Bowtie2 index base name for spike-in genome"

steps:
  # Align reads to spike-in genome to get read counts
  spikein_align:
    run: ../../../tools/bowtie2-spikein.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastq_fwd
      fastq_rev: fastq_rev
      spikein_index_files: spikein_index_files
      spikein_index_base: spikein_index_base
      sample_id: sample_ids
    out: [spikein_stats, spikein_log]

  # Compute scale factors from spike-in counts
  compute_scale_factors:
    run: ../../../tools/compute-spikein-scale-factors.cwl
    in:
      spikein_stats: spikein_align/spikein_stats
    out: [scale_factors_table, scale_factors_list]

  # Parse scale factors from text file into float array
  parse_scale_factors:
    run:
      class: ExpressionTool
      cwlVersion: v1.2
      requirements:
        InlineJavascriptRequirement: {}
      inputs:
        scale_factors_file:
          type: File
          loadContents: true
      outputs:
        scale_factors:
          type: float[]
      expression: |
        ${
          var lines = inputs.scale_factors_file.contents.trim().split('\n');
          var factors = [];
          for (var i = 0; i < lines.length; i++) {
            var val = parseFloat(lines[i].trim());
            if (!isNaN(val)) {
              factors.push(val);
            }
          }
          return {"scale_factors": factors};
        }
    in:
      scale_factors_file: compute_scale_factors/scale_factors_list
    out: [scale_factors]

  # Generate scaled bigWig coverage tracks
  scaled_bamcoverage:
    run: ../../../tools/deeptools-bamcoverage-scaled.cwl
    scatter: [bam, sample_id, scale_factor]
    scatterMethod: dotproduct
    in:
      bam: bams
      sample_id: sample_ids
      scale_factor: parse_scale_factors/scale_factors
    out: [scaled_bigwig]

outputs:
  scaled_bigwigs:
    type: File[]
    outputSource: scaled_bamcoverage/scaled_bigwig
    doc: "Spike-in normalized bigWig coverage tracks"
  spikein_stats:
    type: File[]
    outputSource: spikein_align/spikein_stats
    doc: "Spike-in alignment count stats"
  spikein_logs:
    type: File[]
    outputSource: spikein_align/spikein_log
    doc: "Spike-in alignment logs"
  scale_factors_table:
    type: File
    outputSource: compute_scale_factors/scale_factors_table
    doc: "Table of spike-in counts and scale factors per sample"
