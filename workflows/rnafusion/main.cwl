#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "rnafusion - Gene fusion detection pipeline"
doc: |
  Gene fusion detection from RNA-seq data using STAR alignment with
  chimeric detection and Arriba fusion calling. Optional callers include
  STAR-Fusion and FusionCatcher. Post-processing validation with
  FusionInspector and Arriba visualization are also available.

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

  # === Reference ===
  star_index:
    type: Directory
    doc: "STAR genome index directory"

  reference_fasta:
    type: File
    doc: "Reference genome FASTA"

  gtf:
    type: File
    doc: "Gene annotation GTF file"

  # === Optional Arriba databases ===
  arriba_blacklist:
    type: File?
    doc: "Arriba blacklist of recurrent artifacts"

  arriba_known_fusions:
    type: File?
    doc: "Arriba known fusions for boosting sensitivity"

  arriba_protein_domains:
    type: File?
    doc: "Arriba protein domain annotation (GFF3)"

  # === STAR-Fusion ===
  run_star_fusion:
    type: boolean?
    default: false
    doc: "Run STAR-Fusion fusion caller on chimeric junctions"

  ctat_lib:
    type: Directory?
    doc: "CTAT genome library directory (required for STAR-Fusion and FusionInspector)"

  # === FusionCatcher ===
  run_fusioncatcher:
    type: boolean?
    default: false
    doc: "Run FusionCatcher fusion caller"

  fusioncatcher_db:
    type: Directory?
    doc: "FusionCatcher data directory (required for FusionCatcher)"

  # === FusionInspector ===
  run_fusion_inspector:
    type: boolean?
    default: false
    doc: "Run FusionInspector for post-processing validation of fusions"

  # === Arriba visualization ===
  run_arriba_viz:
    type: boolean?
    default: false
    doc: "Generate Arriba fusion visualization PDFs"

  arriba_cytobands:
    type: File?
    doc: "Cytoband annotation TSV for Arriba visualization"

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
  # STAR alignment with chimeric detection (per sample)
  # =====================
  star:
    run: ../../tools/star-align-fusion.cwl
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      sample_id: sample_ids
      index_dir: star_index
    out: [aligned_bam, log_final, log, splice_junctions, chimeric_junctions]

  # =====================
  # Arriba fusion detection (per sample)
  # =====================
  arriba:
    run: ../../tools/arriba.cwl
    scatter: [bam, prefix]
    scatterMethod: dotproduct
    in:
      bam: star/aligned_bam
      assembly: reference_fasta
      gtf: gtf
      blacklist: arriba_blacklist
      known_fusions: arriba_known_fusions
      protein_domains: arriba_protein_domains
      prefix: sample_ids
    out: [fusions, discarded_fusions]

  # =====================
  # samtools index (per sample, for BAM output)
  # =====================
  samtools_index:
    run: ../../tools/samtools-index.cwl
    scatter: sorted_bam
    in:
      sorted_bam: star/aligned_bam
    out: [indexed_bam]

  # =====================
  # STAR-Fusion (conditional)
  # =====================
  star_fusion:
    run: steps/star-fusion.cwl
    when: $(inputs.run_star_fusion == true && inputs.ctat_lib != null)
    in:
      chimeric_junctions: star/chimeric_junctions
      ctat_lib: ctat_lib
      sample_ids: sample_ids
      run_star_fusion: run_star_fusion
    out: [fusion_predictions, fusion_predictions_abridged]

  # =====================
  # FusionCatcher (conditional)
  # =====================
  fusioncatcher:
    run: steps/fusioncatcher.cwl
    when: $(inputs.run_fusioncatcher == true && inputs.fusioncatcher_db != null)
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      fusioncatcher_db: fusioncatcher_db
      sample_ids: sample_ids
      run_fusioncatcher: run_fusioncatcher
    out: [final_fusions, summaries]

  # =====================
  # FusionInspector (conditional)
  # =====================
  fusion_inspector:
    run: steps/fusion-inspector.cwl
    when: $(inputs.run_fusion_inspector == true && inputs.ctat_lib != null)
    in:
      fusions_files: arriba/fusions
      ctat_lib: ctat_lib
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      sample_ids: sample_ids
      run_fusion_inspector: run_fusion_inspector
    out: [validated_fusions, evidence_bams]

  # =====================
  # Arriba visualization (conditional)
  # =====================
  arriba_visualization:
    run: steps/arriba-visualization.cwl
    when: $(inputs.run_arriba_viz == true)
    in:
      fusions_tsvs: arriba/fusions
      bams: samtools_index/indexed_bam
      gtf: gtf
      sample_ids: sample_ids
      cytobands: arriba_cytobands
      run_arriba_viz: run_arriba_viz
    out: [fusions_pdfs]

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
          - star/log_final
        linkMerge: merge_flattened
        pickValue: all_non_null
      title:
        default: "pa-cwl rnafusion"
    out: [html_report, data_dir]

outputs:
  fusions:
    type: File[]
    outputSource: arriba/fusions
    doc: "Arriba gene fusion calls per sample"

  discarded_fusions:
    type: File[]
    outputSource: arriba/discarded_fusions
    doc: "Discarded fusion candidates per sample"

  aligned_bams:
    type: File[]
    outputSource: samtools_index/indexed_bam
    doc: "STAR-aligned BAMs with chimeric reads"

  multiqc_report:
    type: File
    outputSource: multiqc/html_report
    doc: "MultiQC HTML report"

  # === STAR-Fusion outputs ===
  star_fusion_predictions:
    type: File[]?
    outputSource: star_fusion/fusion_predictions
    doc: "STAR-Fusion predicted gene fusions (when run_star_fusion=true)"

  star_fusion_predictions_abridged:
    type: File[]?
    outputSource: star_fusion/fusion_predictions_abridged
    doc: "Abridged STAR-Fusion predictions (when run_star_fusion=true)"

  # === FusionCatcher outputs ===
  fusioncatcher_fusions:
    type: File[]?
    outputSource: fusioncatcher/final_fusions
    doc: "FusionCatcher final fusion candidates (when run_fusioncatcher=true)"

  fusioncatcher_summaries:
    type: File[]?
    outputSource: fusioncatcher/summaries
    doc: "FusionCatcher fusion summaries (when run_fusioncatcher=true)"

  # === FusionInspector outputs ===
  validated_fusions:
    type: File[]?
    outputSource: fusion_inspector/validated_fusions
    doc: "FusionInspector validated fusions (when run_fusion_inspector=true)"

  fusion_evidence_bams:
    type: File[]?
    outputSource: fusion_inspector/evidence_bams
    doc: "FusionInspector evidence BAMs (when run_fusion_inspector=true)"

  # === Arriba visualization outputs ===
  arriba_fusion_plots:
    type: File[]?
    outputSource: arriba_visualization/fusions_pdfs
    doc: "Arriba fusion visualization PDFs (when run_arriba_viz=true)"
