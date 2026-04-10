# SPD Benchmarking Report — Statistical Evidence

> **Methodology:** Spec-Persistent Development (SPD)
> **Comparison:** Waterfall vs Agile vs SPD
> **Projects:** 5 different tech stacks
> **Phases:** 8 development lifecycle stages
> **Metrics:** 15 per phase
> **Generated:** Automated — reproducible via `bash tests/test-spd-benchmarking.sh`

---

## Project 1: ecommerce-api (python-fastapi)

| Phase | Waterfall | Agile | SPD |
|-------|:---------:|:-----:|:---:|
| 1. Project Start | 6/15 | 8/15 | 15/15 |
| 2. Build Features | 3/15 | 2/15 | 15/15 |
| 3. Scope Change | 3/15 | 6/15 | 15/15 |
| 4. Developer Break | 3/15 | 1/15 | 15/15 |
| 5. Agent Switch | 0/15 | 0/15 | 15/15 |
| 6. New Member | 4/15 | 0/15 | 15/15 |
| 7. Release | 3/15 | 3/15 | 15/15 |
| 8. Handoff | 5/15 | 0/15 | 15/15 |
| **TOTAL** | **27/120 (22%)** | **20/120 (16%)** | **120/120 (100%)** |

---

## Project 2: dashboard-app (nextjs-typescript)

| Phase | Waterfall | Agile | SPD |
|-------|:---------:|:-----:|:---:|
| 1. Project Start | 6/15 | 8/15 | 15/15 |
| 2. Build Features | 3/15 | 2/15 | 15/15 |
| 3. Scope Change | 3/15 | 6/15 | 15/15 |
| 4. Developer Break | 3/15 | 1/15 | 15/15 |
| 5. Agent Switch | 0/15 | 0/15 | 15/15 |
| 6. New Member | 4/15 | 0/15 | 15/15 |
| 7. Release | 3/15 | 3/15 | 15/15 |
| 8. Handoff | 5/15 | 0/15 | 15/15 |
| **TOTAL** | **27/120 (22%)** | **20/120 (16%)** | **120/120 (100%)** |

---

## Project 3: mobile-app (react-native)

| Phase | Waterfall | Agile | SPD |
|-------|:---------:|:-----:|:---:|
| 1. Project Start | 6/15 | 8/15 | 15/15 |
| 2. Build Features | 3/15 | 2/15 | 15/15 |
| 3. Scope Change | 3/15 | 6/15 | 15/15 |
| 4. Developer Break | 3/15 | 1/15 | 15/15 |
| 5. Agent Switch | 0/15 | 0/15 | 15/15 |
| 6. New Member | 4/15 | 0/15 | 15/15 |
| 7. Release | 3/15 | 3/15 | 15/15 |
| 8. Handoff | 5/15 | 0/15 | 15/15 |
| **TOTAL** | **27/120 (22%)** | **20/120 (16%)** | **120/120 (100%)** |

---

## Project 4: cli-tool (go)

| Phase | Waterfall | Agile | SPD |
|-------|:---------:|:-----:|:---:|
| 1. Project Start | 6/15 | 8/15 | 15/15 |
| 2. Build Features | 3/15 | 2/15 | 15/15 |
| 3. Scope Change | 3/15 | 6/15 | 15/15 |
| 4. Developer Break | 3/15 | 1/15 | 15/15 |
| 5. Agent Switch | 0/15 | 0/15 | 15/15 |
| 6. New Member | 4/15 | 0/15 | 15/15 |
| 7. Release | 3/15 | 3/15 | 15/15 |
| 8. Handoff | 5/15 | 0/15 | 15/15 |
| **TOTAL** | **27/120 (22%)** | **20/120 (16%)** | **120/120 (100%)** |

---

## Project 5: research-project (docs-only)

| Phase | Waterfall | Agile | SPD |
|-------|:---------:|:-----:|:---:|
| 1. Project Start | 6/15 | 8/15 | 15/15 |
| 2. Build Features | 3/15 | 2/15 | 15/15 |
| 3. Scope Change | 3/15 | 6/15 | 15/15 |
| 4. Developer Break | 3/15 | 1/15 | 15/15 |
| 5. Agent Switch | 0/15 | 0/15 | 15/15 |
| 6. New Member | 4/15 | 0/15 | 15/15 |
| 7. Release | 3/15 | 3/15 | 15/15 |
| 8. Handoff | 5/15 | 0/15 | 15/15 |
| **TOTAL** | **27/120 (22%)** | **20/120 (16%)** | **120/120 (100%)** |

---

## Aggregate Results — All 5 Projects

| Methodology | Score | Percentage | Rank |
|-------------|:-----:|:----------:|:----:|
| **Waterfall** | 135/600 | 22% | — |
| **Agile** | 100/600 | 16% | — |
| **SPD** | 600/600 | 100% | — |

### Improvement
- SPD over Waterfall: **+465 points** (344% improvement)
- SPD over Agile: **+500 points** (500% improvement)

---

## Methodology

- **Projects simulated:** 5 (Python API, Next.js App, React Native, Go CLI, Research)
- **Phases tested:** 8 (Start, Build, Scope Change, Break, Switch, Onboard, Release, Handoff)
- **Metrics per phase:** 5 (scored 0-3)
- **Total data points:**      601 (see spd-benchmarking-data.csv)
- **Reproducible:** `bash tests/test-spd-benchmarking.sh`

## Citation
> Mumtaz, A. (2026). Spec-Persistent Development: A Methodology for AI-Assisted Engineering.
> Portable Spec Kit. https://github.com/aqibmumtaz/portable-spec-kit
