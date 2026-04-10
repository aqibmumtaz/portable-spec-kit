> **Purpose:** What to build — requirements, features, acceptance criteria.
> **Role:** Defined before dev, refined during development.

# SPECS.md — My App

## Overview
A task management app for small teams. Real-time collaboration, simple UI, free to host.

## Requirements
| # | Requirement |
|---|-------------|
| R1 | Users can create, edit, delete tasks |
| R2 | Tasks have: title, description, assignee, due date, status |
| R3 | Real-time updates when teammates change tasks |
| R4 | Team workspaces with invite links |
| R5 | Authentication (email + Google) |

## Features
| # | Feature | Req | Priority | Status | Tests |
|---|---------|:---:|----------|:------:|-------|
| F1 | Auth (login/signup/session) | R5 | High | [x] | tests/auth.test.js |
| F2 | Task CRUD | R1, R2 | High | [x] | tests/tasks.test.js |
| F3 | Real-time sync | R3 | High | [ ] | |
| F4 | Team workspaces | R4 | Medium | [ ] | |
| F5 | Due date notifications | R2 | Medium | [ ] | |
| F6 | Mobile responsive | R1 | Medium | [ ] | |
| F7 | Task comments | R2 | Low | [ ] | |
| F8 | File attachments | R2 | Low | [ ] | |

## Scope
- **In scope:** Task management, teams, real-time, auth
- **Out of scope (future):** Calendar view, Gantt charts, integrations (Slack, GitHub)

## Acceptance Criteria
- [x] User can sign up, log in, log out
- [x] User can create a task with title and description
- [ ] Task status updates appear in real-time for all team members
- [ ] Team owner can invite members via link
- [ ] Works on mobile and desktop
- [ ] Every done feature has a test reference (R→F→T chain)
