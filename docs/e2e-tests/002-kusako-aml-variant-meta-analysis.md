# E2E Test 002: Kusako — Cross-Project AML Variant Meta-Analysis

> **Test type:** End-to-end agent scenario
> **Workflows:** fetchngs → sarek
> **Organism:** *Homo sapiens* (GRCh38)
> **Data:** PRJNA358716 (118 WXS), PRJNA305214 (106 targeted panel)

## Scenario

Kusako is now in her second semester. After the yeast RNA-seq project went well, her advisor asks her to help a collaborator in the medical school. The collaborator studies *TP53* mutations in acute myeloid leukemia (AML) and wants to know: does the *TP53* mutation landscape look consistent across independently published exome datasets, or does each cohort show different variant patterns?

Kusako needs to find whole-exome sequencing data from AML patients across multiple public studies, run variant calling on each, and check whether *TP53* variants appear consistently.

## Prompt

```
My advisor's collaborator studies TP53 mutations in acute myeloid leukemia.
They want to compare whole exome sequencing data from AML tumor samples
across different published studies to see if the TP53 mutation patterns
are consistent. Can you find WES data from AML patients in public
repositories — ideally from at least 2 different projects — and run
variant calling?
```

## Expected Agent Behavior

### Step 1: Understand the request

This is a cross-project meta-analysis: find AML WXS data from multiple independent studies, call variants, and compare a specific locus (TP53). Kusako doesn't know about CWL, WES, or variant calling pipelines.

### Step 2: Read AGENTS.md

Discover sarek (germline + somatic variant calling) and fetchngs. Note the WES submission protocol.

### Step 3: Find the data

Read `docs/data-discovery.md`, then search ENA:

1. **First attempt — `disease` field:**
   ```
   GET https://www.ebi.ac.uk/ena/portal/api/search?
     query=tax_tree(9606) AND library_strategy="WXS" AND disease="acute myeloid leukemia"
     &result=read_run&fields=run_accession,study_accession,...
   ```
   Returns empty — `disease` field is rarely populated in ENA.

2. **Fall back to `experiment_title` keyword search:**
   ```
   GET https://www.ebi.ac.uk/ena/portal/api/search?
     query=tax_tree(9606) AND library_strategy="WXS" AND experiment_title="*myeloid*"
     &result=read_run&fields=run_accession,study_accession,read_count,experiment_title
   ```
   Finds multiple projects including:
   - **PRJNA358716** — "WXS of homo sapiens: acute myeloid leukemia"
   - **PRJNA305214** — "Profiling of somatic mutations in acute myeloid leukemia with FLT3-ITD"
   - **PRJNA1282068** — "TruSight Myeloid Sequencing Panel" (targeted panel, not WXS)

3. **Assess data quality per project:**
   - PRJNA358716: 118 runs, 8M–141M reads/sample (median ~45M) — genuine WXS
   - PRJNA305214: 106 runs, 115K–7M reads/sample — too low for WXS, likely targeted panel or amplicon despite WXS tag
   - PRJNA1282068: 7 runs, explicitly named as panel sequencing

4. **Present findings to Kusako:**
   - Explain that PRJNA358716 has 118 genuine WXS samples at good coverage
   - Flag that PRJNA305214 has much lower read counts — may be targeted panel mislabeled as WXS, which would affect variant calling sensitivity
   - Recommend using both but noting the coverage difference, or focusing on PRJNA358716 for reliable WXS analysis
   - Ask Kusako to confirm

### Step 4: Fetch raw data

Read `workflows/fetchngs/agent.yaml`:
- Submit fetchngs with all confirmed SRA accessions
- For 118 + 106 = 224 runs, this is a large download (~2.3 Tb total)
- Poll until complete
- Retrieve FASTQ output paths

### Step 5: Resolve references

Read `references/README.md` + `references/genomes.yaml`:
- Look up *Homo sapiens* GRCh38 (Tier 1 in catalog)
- Workflow-to-index mapping: sarek needs genome FASTA + FAI + BWA-MEM2 index + known sites VCF
- iGenomes has BWA-MEM2 index at `s3://ngi-igenomes/igenomes/Homo_sapiens/GATK/GRCh38/Sequence/BWAmem2Index/`
- Known sites VCF (dbSNP, Mills indels) needed for BQSR — agent needs to locate these from GATK resource bundle or similar
- Download indices via `aws s3 cp --no-sign-request`

### Step 6: Run variant calling

Read `workflows/sarek/agent.yaml`:
- Prepare inputs: FASTQs + genome FASTA + BWA-MEM2 index + known sites
- For WES data, provide target intervals BED if available
- Submit sarek to WES for each sample (or batched)
- Poll until complete
- Retrieve per-sample VCFs

### Step 7: Retrieve provenance

`GET /runs/{run_id}/ro-crate` for all workflow runs.

### Step 8: Present results

- Extract TP53 region variants (chr17:7,668,421–7,687,490 on GRCh38) from each VCF
- Tabulate: which TP53 variants appear in which samples, from which project
- Summarize: are certain TP53 hotspot mutations (R175H, R248W, R273H, etc.) recurrent across both cohorts?
- Note any differences in variant detection between the high-coverage (PRJNA358716) and low-coverage (PRJNA305214) datasets
- Explain results in accessible terms for Kusako

## Verified Data Path

| Step | Input | Method | Output | Verified |
|------|-------|--------|--------|----------|
| ENA search (disease) | tax_tree=9606, WXS, disease=AML | ENA Portal API | Empty result | Yes |
| ENA search (title) | tax_tree=9606, WXS, title=*myeloid* | ENA Portal API | 3 projects found | Yes |
| Project 1 details | PRJNA358716 | ENA Portal API | 118 runs, 2.28 Tb, genuine WXS | Yes |
| Project 2 details | PRJNA305214 | ENA Portal API | 106 runs, 57.4 Gb, targeted panel | Yes |
| Genome lookup | *Homo sapiens* | references/genomes.yaml | GRCh38, Ensembl 115, Tier 1 | Yes |
| BWA-MEM2 index | GRCh38 | iGenomes S3 | Available | Yes |

## Dataset Summary

### PRJNA358716 — AML Whole Exome Sequencing

- **Study:** Whole exome sequencing of acute myeloid leukemia samples
- **Samples:** 118 runs
- **Total data:** 2,281,449,697,775 bases (~2.28 Tb)
- **Read counts:** 7.8M – 140.9M per sample (median ~45M)
- **Sequencing:** Illumina HiSeq 2000, paired-end, 100 bp
- **Data quality:** Genuine WXS with good coverage

<details>
<summary>All 118 run accessions</summary>

SRR5128960, SRR5128961, SRR5128962, SRR5128963, SRR5128964, SRR5128965,
SRR5128966, SRR5128967, SRR5128968, SRR5128969, SRR5128970, SRR5128971,
SRR5128972, SRR5128973, SRR5128974, SRR5128975, SRR5128976, SRR5128977,
SRR5128978, SRR5128979, SRR5128980, SRR5128981, SRR5128982, SRR5128983,
SRR5128984, SRR5128985, SRR5128986, SRR5128987, SRR5128988, SRR5128989,
SRR5128990, SRR5128991, SRR5128992, SRR5128993, SRR5128994, SRR5128995,
SRR5128996, SRR5128997, SRR5128998, SRR5128999, SRR5129000, SRR5129001,
SRR5129002, SRR5129003, SRR5129004, SRR5129005, SRR5129006, SRR5129007,
SRR5129008, SRR5129009, SRR5129010, SRR5129011, SRR5129012, SRR5129013,
SRR5129014, SRR5129015, SRR5129016, SRR5129017, SRR5129018, SRR5129019,
SRR5129020, SRR5129021, SRR5129022, SRR5129023, SRR5129024, SRR5129025,
SRR5129026, SRR5129027, SRR5129028, SRR5129029, SRR5129030, SRR5129031,
SRR5129032, SRR5129033, SRR5129034, SRR5129035, SRR5129036, SRR5129037,
SRR5129038, SRR5129039, SRR5129040, SRR5129041, SRR5129044, SRR5129045,
SRR5129046, SRR5129048, SRR5129049, SRR5129050, SRR5129051, SRR5129053,
SRR5129054, SRR5129055, SRR5129058, SRR5129059, SRR5129060, SRR5129061,
SRR5129062, SRR5129065, SRR5129066, SRR5129067

</details>

### PRJNA305214 — AML FLT3-ITD Somatic Mutation Profiling

- **Study:** Profiling of somatic mutations in AML with FLT3-ITD at diagnosis and relapse
- **Samples:** 106 runs
- **Total data:** 57,381,693,420 bases (~57.4 Gb)
- **Read counts:** 115K – 6.8M per sample (median ~500K)
- **Sequencing:** Illumina HiSeq 2000, paired-end
- **Data quality:** Very low read counts — likely targeted panel or amplicon sequencing mislabeled as WXS. Agent should flag this quality issue to the user.

## Benchmark Profile

This is a compute-intensive benchmark. Expected resource requirements:

| Phase | Data Volume | Estimate |
|-------|------------|----------|
| fetchngs download | ~2.3 Tb FASTQ | Depends on network bandwidth |
| BWA-MEM2 alignment | 224 samples × GRCh38 | ~1–2 hours/sample (8 cores) |
| HaplotypeCaller | 224 samples | ~1–3 hours/sample (8 cores) |
| Total compute | | ~500–1000 CPU-hours |
| Storage | FASTQs + BAMs + VCFs | ~5–10 Tb |

**Record actual timings when running the benchmark to calibrate future estimates.**

## Success Criteria

- [ ] Agent searches ENA and discovers the `disease` field is empty
- [ ] Agent falls back to `experiment_title` keyword search and finds multiple AML projects
- [ ] Agent identifies data quality difference between projects (WXS vs targeted panel)
- [ ] Agent presents findings and asks Kusako to confirm sample selection
- [ ] fetchngs completes for all selected samples
- [ ] Human GRCh38 reference resolved from genomes.yaml (FASTA + BWA-MEM2 index)
- [ ] Agent locates known sites VCF for BQSR
- [ ] sarek completes with variant calls for all samples
- [ ] Agent extracts TP53 variants and compares across projects
- [ ] RO-Crate retrieved and valid for all workflow runs

## Key Differences from Test 001

| Aspect | Test 001 (Yeast RNA-seq) | Test 002 (AML Variants) |
|--------|--------------------------|------------------------|
| Entry point | Paper PMID → PMC text mining | Direct ENA keyword search |
| Data discovery | Single project, ID conversion | Cross-project, metadata quality issue |
| Challenge | Extracting IDs from paper text | Empty metadata fields, mislabeled data |
| Workflow | fetchngs → rnaseq | fetchngs → sarek |
| Organism | Yeast (12 Mb genome) | Human (3.1 Gb genome) |
| Scale | 2–24 samples, ~minutes | 224 samples, ~days |
| Reference | STAR index | BWA-MEM2 index + known sites VCF |
| Output | Gene expression counts | Variant calls (VCF) |
| Compute | Light | Heavy benchmark |
