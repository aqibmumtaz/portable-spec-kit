#!/usr/bin/env bash
# mechanical-script: deterministic, no AI prompts (Dim 28 allowlist — v0.6.60 HF7b)
# psk-generate-ci.sh — auto-create .github/workflows/ci.yml from AGENT.md Stack table
#
# Generic: detects stack from agent/AGENT.md and emits the correct test command.
# Called automatically by psk-release.sh Step 1 when .github/workflows/ci.yml absent.
# Safe to call repeatedly — skips if file already exists.
#
# Usage:  bash psk-generate-ci.sh [PROJECT_ROOT]
# Output: PROJECT_ROOT/.github/workflows/ci.yml

set -euo pipefail

PROJ_ROOT="${1:-$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null || pwd)}"

CI_FILE="$PROJ_ROOT/.github/workflows/ci.yml"

if [ -f "$CI_FILE" ]; then
  echo "✓ .github/workflows/ci.yml already exists — skipping"
  exit 0
fi

mkdir -p "$PROJ_ROOT/.github/workflows"

AGENT_MD="$PROJ_ROOT/agent/AGENT.md"

# Detect stack from AGENT.md Stack table or manifest files
stack="node"  # default
# NB: under `set -euo pipefail` a no-match grep exits 1 and pipefail propagates it through the
# `| head` pipe, which would kill the script. A no-match is a valid "not this stack" signal, not
# an error — so each detection capture ends in `|| true`. The `:-` guards keep set -u happy.
if [ -f "$AGENT_MD" ]; then
  stack_line=$(grep -iE 'Next\.js|Node|TypeScript|React|Express|pnpm|npm|yarn' "$AGENT_MD" 2>/dev/null | head -1 || true)
  [ -n "${stack_line:-}" ] && stack="node"
  python_line=$(grep -iE 'Python|FastAPI|Flask|Django|pytest|pip' "$AGENT_MD" 2>/dev/null | head -1 || true)
  [ -n "${python_line:-}" ] && stack="python"
  go_line=$(grep -iE '\bGo\b|Golang|go test|go build' "$AGENT_MD" 2>/dev/null | head -1 || true)
  [ -n "${go_line:-}" ] && stack="go"
  rust_line=$(grep -iE 'Rust|cargo test|cargo build' "$AGENT_MD" 2>/dev/null | head -1 || true)
  [ -n "${rust_line:-}" ] && stack="rust"
fi
# Manifest files override AGENT.md (ground truth)
[ -f "$PROJ_ROOT/go.mod" ] && stack="go"
[ -f "$PROJ_ROOT/Cargo.toml" ] && stack="rust"
{ [ -f "$PROJ_ROOT/requirements.txt" ] || [ -f "$PROJ_ROOT/pyproject.toml" ]; } && stack="python"
[ -f "$PROJ_ROOT/package.json" ] && stack="node"  # node wins if package.json present
true   # ensure the manifest-probe block's last test never propagates a non-zero under set -e

# Detect package manager for node
pkg_manager="npm"
[ -f "$PROJ_ROOT/pnpm-lock.yaml" ] && pkg_manager="pnpm"
[ -f "$PROJ_ROOT/yarn.lock" ] && pkg_manager="yarn"
[ -f "$PROJ_ROOT/bun.lockb" ] && pkg_manager="bun"

# Detect test command from package.json
test_cmd="test"
if [ "$stack" = "node" ] && [ -f "$PROJ_ROOT/package.json" ]; then
  has_vitest=$(grep -c '"vitest"' "$PROJ_ROOT/package.json" 2>/dev/null || echo 0)
  [ "$has_vitest" -gt 0 ] && test_cmd="test --run"
  has_jest=$(grep -c '"jest"' "$PROJ_ROOT/package.json" 2>/dev/null || echo 0)
  [ "$has_jest" -gt 0 ] && test_cmd="test"
fi

# Generate stack-specific CI YAML
case "$stack" in
  node)
    cat > "$CI_FILE" <<YAML
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

$([ "$pkg_manager" = "pnpm" ] && cat <<PNPM
      - uses: pnpm/action-setup@v3
        with:
          version: latest
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm $test_cmd
PNPM
)
$([ "$pkg_manager" = "npm" ] && cat <<NPM
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm $test_cmd
NPM
)
$([ "$pkg_manager" = "yarn" ] && cat <<YARN
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'yarn'
      - run: yarn install --frozen-lockfile
      - run: yarn $test_cmd
YARN
)
$([ "$pkg_manager" = "bun" ] && cat <<BUN
      - uses: oven-sh/setup-bun@v1
      - run: bun install --frozen-lockfile
      - run: bun $test_cmd
BUN
)
YAML
    ;;

  python)
    cat > "$CI_FILE" <<YAML
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: pytest
YAML
    ;;

  go)
    cat > "$CI_FILE" <<YAML
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: stable
      - run: go test ./...
YAML
    ;;

  rust)
    cat > "$CI_FILE" <<YAML
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo test
YAML
    ;;
esac

echo "✓ .github/workflows/ci.yml written (stack: $stack, pkg: ${pkg_manager:-n/a})"
