# pa-cwl: Pretty Agentic CWL

Production-ready [Common Workflow Language](https://www.commonwl.org/) workflows designed for AI-agent execution via the [GA4GH Workflow Execution Service (WES)](https://ga4gh.github.io/workflow-execution-service-schemas/) API.

## What is this?

pa-cwl provides a curated collection of CWL v1.2 workflows for scientific data analysis. Each workflow ships with:

- **`agent.yaml`** — Machine-readable instructions for AI agents: what the workflow does, what inputs it needs, how to run it
- **CWL v1.2 workflows** — Portable, standards-compliant workflow definitions
- **WES-ready execution** — Tested with [sapporo-wes](https://github.com/sapporo-wes/sapporo-service) and validated via [yevis-cli](https://github.com/sapporo-wes/yevis-cli)
- **Workflow Run RO-Crate** — Provenance records for every validated execution
- **Test data on Zenodo** — Persistent, DOI-backed datasets for acceptance testing

## Workflows

| Workflow | Description | Status |
|----------|-------------|--------|
| [fetchngs](workflows/fetchngs/) | Fetch sequencing data from public repositories (SRA/ENA/DDBJ) | WIP |
| [rnaseq](workflows/rnaseq/) | RNA-seq quantification (STAR, HISAT2, Salmon, RSEM, kallisto) | WIP |

More workflows coming — see [Roadmap](#roadmap).

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
cwltool workflows/rnaseq/main.cwl examples/local-fastq.yaml

# Run via sapporo-wes
# See docs/running-with-wes.md
```

## Testing

Workflows are validated through:

1. **Local execution** — Run against sapporo-wes with real-sized test data
2. **RO-Crate generation** — Execution provenance captured as Workflow Run RO-Crate
3. **CI evaluation** — GitHub Actions validates RO-Crate completeness and output correctness
4. **Acceptance testing** — Test data published on Zenodo for users to reproduce

## Roadmap

- **Phase 0** — Repository scaffold, schemas, CI setup
- **Phase 1** — fetchngs + rnaseq (proof of concept)
- **Phase 2** — sarek, atacseq, chipseq, ampliseq, mag, differentialabundance
- **Phase 3** — MCP server for agent discovery, Python client library
- **Phase 4** — Community contributions, workflow template generator

## License

[Apache-2.0](LICENSE)
