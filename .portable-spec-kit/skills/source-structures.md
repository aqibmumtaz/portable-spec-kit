<!-- Section Version: v0.6.39 -->
### Standard Source Code Structures (by project type)

> **Stack matching rule:** The kit's orchestrator (`psk-orchestrate.sh`) reads the declared
> stack from `agent/PLANS.md` and applies the matching template below during Phase 6 scaffold.
> Directories are created exactly as the template shows — no guessing, no mixing.
>
> **Framework-managed directories** (never listed in project structure — gitignored, user never touches):
> - `node_modules/` — npm/pnpm/yarn puts it at project root; always gitignored; never part of source layout
> - `.next/` — Next.js build cache; always gitignored
> - `.nuxt/` / `.svelte-kit/` — framework build outputs; always gitignored
> - `dist/` / `build/` / `out/` — compiled output; always gitignored

---

**Next.js Full-Stack (colocated) — DEFAULT for single Next.js apps with API routes:**

> Use when: `agent/PLANS.md` Stack declares Next.js with no separate backend language.
> All frontend and backend code lives in one Next.js app. Most common 2025 pattern.

```
my-project/                        ← project root: config files + kit dirs only
├── src/                           ← ALL application code lives here
│   ├── app/                       ← Next.js App Router (pages, layouts, API routes)
│   │   ├── api/                   ← API route handlers (app/api/*)
│   │   │   └── v1/                ← versioned API routes
│   │   ├── (auth)/                ← Auth route group (signin, signup, verify)
│   │   ├── dashboard/             ← Protected user area
│   │   └── layout.tsx / page.tsx  ← Root layout + landing page
│   ├── components/
│   │   ├── ui/                    ← Base primitives (Button, Input, Modal, Toast…)
│   │   ├── layout/                ← Header, Footer, Nav, Sidebar
│   │   └── features/              ← Feature-specific components
│   ├── lib/                       ← Shared utilities, constants, configs
│   │   └── i18n/                  ← Locale files (en.ts, ur.ts…)
│   ├── db/                        ← Database layer
│   │   ├── schema/                ← ORM schema files (Drizzle / Prisma)
│   │   └── migrations/            ← SQL migration files
│   │                              ← drizzle.config.ts → out: "./src/db/migrations"
│   ├── auth/                      ← Auth config, session helpers (NextAuth / Lucia)
│   ├── middleware/                ← Edge middleware (rate-limit, auth guard)
│   ├── queue/                     ← Background job producers + consumers
│   ├── hooks/                     ← Custom React hooks
│   ├── types/                     ← Shared TypeScript types / interfaces
│   └── worker.ts                  ← Worker entry point (if applicable)
├── public/                        ← Static file serving (Next.js requires at root)
│   └── logo.svg                   ← Framework constraint — cannot be moved into src/
├── tests/                         ← All tests (feature-wise naming: f1-*.test.ts…)
│   └── e2e/                       ← Playwright specs (require live server — see reflex config)
├── docs/                          ← Project documentation
├── ard/                           ← Architecture docs (HTML + PDF)
├── agent/                         ← Kit management files
├── package.json
├── tsconfig.json
├── next.config.ts
├── drizzle.config.ts              ← out: "./src/db/migrations"
├── tailwind.config.ts
├── vitest.config.ts
├── playwright.config.ts
├── .env.example                   ← placeholder values only — never real secrets
└── .gitignore                     ← includes: node_modules/ .next/ .env.local
```

---

**Next.js Frontend-Only SPA — for apps where backend is a separate service:**

> Use when: `agent/PLANS.md` Stack declares Next.js + a separate backend runtime
> (FastAPI, Express, Django, Rails, Go). Frontend and backend are in separate repos
> or separate root directories.

```
frontend/
├── src/
│   ├── app/               ← Next.js App Router (pages, layouts)
│   ├── components/
│   │   ├── ui/            ← Base primitives
│   │   ├── layout/        ← Header, Footer, Nav
│   │   └── features/      ← Feature-specific components
│   ├── hooks/             ← Custom React hooks
│   ├── lib/               ← API client, utilities, constants
│   ├── types/             ← TypeScript types
│   └── styles/            ← Global styles, theme tokens
├── public/                ← Static assets (framework constraint — at frontend/ root)
└── tests/
```

---

**Python Backend (FastAPI / Flask / Django):**

```
backend/
├── app/
│   ├── main.py            ← App entry point
│   ├── config.py          ← Settings (Pydantic BaseSettings)
│   ├── auth.py            ← Authentication middleware
│   ├── api/               ← Route handlers (grouped by feature)
│   ├── models/            ← Database models (SQLAlchemy / Pydantic)
│   ├── schemas/           ← Request / response schemas
│   ├── services/          ← Business logic (AI, email, PDF gen, etc.)
│   └── utils/             ← Helpers, formatters
├── tests/
├── Dockerfile
└── requirements.txt
```

---

**Full Stack (separate services) — polyglot stack, independently deployed:**

> Use when: frontend and backend are different runtimes (e.g. Next.js + FastAPI).
> Each subdirectory is its own deployable unit with its own `package.json` / `requirements.txt`.

```
my-project/
├── frontend/              ← Next.js app (uses Next.js Frontend-Only SPA template inside)
├── backend/               ← API server (uses Python Backend template inside)
├── shared/                ← Shared types, constants between frontend + backend
├── scripts/               ← Build scripts, deploy scripts, data migrations
├── tests/                 ← Integration + e2e tests spanning both services
├── docs/
├── ard/
└── agent/                 ← Kit management files (one agent/ for the whole monorepo)
```

---

**Full Stack + Mobile:**

```
my-project/
├── frontend/              ← Web app (Next.js)
├── mobile/                ← Mobile app (React Native / Flutter)
├── backend/               ← API server
├── shared/                ← Shared types, constants across all clients
├── scripts/               ← Build scripts, deployment scripts
├── docs/
├── ard/
└── agent/
```

---

**Next.js Monorepo (Turborepo / pnpm workspaces):**

> Use when: multiple apps or packages share code in one repo.
> Each app inside `apps/` uses the colocated template above.

```
my-monorepo/
├── apps/
│   ├── web/               ← Next.js app (colocated template inside)
│   └── docs/              ← Documentation site
├── packages/
│   ├── shared/            ← Shared types + utilities
│   ├── ui/                ← Shared component library
│   └── config/            ← Shared tsconfig, eslint, tailwind presets
├── tests/                 ← Cross-app integration tests
├── turbo.json             ← Turborepo pipeline config
├── package.json           ← Workspace root (pnpm/yarn workspaces)
├── docs/
├── ard/
└── agent/
```

---

**Mobile App — Cross-Platform (React Native / Flutter):**

```
mobile/
├── src/
│   ├── screens/           ← Screen components (Home, Profile, Settings)
│   ├── components/
│   │   ├── ui/            ← Base components (buttons, inputs, cards)
│   │   └── features/      ← Feature-specific components
│   ├── navigation/        ← Navigation stack, tab config, deep linking
│   ├── services/          ← API clients, storage, push notifications
│   ├── hooks/             ← Custom hooks
│   ├── lib/               ← Utilities, constants, helpers
│   ├── types/             ← TypeScript type definitions
│   ├── store/             ← State management (Redux, Zustand, Context)
│   └── assets/            ← Images, fonts, icons (bundled)
├── android/               ← Native Android config
├── ios/                   ← Native iOS config
├── tests/
└── app.json               ← App config (name, version, permissions)
```

---

**Android Native (Kotlin / Java):**

```
app/
├── src/
│   ├── main/
│   │   ├── java/com/example/    ← Source code (activities, fragments, viewmodels)
│   │   │   ├── ui/              ← Screens, adapters, custom views
│   │   │   ├── data/            ← Repositories, models, database (Room)
│   │   │   ├── network/         ← API clients (Retrofit), DTOs
│   │   │   ├── di/              ← Dependency injection (Hilt/Dagger)
│   │   │   └── utils/           ← Helpers, extensions, constants
│   │   ├── res/                 ← Resources (layouts, drawables, strings, themes)
│   │   └── AndroidManifest.xml  ← Permissions, activities, services
│   ├── test/                    ← Unit tests
│   └── androidTest/             ← Instrumented tests
├── build.gradle.kts             ← App-level build config
└── gradle/                      ← Gradle wrapper
```

---

**iOS Native (Swift / SwiftUI):**

```
App/
├── Sources/
│   ├── App/                     ← App entry point, app delegate
│   ├── Views/                   ← SwiftUI views / UIKit view controllers
│   ├── ViewModels/              ← View models (MVVM)
│   ├── Models/                  ← Data models, Codable structs
│   ├── Services/                ← API clients (URLSession/Alamofire), storage
│   ├── Navigation/              ← Coordinators, router
│   └── Utils/                   ← Extensions, helpers, constants
├── Resources/                   ← Assets.xcassets, Localizable.strings, Info.plist
├── Tests/                       ← Unit tests (XCTest)
├── UITests/                     ← UI tests
└── App.xcodeproj                ← Xcode project config
```

---

**Document / Research Project (no code):**

```
├── plan/                  ← Main deliverables (HTML, Word, PDF)
├── research/              ← Working data, analysis (not user-facing)
└── templates/             ← Document templates, email drafts
```
