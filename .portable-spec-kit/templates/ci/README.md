# CI Templates for Kit-Adopted Projects

Pick the template matching your stack and copy it to `.github/workflows/ci.yml` in your project:

| Stack | Template | What it runs |
|-------|----------|--------------|
| Node / TypeScript | `ci-node.yml` | `npm ci` · lint · typecheck · test · R→F→T · sync-check |
| Python | `ci-python.yml` | `pip install` · ruff · mypy · pytest · R→F→T · sync-check |
| Go | `ci-go.yml` | `go build` · `go vet` · `go test -race` · R→F→T · sync-check |
| Other / mixed | `ci-generic.yml` | Kit gates only (add your test steps separately) |

Each template ends with the kit's mandatory gates:
- **R→F→T gate** — every `[x]` feature in `agent/SPECS.md` must reference a passing test
- **PSK sync-check** — 12 deterministic checks including PSK011 secret scan
- **Bypass detector** — CI fails if any commit in the branch bypassed a local gate (`agent/.bypass-log` present)

## Agent-assisted installation

Ask your AI agent: *"enable CI"* — it will detect your stack and copy the right template automatically.
