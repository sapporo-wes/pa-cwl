# pa-cwl Development Guide

## Project Overview
pa-cwl (Pretty Agentic CWL) — Production-ready CWL v1.2 workflows for AI-agent execution via WES.

## Key Decisions
- CWL v1.2 (not v1.3-dev)
- BioContainers (one container per tool)
- Input resolution: fetchngs as separate workflow, analysis workflows stay pure
- Agent interface: agent.yaml + AGENTS.md (no wrapper library needed — agents read the WES OpenAPI spec directly)
- Full feature parity with nf-core reference workflows
- Single monorepo under sapporo-wes org
- Testing: local sapporo-wes execution → RO-Crate → GH Actions evaluation → Zenodo test data
- License: Apache-2.0

## Repository Structure
- `workflows/<name>/main.cwl` — Top-level CWL workflow
- `workflows/<name>/steps/` — Subworkflows and CommandLineTools
- `workflows/<name>/agent.yaml` — AI-agent instructions (must conform to schemas/agent-spec.schema.yaml)
- `workflows/<name>/examples/` — Example input YAML files
- `workflows/<name>/tests/` — Test inputs and expected outputs
- `tools/` — Shared CWL CommandLineTools
- `schemas/` — JSON Schema definitions
- `AGENTS.md` — Top-level agent entry point (workflow catalog, WES API, provenance protocol)

## Workflow Development Guidelines
- Write idiomatic CWL — do NOT transpile from Nextflow
- Use nf-core pipelines as functional specification only
- Every workflow MUST have agent.yaml conforming to the schema
- Use BioContainers Docker images with pinned versions
- Design step interfaces so tools can be swapped (e.g., STAR ↔ HISAT2)
- Scatter over samples where possible for parallelism

## agent.yaml Conventions
- execution_plan: structured deterministic steps
- hints: natural language for edge cases
- All inputs must have resolve_from strategies where applicable
- Always specify wes.resource_hints

## Testing
- Test locally with sapporo-wes + yevis-cli
- Push Workflow Run RO-Crate to tests/ro-crate/
- GH Actions validates CWL, agent.yaml schema, and RO-Crate
- Test data published on Zenodo
