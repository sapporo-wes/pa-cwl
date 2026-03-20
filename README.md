# pa-cwl: Pretty Agentic CWL

Production-ready [Common Workflow Language](https://www.commonwl.org/) workflows designed for AI-agent execution via the [GA4GH Workflow Execution Service (WES)](https://ga4gh.github.io/workflow-execution-service-schemas/) API.

## What is this?

pa-cwl provides a curated collection of CWL v1.2 workflows for scientific data analysis. Each workflow ships with:

- **`agent.yaml`** — Machine-readable instructions for AI agents: what the workflow does, what inputs it needs, how to run it
- **CWL v1.2 workflows** — Portable, standards-compliant workflow definitions
- **WES-ready execution** — Tested with [sapporo-wes](https://github.com/sapporo-wes/sapporo-service) and validated via [yevis-cli](https://github.com/sapporo-wes/yevis-cli)
- **Workflow Run RO-Crate** — Provenance records for every validated execution

## Workflows

All 16 pipelines implemented and tested. Functional specifications derived from [nf-core](https://nf-co.re/) pipelines, rewritten as idiomatic CWL v1.2 (not transpiled).

### Data Retrieval

| Workflow | Description | Key Tools |
|----------|-------------|-----------|
| [fetchngs](workflows/fetchngs/) | Fetch FASTQ from public repositories (SRA/ENA/DDBJ) | ENA API, fasterq-dump |

### Transcriptomics

| Workflow | Description | Key Tools |
|----------|-------------|-----------|
| [rnaseq](workflows/rnaseq/) | RNA-seq quantification (4 pathways) | STAR, HISAT2, Salmon, RSEM, kallisto |
| [scrnaseq](workflows/scrnaseq/) | Single-cell RNA-seq (10x, Drop-seq) | STARsolo |
| [rnafusion](workflows/rnafusion/) | Gene fusion detection | STAR (chimeric), Arriba |

### Epigenomics

| Workflow | Description | Key Tools |
|----------|-------------|-----------|
| [chipseq](workflows/chipseq/) | ChIP-seq peak calling | BWA-MEM2, MACS2, deepTools |
| [atacseq](workflows/atacseq/) | ATAC-seq chromatin accessibility | BWA-MEM2, MACS2 (--nomodel) |
| [methylseq](workflows/methylseq/) | Bisulfite-seq methylation | Bismark |
| [cutandrun](workflows/cutandrun/) | CUT&RUN/CUT&TAG peak calling | Bowtie2, MACS2 (--nomodel), deepTools |

### Variant Calling

| Workflow | Description | Key Tools |
|----------|-------------|-----------|
| [sarek](workflows/sarek/) | Germline variant calling | BWA-MEM2, GATK4 HaplotypeCaller |
| [raredisease](workflows/raredisease/) | Rare disease variant annotation | sarek + Ensembl VEP |
| [viralrecon](workflows/viralrecon/) | Viral variant calling and consensus | BWA-MEM2, iVar |

### Metagenomics

| Workflow | Description | Key Tools |
|----------|-------------|-----------|
| [ampliseq](workflows/ampliseq/) | 16S/ITS amplicon sequencing | Cutadapt, DADA2 |
| [mag](workflows/mag/) | Metagenome-assembled genomes | SPAdes, MetaBAT2, Prodigal |
| [taxprofiler](workflows/taxprofiler/) | Taxonomic profiling | Kraken2, Bracken |

### Long-Read & 3D Genomics

| Workflow | Description | Key Tools |
|----------|-------------|-----------|
| [nanoseq](workflows/nanoseq/) | Nanopore long-read sequencing | minimap2, NanoPlot |
| [hic](workflows/hic/) | Hi-C chromatin conformation | Bowtie2 (two-step), pairtools, cooler |

68 CWL tools in `tools/`, shared across pipelines. See [pipeline roadmap](docs/pipeline-roadmap.md) for detailed feature tables and test matrices.

## For AI Agents

Every workflow contains an `agent.yaml` that provides:

1. **Structured execution plan** — Deterministic steps with conditionals for input resolution and tool selection
2. **Natural language hints** — Guidance for edge cases and user interaction
3. **Input schema** — Typed parameters with descriptions, defaults, and resolution strategies
4. **WES submission details** — Tested engines, resource requirements, and expected outputs

### Quick Start (Agent)

```
1. Read workflows/<name>/agent.yaml
2. Resolve user inputs (local files, SRA accessions, URLs)
3. Generate CWL input object (YAML)
4. Submit to WES endpoint: POST /runs
5. Monitor: GET /runs/{run_id}/status
6. Retrieve outputs on COMPLETE
```

## For Humans

```bash
# Run locally with cwltool
cwltool workflows/rnaseq/main.cwl workflows/rnaseq/examples/star-salmon.yaml

# Run via sapporo-wes
# See docs/running-with-wes.md
```

## Roadmap

- **Phase 1** — 16 core pipelines (fetchngs through hic) — **Complete**
- **Phase 2** — v1.1 enhancements (additional pathways, tools, and modes per pipeline)
- **Phase 3** — MCP server for agent discovery, Python client library
- **Phase 4** — Community contributions, workflow template generator

## License

[Apache-2.0](LICENSE)
