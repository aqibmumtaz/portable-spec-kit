<!-- Section Version: v0.5.5 -->
## Document Generation (ARD / Technical Docs)

### Flow Documentation (`docs/work-flows/`)

**All flow diagrams use box-style ASCII diagrams.** Never use tree-style connectors (bare `│/▼` on standalone lines). Every flow doc in `docs/work-flows/` must follow this format:

```
┌─────────────────────────────────────────────────────────────┐
│  STEP NAME                                                   │
│     Detail line 1                                           │
│     Detail line 2                                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  NEXT STEP                                                   │
└─────────────────────────────────────────────────────────────┘
```

Rules:
- Each step in a flow = one box (`┌─...─┐` / `│` / `└─...─┘`)
- Boxes connect with `└──────┬──────┘` → `┌──────▼──────┐` connectors
- Decision branches go inside the box as `├─ Yes → ... / └─ No → ...`
- Inner content boxes (showing file states, examples) nest with 2-space indent inside outer box
- No standalone `│` or `▼` lines between steps
- When updating a flow doc, convert any remaining tree-style sections to box-style in the same session
- Every box line (`│...│`) must be exactly 63 display characters wide — pad trailing spaces to align the right `│` border

**Architecture change rule:** When any agent behavior, process, or setup flow changes — new step added, trigger modified, rule removed — update the relevant `docs/work-flows/` file in the same session. A process change without a matching flow doc update is incomplete.

**Release gate for flow docs:** As part of every `prepare release` Step 2 — scan `docs/work-flows/` and verify each flow reflects current behavior. If any flow describes a process that changed this release, update it before finalizing. Box-style format required. No tree-style connectors. All box lines 63 chars wide.

### Document Structure (Standard Order)
1. Title Page (cover — readable text, professional styling)
2. Executive Summary + Key Highlights
3. Version Changelog (detailed per-version with categorized changes)
4. Table of Contents
5. Full document sections (each TOC heading starts on new page)

### Changelog Format
- Each version: `v0.X — Title (Date)`
- Group changes by category (e.g., Frontend, Backend, AI, Infrastructure)
- List specific features with technical detail
- Reference file paths, APIs, and technologies used

### Styling Rules
- HTML source → convert to PDF via browser print or PDF generation tool
- `@page { size: A4; margin: 22mm 20mm; }`
- Professional fonts: Segoe UI / system-ui
- Brand colors: defined per project in `agent/AGENT.md`
- Tables with dark header, alternating row colors
- Code blocks with monospace font, light background
- Page breaks before each major section (`page-break-before: always`)

### Presentations
- Landscape slides: `@page { size: 297mm 210mm; }`
- Content vertically centered on each slide
- Consistent slide themes: dark, light, accent, gray
- Footer gradient bar on light slides
- Slide numbers in bottom-right corner

---

