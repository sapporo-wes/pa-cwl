# pa-cwl Agent Guide

This repository contains 16 production-ready CWL v1.2 bioinformatics workflows. Each workflow can be executed via any GA4GH Workflow Execution Service (WES) endpoint.

## Workflow Catalog

| Workflow | Description | agent.yaml |
|----------|-------------|------------|
| ampliseq | 16S/ITS amplicon sequencing | `workflows/ampliseq/agent.yaml` |
| atacseq | ATAC-seq chromatin accessibility | `workflows/atacseq/agent.yaml` |
| chipseq | ChIP-seq peak calling | `workflows/chipseq/agent.yaml` |
| cutandrun | CUT&RUN/CUT&TAG peak calling | `workflows/cutandrun/agent.yaml` |
| fetchngs | Fetch FASTQ from SRA/ENA/DDBJ | `workflows/fetchngs/agent.yaml` |
| hic | Hi-C chromatin conformation | `workflows/hic/agent.yaml` |
| mag | Metagenome-assembled genomes | `workflows/mag/agent.yaml` |
| methylseq | Bisulfite-seq methylation | `workflows/methylseq/agent.yaml` |
| nanoseq | Nanopore long-read sequencing | `workflows/nanoseq/agent.yaml` |
| raredisease | Rare disease variant annotation | `workflows/raredisease/agent.yaml` |
| rnafusion | Gene fusion detection | `workflows/rnafusion/agent.yaml` |
| rnaseq | RNA-seq quantification | `workflows/rnaseq/agent.yaml` |
| sarek | Germline + somatic variant calling | `workflows/sarek/agent.yaml` |
| scrnaseq | Single-cell RNA-seq | `workflows/scrnaseq/agent.yaml` |
| taxprofiler | Taxonomic profiling | `workflows/taxprofiler/agent.yaml` |
| viralrecon | Viral variant calling and consensus | `workflows/viralrecon/agent.yaml` |
| prepare-references | Build genome indices (STAR, BWA, Bowtie2, HISAT2) | `workflows/prepare-references/agent.yaml` |

## How to Run a Workflow

1. **Read the agent.yaml** for the workflow you need. It contains the input schema, execution plan, resolution strategies, and resource requirements.

2. **Resolve inputs** using the `resolve_from` strategies listed in the agent.yaml. For public data (SRA/ENA accessions), run `fetchngs` first to obtain FASTQ files.

3. **Submit to WES** — see [WES API](#wes-api) below.

4. **Poll for completion** until the run state is `COMPLETE`.

5. **Retrieve outputs and provenance** — download results and the RO-Crate metadata.

## WES API

The WES endpoint (e.g., [Sapporo](https://github.com/sapporo-wes/sapporo-service)) exposes a standard GA4GH WES API. Three operations are needed:

### Submit a run

```
POST /runs
Content-Type: multipart/form-data

workflow_type=CWL
workflow_type_version=v1.2
workflow_engine=cwltool
workflow_url=file:///path/to/packed.cwl
workflow_params=<JSON string of CWL inputs>
```

Pack the workflow first with `cwltool --pack workflows/<name>/main.cwl` to produce a single portable CWL file.

### Poll status

```
GET /runs/{run_id}/status

Response: {"run_id": "...", "state": "RUNNING"}
```

States: `QUEUED`, `INITIALIZING`, `RUNNING`, `COMPLETE`, `EXECUTOR_ERROR`, `SYSTEM_ERROR`, `CANCELED`.

### Retrieve RO-Crate provenance

```
GET /runs/{run_id}/ro-crate

Response: RO-Crate metadata JSON (Workflow Run RO-Crate)
```

The full WES API spec is available at the running endpoint via `GET /service-info`.

## Provenance

Every workflow run produces a [Workflow Run RO-Crate](https://www.researchobject.org/workflow-run-crate/) that records:

- Workflow definition and version
- Input parameters and files
- Output files with checksums
- Execution engine, timestamps, exit codes

Save RO-Crate metadata to the repository:

- Single-test workflows: `workflows/<name>/tests/ro-crate/ro-crate-metadata.json`
- Multi-test workflows: `workflows/<name>/tests/ro-crate/<test-name>/ro-crate-metadata.json`

Validate that the RO-Crate `@graph` contains `Dataset`, `ComputationalWorkflow`, and `CreateAction` entities.

## Input Resolution

Each `agent.yaml` lists `resolve_from` strategies for its inputs. Common patterns:

| Strategy | Description |
|----------|-------------|
| `local_path` | User provides a file path |
| `sra_accession` | Run `fetchngs` to download from SRA/ENA/DDBJ |
| `bioproject_accession` | Run `fetchngs` with a BioProject ID |
| `https_url` | Download from a URL |
| `s3_uri` / `gcp_uri` | Cloud storage paths |
| `genome_catalog` | Look up organism in references/genomes.yaml |

When the user provides SRA accessions, chain `fetchngs` first, then pass its outputs to the analysis workflow. The `dependencies` field in agent.yaml indicates when this chaining is needed.

## Finding Public Data

When the researcher needs to find public sequencing data, see [docs/data-discovery.md](docs/data-discovery.md) for the full guide. Summary:

1. **Have a paper or dataset ID?** Use [TogoID](https://togoid.dbcls.jp) to convert PubMed, BioProject, BioSample, or GEO IDs to SRA run accessions.
2. **Know the organism and assay type?** Search the [ENA Portal API](https://www.ebi.ac.uk/ena/portal/api/) by taxonomy and library strategy.
3. **ENA doesn't have it?** Fall back to [NCBI E-utilities](https://www.ncbi.nlm.nih.gov/books/NBK25499/) esearch/efetch.

All accession lists feed into the `fetchngs` workflow to download FASTQ files.

## Reference Genomes

When a workflow needs a genome reference, see [references/README.md](references/README.md) for the full guide and [references/genomes.yaml](references/genomes.yaml) for the verified genome catalog.

**Decision tree:**
1. Look up organism in `references/genomes.yaml` (8 common organisms with verified Ensembl + iGenomes URLs)
2. If iGenomes has pre-built indices for the needed type → download with `aws s3 cp --no-sign-request`
3. If not → pass Ensembl HTTPS URLs to the `prepare-references` workflow to build indices
4. Organism not in catalog → query `https://rest.ensembl.org/info/genomes/{name}?content-type=application/json`

See the workflow-to-index mapping in [references/README.md](references/README.md) to know which indices each workflow needs.

## Reference

- [Agent spec schema](schemas/agent-spec.schema.yaml) — JSON Schema for agent.yaml files
- [Testing guide](docs/testing.md) — Test inventory and results
- [Pipeline roadmap](docs/pipeline-roadmap.md) — Feature tables per workflow
- [Zenodo archive](https://doi.org/10.5281/zenodo.19233880) — Workflows and test data (v1.0.0)
