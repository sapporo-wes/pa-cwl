# Design: Data Discovery and Reference Resolution

## Date: 2026-03-27

## Context

pa-cwl has 16 production-ready CWL workflows and an agent guide (AGENTS.md), but two critical gaps prevent end-to-end researcher workflows:

1. **Data discovery** — researchers say "I want RNA-seq data for organism X" but agents have no guidance on how to find relevant SRA accessions from public repositories.
2. **Reference resolution** — researchers say "organism X" but workflows need genome FASTA, GTF, and pre-built indices. Agents have no guidance on where to get these.

## Design

### 1. Data Discovery Guide (`docs/data-discovery.md`)

An agent-readable document teaching agents how to find public sequencing data. Four search strategies, ordered by typical researcher starting point:

#### 1a. TogoID (ID conversion)

- Service: `https://togoid.dbcls.jp`
- Use case: researcher has a PubMed ID, BioSample, BioProject, or GEO accession and needs SRA run accessions
- The agent calls TogoID's API to convert between identifier types
- API format: `GET https://togoid.dbcls.jp/convert?ids={id}&route={source},{target}&format=json`
- Common conversion routes: `pubmed,bioproject,sra_run` / `biosample,sra_run` / `geo,sra_run`
- Typical flow: PubMed ID → BioProject → SRA Run accessions → `fetchngs`

#### 1b. ENA Search API (keyword/taxonomy search)

- Endpoint: `GET https://www.ebi.ac.uk/ena/portal/api/search`
- Use case: researcher wants to find datasets by organism, assay type, library strategy
- Key query fields: `tax_tree` (NCBI taxonomy ID), `library_strategy` (RNA-Seq, WGS, ChIP-Seq, etc.), `library_source`, `instrument_platform`
- Pagination: use `limit` (default 0 = unlimited, recommend 100) and `offset` for large result sets
- Filtering: narrow by `library_layout` (PAIRED/SINGLE), `base_count` (minimum data), `first_public` (date range) to keep results manageable
- Returns accession lists that feed into `fetchngs`

#### 1c. NCBI E-utilities (fallback)

- `esearch` + `efetch` against the SRA database
- Alternative when ENA doesn't have what's needed
- Document the query syntax differences from ENA

#### 1d. Future: Curated Metadata API (placeholder)

- A secondary metadata repository is in development that curates public SRA/ENA metadata using language models and maps to ontology terms
- Expected API contract: accepts taxonomy ID and library_strategy, returns ranked accession lists with ontology-annotated metadata
- When available, this will provide higher-quality search results than raw public repository APIs
- This section serves as the integration point — agents check here first, fall back to ENA/NCBI if not yet available

**Design principle:** The document teaches agents which APIs to call and how to interpret results. The agent executes the API calls directly — no wrapper code. The search backend is a documented strategy that can be swapped without changing any workflow code.

### 2. Reference Resolution (`references/`)

#### 2a. Genome Catalog (`references/genomes.yaml`)

A YAML file mapping common organisms to verified download locations.

Structure per organism:

```yaml
- organism: Homo sapiens
  taxonomy_id: 9606
  assembly: GRCh38
  ensembl_release: 112
  verified_date: "2026-03-27"
  sources:
    ensembl:
      fasta: https://ftp.ensembl.org/pub/release-112/.../Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
      gtf: https://ftp.ensembl.org/pub/release-112/.../Homo_sapiens.GRCh38.112.gtf.gz
    igenomes:
      base: s3://ngi-igenomes/igenomes/Homo_sapiens/Ensembl/GRCh38/
      star_index: Sequence/STARIndex/
      bwa_index: Sequence/BWAIndex/
      hisat2_index: Sequence/HISAT2Index/
      bowtie2_index: Sequence/Bowtie2Index/
      gtf: Annotation/Genes/genes.gtf
```

**Note on iGenomes S3 paths:** These are public S3 URIs requiring `--no-sign-request` for access. CWL File inputs generally cannot consume S3 URIs directly. Agents should use `aws s3 cp --no-sign-request` to download iGenomes files to local paths before passing them to workflows. The Ensembl HTTPS URLs are the preferred source for CWL inputs, as cwltool can resolve HTTPS URLs natively. iGenomes paths are most useful when pre-built indices are needed (saves hours of index building).

**Organism tiers:**

| Tier | Organisms | Verification |
|------|-----------|-------------|
| Tier 1 | Human (GRCh38), Mouse (GRCm39), Yeast (R64-1-1) | Full URL verification + manual index download test (recorded in verified_date) |
| Tier 2 | Rat, Zebrafish, Drosophila, C. elegans, Arabidopsis | URL verification (curl + S3 ls) |
| Tier 3 | Everything else | Ensembl REST API fallback documented |

**Tier 3 fallback:** Agents use the Ensembl REST API at `https://rest.ensembl.org/info/genomes/{organism_name}` to discover assembly names and FTP paths for organisms not in the catalog.

#### 2b. Workflow-to-Index Mapping

Each analysis workflow requires specific reference files and indices. This is the authoritative mapping:

| Workflow | Required References |
|----------|-------------------|
| rnaseq | genome FASTA + GTF + (STAR index OR HISAT2 index) |
| scrnaseq | genome FASTA + GTF + STAR index |
| rnafusion | genome FASTA + GTF + STAR index |
| sarek | genome FASTA + FAI + BWA-MEM2 index + known sites VCF |
| raredisease | genome FASTA + FAI + BWA-MEM2 index + known sites VCF |
| chipseq | genome FASTA + BWA-MEM2 index |
| atacseq | genome FASTA + BWA-MEM2 index |
| methylseq | genome FASTA (Bismark builds index internally) |
| cutandrun | genome FASTA + Bowtie2 index |
| hic | genome FASTA + Bowtie2 index + chromsizes |
| viralrecon | genome FASTA + BWA-MEM2 index + primer BED |
| nanoseq | genome FASTA (minimap2 indexes on-the-fly) |
| ampliseq | taxonomy reference FASTA (not a genome) |
| mag | genome FASTA (for host filtering, optional) |
| taxprofiler | Kraken2/Bracken databases (not genome references) |
| fetchngs | N/A (no reference needed) |

This table is included in `references/README.md` and referenced from `AGENTS.md`.

#### 2c. Agent Guide (`references/README.md`)

Agent-readable document covering:

- How to look up an organism in `genomes.yaml`
- The workflow-to-index mapping table above
- Decision logic: pre-built indices on iGenomes → download via `aws s3 cp --no-sign-request`; not available → run `prepare-references` workflow
- Ensembl REST API fallback for organisms not in the catalog
- How to handle custom genomes provided by the researcher

#### 2d. Prepare-References Workflow (`workflows/prepare-references/`)

A CWL workflow for building indices when pre-built ones aren't available.

- **Inputs:**
  - `genome_fasta: File` — genome FASTA (accepts HTTPS URLs via CWL URL resolution)
  - `gtf: File?` — gene annotation GTF
  - `build_star: boolean` (default: false)
  - `build_bwa: boolean` (default: false)
  - `build_bowtie2: boolean` (default: false)
  - `build_hisat2: boolean` (default: false)
- **Steps:** Each index step uses a CWL `when` condition on its boolean flag:
  - `samtools-faidx.cwl` (always runs)
  - `star-genome-generate.cwl` — `when: $(inputs.build_star)`
  - `bwa-mem2-index.cwl` — `when: $(inputs.build_bwa)`
  - `bowtie2-build.cwl` — `when: $(inputs.build_bowtie2)`
  - `hisat2-build.cwl` — `when: $(inputs.build_hisat2)`
- **Outputs:** Indexed genome FASTA + whichever indices were requested
- **agent.yaml:** Standard agent spec for this workflow
- **Test:** `test-yeast.yaml` — builds STAR + BWA indices for yeast (R64-1-1), expects indexed FASTA + STAR index + BWA index as outputs. Produces RO-Crate.

**Note on genome download:** CWL runners (including cwltool) can resolve HTTPS URLs in File inputs natively. The `genome_fasta` and `gtf` inputs accept URLs from `genomes.yaml` directly — no separate download step needed. Agents should use the Ensembl HTTPS URLs (not FTP) for this reason.

### 3. CI Addition

Add a job to `.github/workflows/evaluate.yml`:

- **`validate-references`** — checks that all URLs in `genomes.yaml` resolve
  - Uses `curl -sI` (supports both HTTPS and FTP) to verify URLs return 200/226
  - Uses `aws s3 ls --no-sign-request` for S3 paths
  - Runs on schedule (weekly) to catch link rot
  - Also runs on push when `references/genomes.yaml` changes

### 4. AGENTS.md Update

Integrate into the existing structure:

- **Finding public data** section — pointer to `docs/data-discovery.md`, brief summary of the TogoID → ENA → fetchngs flow
- **Reference genomes** section — pointer to `references/genomes.yaml` and `references/README.md`, with the decision tree: catalog lookup → iGenomes download or prepare-references workflow
- Update the **Input Resolution** table to include `genome_catalog` as a resolution strategy

### 5. CLAUDE.md Update

Add `references/` to the repository structure section.

### 6. Schema Update (follow-up)

Note for future: add `genome_catalog` as a `resolve_from` strategy in `schemas/agent-spec.schema.yaml` so agent.yaml files can formally declare that genome inputs can be resolved via the genome catalog. Not blocking for v1 — the agent guide in `references/README.md` covers this for now.

## Example End-to-End Flow

Researcher: "I want to analyze RNA-seq data from zebrafish to look at gene expression near a variant I found."

1. Agent reads `AGENTS.md` → identifies need for `rnaseq` + `sarek` workflows
2. Agent reads `docs/data-discovery.md` → searches ENA for zebrafish RNA-seq (`tax_tree=7955&library_strategy=RNA-Seq`)
3. Agent selects relevant accessions → runs `fetchngs` via WES → gets FASTQs
4. Agent reads `references/genomes.yaml` → finds zebrafish (GRCm10, Tier 2), gets Ensembl HTTPS URLs + iGenomes S3 paths
5. Agent checks workflow-to-index mapping → rnaseq needs STAR index, sarek needs BWA index
6. Agent downloads STAR + BWA indices from iGenomes (or runs `prepare-references` if not available)
7. Agent submits `rnaseq` and `sarek` via WES with resolved inputs
8. Agent retrieves outputs + RO-Crate provenance

## File Summary

| File | Type | Description |
|------|------|-------------|
| `docs/data-discovery.md` | New | Agent guide for finding public datasets |
| `references/genomes.yaml` | New | Verified genome catalog |
| `references/README.md` | New | Agent guide for reference resolution |
| `workflows/prepare-references/main.cwl` | New | Index-building workflow |
| `workflows/prepare-references/agent.yaml` | New | Agent spec for prepare-references |
| `workflows/prepare-references/examples/` | New | Example input YAML |
| `workflows/prepare-references/tests/test-yeast.yaml` | New | Test with yeast genome |
| `.github/workflows/evaluate.yml` | Modified | Add URL liveness check |
| `AGENTS.md` | Modified | Add data discovery + reference sections |
| `CLAUDE.md` | Modified | Add references/ to repo structure |

## Non-Goals

- No Python wrapper libraries — agents call APIs directly
- No MCP server — agents read docs and specs
- No curated metadata integration yet — placeholder only
- No index caching service — agents download/build as needed
- No `genome_catalog` resolve_from strategy in schema yet — follow-up item
