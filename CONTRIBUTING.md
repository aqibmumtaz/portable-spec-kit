# Contributing to Portable Spec Kit

Thank you for your interest in improving the framework! Contributions from the community make this better for everyone.

---

## How to Contribute

### 1. Report Issues

Found a gap in the framework? Something unclear? [Open an issue](https://github.com/aqibmumtaz/portable-spec-kit/issues) with:
- What's missing or broken
- Why it matters
- Suggested improvement (if you have one)

### 2. Suggest Framework Improvements

The best contributions come from real-world usage. If you've been using CLAUDE.md and discovered:
- A new testing pattern that catches more bugs
- A better project structure for a specific stack
- An agent behavior rule that improves developer experience
- An edge case the framework doesn't handle

Open a PR or issue describing the improvement.

### 3. Submit a Pull Request

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/portable-spec-kit.git
cd portable-spec-kit

# Create a branch
git checkout -b improve/testing-rules

# Make your changes to CLAUDE.md
# ...

# Commit and push
git add .
git commit -m "Add integration testing guidelines"
git push origin improve/testing-rules

# Open a PR on GitHub
```

---

## What Makes a Good Contribution

### Do Contribute

| Type | Examples |
|------|---------|
| **Universal dev practices** | New testing patterns, error handling strategies, security rules |
| **Better templates** | Improved agent file templates, README structure |
| **Agent behavior** | Rules that make AI agents more helpful and less annoying |
| **Edge cases** | Testing checklists, deployment gotchas, naming edge cases |
| **Documentation** | Clearer explanations, better examples, typo fixes |
| **Workflow improvements** | Better task tracking formats, version logging patterns |

### Don't Contribute

| Type | Why |
|------|-----|
| **Stack-specific rules** | "Use React hooks" — belongs in project's `agent/AGENT.md`, not the framework |
| **Personal preferences** | "Tabs vs spaces" — framework is opinionated where it matters, flexible where it doesn't |
| **Tool-specific config** | ESLint configs, Prettier settings — too specific for a portable framework |
| **AI-provider-specific** | "Use Claude 4.6" — framework is agent-agnostic |

### The Portability Test

Before submitting, ask: **"Would this rule apply to ANY project, in ANY language, with ANY AI agent?"**

- If yes → it belongs in CLAUDE.md
- If no → it belongs in a project's `agent/AGENT.md`

---

## PR Guidelines

- **One improvement per PR** — easier to review and merge
- **Explain the why** — not just what changed, but why it's better
- **Show real-world evidence** — "I used this rule on 3 projects and it caught X" is compelling
- **Keep it concise** — the framework's strength is being lightweight. Don't bloat it.
- **Test your changes** — drop the modified CLAUDE.md into a fresh project and verify the agent follows it correctly

---

## Branch Naming

```
improve/testing-rules
improve/agent-behavior
fix/template-typo
add/error-handling-section
docs/better-examples
```

---

## Code of Conduct

- Be respectful and constructive
- Focus on the framework, not the person
- Assume good intent
- Every contribution — no matter how small — is valued

---

## Review Process

- All PRs are reviewed by the framework author ([@aqibmumtaz](https://github.com/aqibmumtaz))
- Expect a response within a few days
- Small fixes (typos, docs) merge quickly
- Framework changes (new rules, modified behavior) may take longer — need real-world validation
- As the community grows, trusted contributors may be added as maintainers

---

## Questions?

Open an issue with the `question` label, or start a discussion in the repo's Discussions tab.

Thank you for helping make AI-assisted development better for everyone.
