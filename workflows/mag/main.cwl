#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: "mag - Metagenome-Assembled Genomes pipeline"
doc: |
  Metagenome assembly and binning pipeline. Performs QC, trimming,
  optional host read removal, assembly with SPAdes, contig binning with
  MetaBAT2, optional MaxBin2 binning, optional bin refinement with DAS Tool,
  optional bin quality assessment with BUSCO, optional taxonomic classification
  with GTDB-Tk, optional functional annotation with Prokka, gene prediction
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

  # === Host filtering options ===
  host_index_files:
    type: File[]?
    doc: "Bowtie2 index files for host genome (omit to skip host read removal)"

  host_index_base:
    type: string?
    doc: "Bowtie2 index base name for host genome"

  # === Assembly parameters ===
  min_contig_len:
    type: int?
    default: 1000
    doc: "Minimum contig length for assembly output"

  # === Post-binning options ===
  run_das_tool:
    type: boolean?
    default: false
    doc: "Run DAS Tool for bin refinement"

  run_maxbin2:
    type: boolean?
    default: false
    doc: "Run MaxBin2 as an alternative binner"

  run_prokka:
    type: boolean?
    default: false
    doc: "Run Prokka for bin functional annotation"

  busco_lineage:
    type: string?
    doc: "BUSCO lineage dataset for bin QC (e.g., bacteria_odb10). Omit to skip BUSCO."

  gtdbtk_db:
    type: Directory?
    doc: "GTDB-Tk reference database directory. Omit to skip taxonomic classification."

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
  # Host read removal with Bowtie2 (conditional, per sample)
  # =====================
  host_filter:
    run: ../../tools/bowtie2-host-filter.cwl
    when: $(inputs.host_index_files != null && inputs.host_index_base != null)
    scatter: [fastq_fwd, fastq_rev, sample_id]
    scatterMethod: dotproduct
    in:
      fastq_fwd: fastp/trimmed_fwd
      fastq_rev: fastp/trimmed_rev
      host_index_files: host_index_files
      host_index_base: host_index_base
      sample_id: sample_ids
    out: [filtered_fwd, filtered_rev, log]

  # =====================
  # Select reads for assembly (filtered or trimmed)
  # =====================
  select_reads:
    run:
      class: ExpressionTool
      requirements:
        InlineJavascriptRequirement: {}
      inputs:
        filtered_fwd:
          type:
            - "null"
            - type: array
              items: File
        filtered_rev:
          type:
            - "null"
            - type: array
              items: File
        trimmed_fwd:
          type: File[]
        trimmed_rev:
          type: File[]
      outputs:
        fwd:
          type: File[]
        rev:
          type: File[]
      expression: |
        ${
          if (inputs.filtered_fwd !== null && Array.isArray(inputs.filtered_fwd) && inputs.filtered_fwd.length > 0 && inputs.filtered_fwd[0] !== null) {
            return {fwd: inputs.filtered_fwd, rev: inputs.filtered_rev};
          }
          return {fwd: inputs.trimmed_fwd, rev: inputs.trimmed_rev};
        }
    in:
      filtered_fwd: host_filter/filtered_fwd
      filtered_rev: host_filter/filtered_rev
      trimmed_fwd: fastp/trimmed_fwd
      trimmed_rev: fastp/trimmed_rev
    out: [fwd, rev]

  # =====================
  # Metagenome assembly (co-assembly)
  # =====================
  assembly:
    run: ../../tools/spades.cwl
    in:
      fastq_fwd: select_reads/fwd
      fastq_rev: select_reads/rev
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
      fastq_fwd: select_reads/fwd
      fastq_rev: select_reads/rev
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
  # MaxBin2 binning (conditional)
  # =====================
  maxbin2:
    run: ../../tools/maxbin2.cwl
    when: $(inputs.run_maxbin2 == true)
    in:
      contigs: assembly/contigs
      abundance_file: metabat2/depth_file
      sample_id:
        default: "maxbin2"
      run_maxbin2: run_maxbin2
    out: [bins, summary]

  # =====================
  # Prepare DAS Tool input (combine binners when both available)
  # =====================
  prepare_das_tool_input:
    run:
      class: ExpressionTool
      requirements:
        InlineJavascriptRequirement: {}
      inputs:
        metabat2_bins:
          type: File[]
        maxbin2_bins:
          type:
            - "null"
            - type: array
              items: File
        run_das_tool:
          type: boolean?
      outputs:
        all_bins:
          type: File[]
        labels:
          type: string
      expression: |
        ${
          var all_bins = inputs.metabat2_bins.slice();
          var labels = "metabat2";
          if (inputs.maxbin2_bins !== null && Array.isArray(inputs.maxbin2_bins) && inputs.maxbin2_bins.length > 0 && inputs.maxbin2_bins[0] !== null) {
            all_bins = all_bins.concat(inputs.maxbin2_bins);
            labels = "metabat2,maxbin2";
          }
          return {all_bins: all_bins, labels: labels};
        }
    in:
      metabat2_bins: metabat2/bins
      maxbin2_bins: maxbin2/bins
      run_das_tool: run_das_tool
    out: [all_bins, labels]

  # =====================
  # DAS Tool bin refinement (conditional)
  # =====================
  das_tool:
    run: ../../tools/das-tool.cwl
    when: $(inputs.run_das_tool == true)
    in:
      contigs: assembly/contigs
      bins: prepare_das_tool_input/all_bins
      sample_id:
        default: "das_tool"
      run_das_tool: run_das_tool
    out: [refined_bins, summary, log]

  # =====================
  # Select bins (refined or original)
  # =====================
  select_bins:
    run:
      class: ExpressionTool
      requirements:
        InlineJavascriptRequirement: {}
      inputs:
        das_tool_bins:
          type:
            - "null"
            - type: array
              items: File
        metabat2_bins:
          type: File[]
      outputs:
        bins:
          type: File[]
      expression: |
        ${
          var bins = inputs.das_tool_bins;
          if (bins !== null && Array.isArray(bins) && bins.length > 0 && bins[0] !== null) {
            return {bins: bins};
          }
          return {bins: inputs.metabat2_bins};
        }
    in:
      das_tool_bins: das_tool/refined_bins
      metabat2_bins: metabat2/bins
    out: [bins]

  # =====================
  # BUSCO bin quality assessment (conditional)
  # =====================
  busco_qc:
    run: steps/busco-bins.cwl
    when: $(inputs.busco_lineage != null)
    in:
      bins: select_bins/bins
      lineage: busco_lineage
      busco_lineage: busco_lineage
    out: [summaries]

  # =====================
  # GTDB-Tk taxonomic classification (conditional)
  # =====================
  gtdbtk_classify:
    run: steps/gtdbtk-bins.cwl
    when: $(inputs.gtdbtk_db != null)
    in:
      bins: select_bins/bins
      gtdbtk_db: gtdbtk_db
    out: [classification, bac120_summary, ar53_summary]

  # =====================
  # Prokka bin annotation (conditional)
  # =====================
  prokka_annotate:
    run: steps/prokka-bins.cwl
    when: $(inputs.run_prokka == true)
    in:
      bins: select_bins/bins
      run_prokka: run_prokka
    out: [gff_files, faa_files, gbk_files]

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

  refined_bins:
    type: File[]?
    outputSource: das_tool/refined_bins
    doc: "DAS Tool refined genome bins (when run_das_tool=true)"

  das_tool_summary:
    type: File?
    outputSource: das_tool/summary
    doc: "DAS Tool bin scoring summary (when run_das_tool=true)"

  maxbin2_bins:
    type: File[]?
    outputSource: maxbin2/bins
    doc: "MaxBin2 genome bins (when run_maxbin2=true)"

  maxbin2_summary:
    type: File?
    outputSource: maxbin2/summary
    doc: "MaxBin2 binning summary (when run_maxbin2=true)"

  busco_summaries:
    type: File[]?
    outputSource: busco_qc/summaries
    doc: "BUSCO completeness summaries per bin (when busco_lineage is set)"

  gtdbtk_classification:
    type: File?
    outputSource: gtdbtk_classify/classification
    doc: "GTDB-Tk taxonomic classification summary (when gtdbtk_db is provided)"

  gtdbtk_bac120_summary:
    type: File?
    outputSource: gtdbtk_classify/bac120_summary
    doc: "GTDB-Tk bacterial classification (when gtdbtk_db is provided)"

  gtdbtk_ar53_summary:
    type: File?
    outputSource: gtdbtk_classify/ar53_summary
    doc: "GTDB-Tk archaeal classification (when gtdbtk_db is provided)"

  prokka_gff:
    type: File[]?
    outputSource: prokka_annotate/gff_files
    doc: "Prokka GFF annotations per bin (when run_prokka=true)"

  prokka_faa:
    type: File[]?
    outputSource: prokka_annotate/faa_files
    doc: "Prokka protein sequences per bin (when run_prokka=true)"

  prokka_gbk:
    type: File[]?
    outputSource: prokka_annotate/gbk_files
    doc: "Prokka GenBank annotations per bin (when run_prokka=true)"

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
