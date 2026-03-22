#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "QIIME2 diversity - Alpha and beta diversity analysis"
doc: |
  Import DADA2 outputs into QIIME2 format and compute alpha/beta diversity
  metrics. Imports the ASV count table (biom) and representative sequences,
  builds a phylogenetic tree, and runs core-metrics-phylogenetic for
  comprehensive diversity analysis.

requirements:
  ResourceRequirement:
    coresMin: 4
    ramMin: 8192
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entryname: run_qiime2_diversity.sh
        entry: |
          #!/bin/bash
          set -euo pipefail

          ASV_TABLE="$1"
          REP_SEQS="$2"
          SAMPLING_DEPTH="$3"
          THREADS="$4"

          echo "=== QIIME2 Diversity Analysis ==="

          # --- Step 1: Convert ASV count CSV to BIOM format ---
          echo "Converting ASV table to BIOM format..."

          # The DADA2 CSV has samples as rows, ASV sequences as columns
          # We need to convert to a BIOM-compatible TSV (features as rows, samples as cols)
          python3 -c "
          import csv, sys

          with open('${ASV_TABLE}', 'r') as f:
              reader = csv.reader(f)
              header = next(reader)
              # header[0] is empty or row label, rest are ASV sequences
              sample_ids = []
              data = []
              for row in reader:
                  sample_ids.append(row[0])
                  data.append([int(float(x)) for x in row[1:]])

          asv_seqs = header[1:]
          n_asvs = len(asv_seqs)
          n_samples = len(sample_ids)

          # Write feature table TSV (BIOM classic format)
          with open('feature_table.tsv', 'w') as out:
              out.write('# Constructed from DADA2 output\n')
              out.write('#OTU ID\t' + '\t'.join(sample_ids) + '\n')
              for j in range(n_asvs):
                  asv_id = 'ASV' + str(j + 1)
                  counts = [str(data[i][j]) for i in range(n_samples)]
                  out.write(asv_id + '\t' + '\t'.join(counts) + '\n')

          print(f'Converted {n_asvs} ASVs x {n_samples} samples')
          "

          biom convert \
            -i feature_table.tsv \
            -o feature_table.biom \
            --table-type="OTU table" \
            --to-hdf5

          # --- Step 2: Rewrite rep seqs with ASV IDs matching the table ---
          echo "Preparing representative sequences..."
          python3 -c "
          asv_id = 0
          with open('${REP_SEQS}', 'r') as f, open('rep_seqs_renamed.fasta', 'w') as out:
              for line in f:
                  if line.startswith('>'):
                      asv_id += 1
                      out.write('>ASV' + str(asv_id) + '\n')
                  else:
                      out.write(line)
          print(f'Wrote {asv_id} representative sequences')
          "

          # --- Step 3: Import into QIIME2 artifacts ---
          echo "Importing feature table into QIIME2..."
          qiime tools import \
            --input-path feature_table.biom \
            --type 'FeatureTable[Frequency]' \
            --input-format BIOMV210Format \
            --output-path table.qza

          echo "Importing representative sequences into QIIME2..."
          qiime tools import \
            --input-path rep_seqs_renamed.fasta \
            --type 'FeatureData[Sequence]' \
            --output-path rep-seqs.qza

          # --- Step 4: Build phylogenetic tree ---
          echo "Building phylogenetic tree..."
          qiime phylogeny align-to-tree-mafft-fasttree \
            --i-sequences rep-seqs.qza \
            --o-alignment aligned-rep-seqs.qza \
            --o-masked-alignment masked-aligned-rep-seqs.qza \
            --o-tree unrooted-tree.qza \
            --o-rooted-tree rooted-tree.qza \
            --p-n-threads "$THREADS"

          # --- Step 5: Run core-metrics-phylogenetic ---
          echo "Running core diversity metrics at sampling depth ${SAMPLING_DEPTH}..."
          qiime diversity core-metrics-phylogenetic \
            --i-phylogeny rooted-tree.qza \
            --i-table table.qza \
            --p-sampling-depth "$SAMPLING_DEPTH" \
            --p-n-jobs-or-threads "$THREADS" \
            --output-dir core-metrics-results

          # --- Step 6: Export key results ---
          echo "Exporting results..."
          mkdir -p diversity_output

          # Alpha diversity - Shannon
          qiime tools export \
            --input-path core-metrics-results/shannon_vector.qza \
            --output-path diversity_output/shannon
          cp diversity_output/shannon/alpha-diversity.tsv diversity_output/shannon_diversity.tsv

          # Alpha diversity - Observed features
          qiime tools export \
            --input-path core-metrics-results/observed_features_vector.qza \
            --output-path diversity_output/observed_features
          cp diversity_output/observed_features/alpha-diversity.tsv diversity_output/observed_features.tsv

          # Beta diversity - Bray-Curtis
          qiime tools export \
            --input-path core-metrics-results/bray_curtis_distance_matrix.qza \
            --output-path diversity_output/bray_curtis

          # Beta diversity - Unweighted UniFrac
          qiime tools export \
            --input-path core-metrics-results/unweighted_unifrac_distance_matrix.qza \
            --output-path diversity_output/unweighted_unifrac

          # Emperor plots (PCoA)
          qiime tools export \
            --input-path core-metrics-results/bray_curtis_emperor.qzv \
            --output-path diversity_output/emperor_bray_curtis
          qiime tools export \
            --input-path core-metrics-results/unweighted_unifrac_emperor.qzv \
            --output-path diversity_output/emperor_unweighted_unifrac

          echo "=== QIIME2 Diversity Analysis Complete ==="

hints:
  DockerRequirement:
    dockerPull: "quay.io/qiime2/amplicon:2024.10"

baseCommand: [bash, run_qiime2_diversity.sh]

inputs:
  asv_table:
    type: File
    doc: "ASV count table in CSV format (from DADA2 denoise)"

  rep_seqs:
    type: File
    doc: "Representative ASV sequences FASTA (from DADA2 denoise)"

  sampling_depth:
    type: int
    doc: "Rarefaction sampling depth for diversity metrics"

arguments:
  - position: 1
    valueFrom: $(inputs.asv_table.path)
  - position: 2
    valueFrom: $(inputs.rep_seqs.path)
  - position: 3
    valueFrom: $(inputs.sampling_depth)
  - position: 4
    valueFrom: $(runtime.cores)

outputs:
  shannon_diversity:
    type: File
    outputBinding:
      glob: "diversity_output/shannon_diversity.tsv"
    doc: "Shannon alpha diversity per sample"

  observed_features:
    type: File
    outputBinding:
      glob: "diversity_output/observed_features.tsv"
    doc: "Observed features (richness) per sample"

  bray_curtis:
    type: Directory
    outputBinding:
      glob: "diversity_output/bray_curtis"
    doc: "Bray-Curtis beta diversity distance matrix"

  unweighted_unifrac:
    type: Directory
    outputBinding:
      glob: "diversity_output/unweighted_unifrac"
    doc: "Unweighted UniFrac beta diversity distance matrix"

  emperor_plots:
    type: Directory
    outputBinding:
      glob: "diversity_output/emperor_bray_curtis"
    doc: "Emperor PCoA plots (Bray-Curtis)"

  emperor_unifrac_plots:
    type: Directory
    outputBinding:
      glob: "diversity_output/emperor_unweighted_unifrac"
    doc: "Emperor PCoA plots (Unweighted UniFrac)"
