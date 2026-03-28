# E2E Test 001: Kusako — Yeast Heat Shock RNA-seq Reanalysis

> **Test type:** End-to-end agent scenario
> **Workflows:** fetchngs → rnaseq
> **Organism:** *Saccharomyces cerevisiae* (R64-1-1)
> **Data:** GSE135568 (PMID: 32109230)

## Scenario

Kusako is an undergraduate biology student working on a thesis about nutrient signaling in *Saccharomyces cerevisiae*. Her lab studies the TOR pathway, and she's interested in how TOR-regulated genes (e.g., *GAP1*, *MEP2*, *DAL5* — nitrogen permease genes) respond under heat shock. She found a paper about yeast heat shock transcriptomics, but the paper focuses on the RNA binding protein Mip6 and histone modifications — her target genes aren't discussed at all.

She wants to reanalyze the same RNA-seq data to look at expression of her specific gene set. She has Claude Code but no bioinformatics experience.

## Prompt

```
I'm studying TOR pathway genes in yeast for my thesis. I found this paper about
heat shock response (PMID: 32109230) that has RNA-seq data — they looked at Mip6
and histone modifications but I want to check what happens to nitrogen permease
genes like GAP1, MEP2, and DAL5 under the same conditions. Can you get the data
and run the analysis for me?
```

## Expected Agent Behavior

### Step 1: Understand the request

This is a secondary analysis: reuse published RNA-seq data to answer a different biological question. The student doesn't know about workflows, WES, or CWL — the agent handles everything.

### Step 2: Read AGENTS.md

Discover available workflows, the WES submission protocol, and provenance requirements.

### Step 3: Find the data

Read `docs/data-discovery.md`, then:

1. Try TogoID: PMID 32109230 → SRA run accessions (no direct route exists)
2. **Fall back to PMC full text**: fetch the paper via Europe PMC or NCBI E-utilities
   - Paper: "A multi-omics dataset of heat-shock response in the yeast RNA binding protein Mip6" (PMC7046740)
   - Scan Data Availability / Data Records section for archive identifiers
   - Find: **GSE135568** (GEO series accession)
3. Use TogoID to convert identifiers:
   - `GET https://api.togoid.dbcls.jp/convert?ids=GSE135568&route=geo_series,bioproject&format=json`
   - Result: **PRJNA559331**
   - `GET https://api.togoid.dbcls.jp/convert?ids=PRJNA559331&route=bioproject,sra_run&format=json`
   - Result: 67 SRA run accessions (SRR9929263–SRR9929329)
4. Filter for RNA-seq only (the dataset also contains ChIP-seq):
   - Query ENA: `study_accession="PRJNA559331"` with `library_strategy` field
   - 24 RNA-seq runs, 36 ChIP-seq runs — select only RNA-seq
5. Present the accessions to Kusako with metadata:
   - Organism: *S. cerevisiae* BY4741
   - Conditions: wild-type vs mip6Δ, 30°C vs 39°C (20 min and 120 min heat shock)
   - Library: paired-end, Illumina HiSeq 2000
   - Ask which samples she needs (all 24, or a subset for her comparison)

### Step 4: Fetch raw data

Read `workflows/fetchngs/agent.yaml`:
- Prepare input YAML with confirmed SRA accessions
- Submit fetchngs to WES, poll until complete
- Retrieve FASTQ output paths

**For testing:** Use a subset of 2–4 samples to keep runtime short (e.g., 1 wild-type 30°C + 1 wild-type 39°C).

### Step 5: Resolve references

Read `references/README.md` + `references/genomes.yaml`:
- Look up *S. cerevisiae* R64-1-1 (Tier 1 in catalog)
- rnaseq needs: genome FASTA + GTF + STAR index
- Check iGenomes: `s3://ngi-igenomes/igenomes/Saccharomyces_cerevisiae/Ensembl/R64-1-1/Sequence/STARIndex/`
- Download pre-built STAR index, OR run `prepare-references` with `build_star: true`

### Step 6: Run RNA-seq quantification

Read `workflows/rnaseq/agent.yaml`:
- Prepare inputs: FASTQs from step 4, genome FASTA + GTF + STAR index from step 5
- Select aligner: STAR (default for model organisms with good annotation)
- Submit to WES, poll until complete
- Retrieve gene-level counts and MultiQC report

### Step 7: Retrieve provenance

`GET /runs/{run_id}/ro-crate` for both fetchngs and rnaseq runs.
Save RO-Crate metadata.

### Step 8: Present results in student-friendly terms

- Extract expression levels of GAP1, MEP2, DAL5 from the gene count matrix
- Compare across conditions (30°C vs 39°C heat shock)
- Explain what the counts mean (higher = more transcripts = more active)
- Point to MultiQC report for data quality
- Note that this is raw counts, not differential expression — suggest DESeq2 as next step if she sees interesting patterns

## Verified Data Path

This test scenario has been verified end-to-end:

| Step | Input | Method | Output | Verified |
|------|-------|--------|--------|----------|
| PMC lookup | PMID 32109230 | Europe PMC / NCBI efetch | PMC7046740 (open access) | Yes |
| Text mining | PMC7046740 full text | Scan Data Records section | GSE135568 | Yes |
| ID conversion | GSE135568 | TogoID geo_series→bioproject | PRJNA559331 | Yes |
| ID conversion | PRJNA559331 | TogoID bioproject→sra_run | 67 SRR accessions | Yes |
| RNA-seq filter | 67 runs | ENA API library_strategy filter | 24 RNA-seq runs | Yes |
| Genome lookup | *S. cerevisiae* | references/genomes.yaml | R64-1-1, Ensembl 115 | Yes |
| STAR index | R64-1-1 | iGenomes S3 | Available | Yes |

## Success Criteria

- [ ] Agent fetches PMC full text and extracts GSE135568 from the paper
- [ ] Agent converts GSE135568 → PRJNA559331 → SRR accessions via TogoID
- [ ] Agent filters to RNA-seq runs only (24 of 67)
- [ ] Agent presents sample metadata and asks Kusako to confirm
- [ ] fetchngs completes and produces FASTQ files
- [ ] Yeast reference resolved from genomes.yaml without manual intervention
- [ ] rnaseq completes with STAR alignment and gene quantification
- [ ] Agent reports expression values for GAP1, MEP2, DAL5
- [ ] RO-Crate retrieved and valid for both workflow runs (Dataset + ComputationalWorkflow + CreateAction)

## Test Subset (for CI/quick validation)

For automated testing, use 2 samples to keep runtime under 30 minutes:

| Run | Condition | Genotype |
|-----|-----------|----------|
| SRR9929263 | 30°C (control) | BY4741 wild-type |
| SRR9929265 | 39°C 20 min (heat shock) | BY4741 wild-type |

These two samples provide the minimal comparison: control vs heat shock in wild-type, which is what Kusako needs to see if her target genes respond to heat stress.
