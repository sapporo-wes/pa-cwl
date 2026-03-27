# Data Discovery Guide

How to find public sequencing data accessions for use with pa-cwl workflows.

## Decision Flowchart

```
Start
  |
  ├─ Have a PubMed ID, BioProject ID, or GEO Series ID?
  │    → Use TogoID to convert to SRA run accessions (Section 1)
  │
  ├─ Know the organism and assay type (e.g., human RNA-Seq)?
  │    → Use ENA Search API to query by taxonomy and library strategy (Section 2)
  │
  └─ ENA not returning results or need SRA-specific metadata?
       → Use NCBI E-utilities as a fallback (Section 3)
```

All paths produce a list of SRA run accessions (SRR/ERR/DRR). Feed these into the `fetchngs` workflow to download FASTQ files.

---

## 1. TogoID (ID Conversion)

**Service:** https://togoid.dbcls.jp
**API base:** `https://api.togoid.dbcls.jp`
**Use case:** Convert a paper or project identifier into SRA run accessions.

### Endpoint

```
GET https://api.togoid.dbcls.jp/convert?ids={IDS}&route={SOURCE},{TARGET}&format=json
```

| Parameter | Description |
|-----------|-------------|
| `ids`     | Comma-separated input identifiers |
| `route`   | Source and target dataset names, comma-separated |
| `format`  | `json` or `tsv` |

### Available Dataset Names

| Dataset name | Example ID | Description |
|---|---|---|
| `pubmed` | `30002370` | PubMed article ID |
| `bioproject` | `PRJNA396809` | BioProject accession |
| `geo_series` | `GSE119931` | GEO Series accession |
| `sra_run` | `SRR7851676` | SRA run accession |
| `biosample` | `SAMD00000001` | BioSample accession |

### Common Conversion Routes

| From | To | Route value |
|---|---|---|
| PubMed ID | BioProject | `pubmed,bioproject` |
| GEO Series | BioProject | `geo_series,bioproject` |
| BioProject | SRA runs | `bioproject,sra_run` |

Note: Multi-hop routes (e.g., PubMed → BioProject → SRA runs) require two sequential API calls. There is no single-call route from `pubmed` or `geo_series` directly to `sra_run`.

### Example: PubMed ID to SRA Runs (Two Steps)

**Step 1 — Get BioProject IDs from a PubMed ID:**

```bash
curl -s 'https://api.togoid.dbcls.jp/convert?ids=30002370&route=pubmed,bioproject&format=json'
```

Response:

```json
{
  "ids": ["30002370"],
  "results": [["30002370", "PRJNA396809"], ["30002370", "PRJNA488561"]],
  "route": ["pubmed", "bioproject"]
}
```

The `results` array contains `[source_id, target_id]` pairs.

**Step 2 — Get SRA run accessions from a BioProject:**

```bash
curl -s 'https://api.togoid.dbcls.jp/convert?ids=PRJNA396809&route=bioproject,sra_run&format=json'
```

Response:

```json
{
  "ids": ["PRJNA396809"],
  "results": ["SRR7851676", "SRR7851677", "SRR7851678", ...],
  "route": ["bioproject", "sra_run"]
}
```

When converting to `sra_run`, the `results` array is a flat list of run accessions.

### Example: GEO Series to SRA Runs

```bash
# Step 1: GEO Series → BioProject
curl -s 'https://api.togoid.dbcls.jp/convert?ids=GSE119931&route=geo_series,bioproject&format=json'
# Returns: {"results": ["PRJNA490732"], ...}

# Step 2: BioProject → SRA runs
curl -s 'https://api.togoid.dbcls.jp/convert?ids=PRJNA490732&route=bioproject,sra_run&format=json'
# Returns: {"results": ["SRR7826334", "SRR7826335", ...], ...}
```

---

## 2. ENA Search API

**Endpoint:** `https://www.ebi.ac.uk/ena/portal/api/search`
**Use case:** Find sequencing runs by organism, assay type, and other metadata when you do not have a specific project ID.

### Query Parameters

| Parameter | Description |
|-----------|-------------|
| `query`   | Search expression (see filters below) |
| `result`  | Result type. Use `read_run` for sequencing runs |
| `fields`  | Comma-separated list of fields to return |
| `format`  | `json` or `tsv` |
| `limit`   | Maximum number of results (default 0 = all). Use for pagination |
| `offset`  | Skip this many results. Combine with `limit` for pagination |

### Key Query Filters

| Filter | Description | Example |
|--------|-------------|---------|
| `tax_tree(ID)` | All runs under a taxonomy node | `tax_tree(9606)` for human |
| `library_strategy="X"` | Sequencing assay type | `"RNA-Seq"`, `"WGS"`, `"ChIP-Seq"`, `"ATAC-seq"`, `"Hi-C"` |
| `library_layout="X"` | Read layout | `"PAIRED"` or `"SINGLE"` |
| `base_count>N` | Minimum total bases | `base_count>1000000000` |
| `first_public>=YYYY-MM-DD` | Published on or after date | `first_public>=2023-01-01` |

Combine filters with `AND`:

```
tax_tree(9606) AND library_strategy="RNA-Seq" AND library_layout="PAIRED"
```

### Useful Return Fields

`run_accession`, `experiment_title`, `library_strategy`, `library_layout`, `base_count`, `first_public`, `study_accession`, `sample_accession`, `instrument_platform`, `read_count`

### Example: Human Paired-End RNA-Seq

```bash
curl -s 'https://www.ebi.ac.uk/ena/portal/api/search?query=tax_tree(9606)%20AND%20library_strategy=%22RNA-Seq%22%20AND%20library_layout=%22PAIRED%22&result=read_run&fields=run_accession,experiment_title,library_strategy,library_layout,base_count,first_public&limit=3&format=json'
```

Response:

```json
[
  {
    "run_accession": "DRR001622",
    "experiment_title": "Illumina Genome Analyzer IIx sequencing: Human ICESeq(-), template 1",
    "library_strategy": "RNA-Seq",
    "library_layout": "PAIRED",
    "base_count": "2198179768",
    "first_public": "2012-06-08"
  },
  ...
]
```

### Example: Recent Yeast WGS

```bash
curl -s 'https://www.ebi.ac.uk/ena/portal/api/search?query=tax_tree(4932)%20AND%20library_strategy=%22WGS%22%20AND%20first_public>=2023-01-01&result=read_run&fields=run_accession,experiment_title,library_strategy,base_count&limit=5&format=json'
```

### Pagination

To iterate through large result sets:

```bash
# Page 1
curl -s '...&limit=100&offset=0&format=json'
# Page 2
curl -s '...&limit=100&offset=100&format=json'
```

Continue until the response returns an empty array `[]`.

### Common Taxonomy IDs

| Organism | Taxonomy ID |
|----------|-------------|
| Human | 9606 |
| Mouse | 10090 |
| *S. cerevisiae* (yeast) | 4932 |
| *D. melanogaster* (fruit fly) | 7227 |
| *C. elegans* | 6239 |
| *A. thaliana* | 3702 |
| *D. rerio* (zebrafish) | 7955 |
| *E. coli* K-12 | 83333 |

---

## 3. NCBI E-utilities (Fallback)

**Use case:** When ENA does not return expected results, or when you need SRA-specific metadata not available through ENA.

### esearch — Find SRA Records

```
GET https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&term={QUERY}&retmax={N}&retmode=json
```

### Example: Find SRA Records for a BioProject

```bash
curl -s 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&term=PRJNA396809%5BBioProject%5D&retmax=5&retmode=json'
```

Response:

```json
{
  "header": {"type": "esearch", "version": "0.3"},
  "esearchresult": {
    "count": "266",
    "retmax": "5",
    "retstart": "0",
    "idlist": ["6368978", "6368977", "6368976", "6368975", "6368974"]
  }
}
```

The `idlist` contains SRA internal UIDs. To get run accessions, pass them to efetch.

### efetch — Get Run Accessions from UIDs

```bash
curl -s 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=sra&id=6368978,6368977&rettype=runinfo&retmode=csv' | head -3
```

This returns CSV with columns including `Run` (the SRR accession), `BioProject`, `LibraryStrategy`, etc.

### esearch Query Syntax

| Search field | Example |
|---|---|
| BioProject | `PRJNA396809[BioProject]` |
| Organism | `"Homo sapiens"[Organism]` |
| Strategy | `"rna seq"[Strategy]` |
| Platform | `"illumina"[Platform]` |

Combine with `AND`:

```
"Homo sapiens"[Organism] AND "rna seq"[Strategy] AND "illumina"[Platform]
```

### Rate Limits

NCBI E-utilities allow 3 requests per second without an API key. Register for an API key at https://www.ncbi.nlm.nih.gov/account/settings/ and append `&api_key=YOUR_KEY` to raise the limit to 10 requests per second.

---

## 4. Future: Curated Metadata API

A curated metadata service is in development. It will use LLMs to annotate public sequencing metadata with standardized ontology terms, enabling higher-quality dataset discovery.

**Expected API contract:**

```
GET /api/v1/datasets?taxonomy_id={ID}&library_strategy={STRATEGY}
```

Input: taxonomy ID + library strategy (and optional filters).
Output: ranked list of accessions with quality scores and standardized annotations.

This section will be updated when the service becomes available.

---

## Feeding Accessions into fetchngs

All discovery methods above produce SRA run accessions (SRR/ERR/DRR). To download the corresponding FASTQ files, pass these accessions to the `fetchngs` workflow:

1. Create an input file with one accession per line
2. Run the `fetchngs` workflow with that file as input

See the `workflows/fetchngs/` directory for workflow definition and usage details.
