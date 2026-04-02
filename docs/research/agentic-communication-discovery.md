# Discovery: Asynchronous Agentic Communication via Shared Specification

> **Date:** April 2, 2026
> **Context:** Observed during Portable Spec Kit v0.2.4 deployment across multiple projects
> **Author:** Dr. Aqib Mumtaz

## The Discovery

Two independent AI agent sessions — with no direct communication channel — coordinated behavior through a shared markdown specification file. Agent A wrote versioning rules into `portable-spec-kit.md`. Agent B, in a completely separate project and session, read those rules and autonomously restructured project files, reported what changed, and continued working.

**No API calls. No message queue. No orchestrator. Just a markdown file.**

## How It Works

```
Agent A (Session 1, Project A)          Agent B (Session 2, Project B)
    │                                        │
    ▼                                        ▼
Writes rules + version bump             Reads rules from
into portable-spec-kit.md               portable-spec-kit.md
    │                                        │
    ▼                                        ▼
Pushes to git                           Pulls from git
    │                                        │
    └───── portable-spec-kit.md ─────────────┘
               (shared protocol)
                    │
                    ▼
           Agent B detects version change
           Reads new rules
           Executes: restructures files
           Reports to user
           Continues working
```

## Key Principles

### 1. Specification as Communication Protocol
The markdown file is not just documentation — it's a **protocol** that agents interpret and execute. Rules encoded by one agent are decoded and followed by another.

### 2. Version as Signal
The `<!-- Framework Version: v0.2.4 -->` comment acts as a **trigger signal**. When Agent B detects a version mismatch against its stored version, it knows new instructions exist and executes them.

### 3. Git as Transport Layer
Git push/pull is the **transport mechanism** — asynchronous, reliable, auditable. No real-time connection needed between agents.

### 4. Rules as Messages
Instead of sending explicit messages ("restructure TASKS.md"), Agent A writes rules ("If framework version changed → restructure all agent files"). Agent B interprets these rules in its own context and executes appropriately.

### 5. Self-Executing Agents
Agent B doesn't need to be told "go check for updates." It reads the specification at session start, detects the version mismatch, and acts autonomously.

### 6. Anonymous Communication
The agents don't know about each other. Agent A doesn't know which agents will read its rules. Agent B doesn't know which agent wrote the rules. The specification is the only shared surface.

## What Was Observed

```
Agent A (this session):
- Wrote versioning rules
- Defined restructure behavior
- Set version to v0.2.4
- Pushed to git

Agent B (other project, different session):
- Read portable-spec-kit.md v0.2.4
- Detected: Framework field missing from AGENT_CONTEXT.md
- Autonomously restructured:
  - AGENT_CONTEXT.md → added Framework: v0.2.4
  - TASKS.md → version-based headings
  - RELEASES.md → framework version range
- Reported all changes to user
- Preserved all existing content
- Continued working
```

## Architecture Components

| Component | Role | Analogy |
|-----------|------|---------|
| `portable-spec-kit.md` | Shared protocol / message bus | Pub/Sub topic |
| `<!-- Framework Version -->` | Signal / trigger | Message ID |
| `agent/AGENT_CONTEXT.md` | Local state / last known version | Consumer offset |
| Git push/pull | Transport layer | Message delivery |
| Rules in markdown | Encoded instructions | Message payload |
| AI agent | Interpreter + executor | Consumer process |

## Implications for Future Systems

### Multi-Agent Coordination Without Infrastructure
No need for:
- Agent-to-agent APIs
- Message queues (RabbitMQ, Kafka)
- Orchestration services
- Real-time connections

Just: **shared specification file + git + versioning**

### Possible Extensions

1. **Agent-to-Agent Task Delegation**
   - Agent A writes a task in TASKS.md: "Needs: backend API for auth"
   - Agent B (working on backend) reads it, builds it, marks done
   - Coordination through shared files, not direct communication

2. **Multi-Project Dependency Management**
   - Project A's SPECS.md references Project B's API
   - When Project B updates its API spec, Project A's agent detects the change
   - Auto-updates integration code

3. **Team Coordination**
   - Multiple developers, each with their own agent
   - All agents read the same specification file
   - Each agent's AGENT_CONTEXT.md tracks its own state
   - User profiles (per-user files) let each agent personalize

4. **Cascading Updates**
   - Kit author updates a testing rule
   - All projects using the kit get the update on next pull
   - All agents restructure accordingly
   - Consistent standards across entire organization

5. **Event-Driven Agent Workflows**
   - Version change = event trigger
   - Rules define event handlers
   - Agents are event consumers
   - Git is the event log

### Scaling Patterns

```
Level 1: Single agent, single project (current)
Level 2: Single agent, multiple projects (tested — works)
Level 3: Multiple agents, single project (team scenario — planned)
Level 4: Multiple agents, multiple projects (organization-wide — possible)
Level 5: Cross-organization (shared spec kit forks — future)
```

## Why This Matters

Traditional multi-agent systems require:
- Complex orchestration infrastructure
- Agent discovery and registration
- Message serialization/deserialization
- Error handling, retries, dead letter queues
- Real-time availability

This approach requires:
- One markdown file
- Git
- AI agents that can read and follow instructions

**The specification IS the infrastructure.**

## Research Questions

1. What is the maximum complexity of rules that agents reliably execute from markdown?
2. How many agents can coordinate through a single specification file?
3. Can agents write rules for other agents (self-modifying protocol)?
4. What happens when agents disagree on rule interpretation?
5. Can this pattern replace traditional CI/CD pipelines?
6. How does this scale to enterprise (100+ projects, 50+ developers)?

## References

- Portable Spec Kit framework: https://github.com/aqibmumtaz/portable-spec-kit
- Observation context: v0.2.4 deployment, restructure trigger across projects
- Related concepts: Event sourcing, CQRS, pub/sub, spec-persistent development
