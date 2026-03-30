> **Purpose:** What to build — requirements, features, acceptance criteria.
> **Role:** Defined before dev, refined during development.

# SPECS.md — My App

## Overview
A task management app for small teams. Real-time collaboration, simple UI, free to host.

## Requirements
- Users can create, edit, delete tasks
- Tasks have: title, description, assignee, due date, status
- Real-time updates when teammates change tasks
- Team workspaces with invite links
- Authentication (email + Google)

## Features
| # | Feature | Priority | Status |
|---|---------|----------|:------:|
| 1 | Auth (login/signup/session) | High | [x] |
| 2 | Task CRUD | High | [x] |
| 3 | Real-time sync | High | [ ] |
| 4 | Team workspaces | Medium | [ ] |
| 5 | Due date notifications | Medium | [ ] |
| 6 | Mobile responsive | Medium | [ ] |
| 7 | Task comments | Low | [ ] |
| 8 | File attachments | Low | [ ] |

## Scope
- **In scope:** Task management, teams, real-time, auth
- **Out of scope (future):** Calendar view, Gantt charts, integrations (Slack, GitHub)

## Acceptance Criteria
- [ ] User can sign up, log in, log out
- [ ] User can create a task with title and description
- [ ] Task status updates appear in real-time for all team members
- [ ] Team owner can invite members via link
- [ ] Works on mobile and desktop
