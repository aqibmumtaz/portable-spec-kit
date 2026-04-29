# Skill — Security Baseline (v0.6.14+)

> **When loaded:** Phase 6 of `project-orchestration.md` — kit scaffolds with security wired in by default, not retrofitted later.
> **What it does:** ships auth + input validation + middleware + secret hygiene + error handling that meets OWASP Top 10 (2021) baseline.
> **Why:** every line of "TODO: add auth later" is a vulnerability waiting to ship. Kit-generated apps must be secure-by-default.

The kit applies the same OWASP Top 10 mitigation patterns regardless of stack — only the implementation differs (Next.js / Express / FastAPI / Go / Spring). **What** is invariant; **how** is stack-specific.

## OWASP Top 10 (2021) — kit baseline mitigations

### A01 — Broken Access Control

**Pattern:** every protected resource verifies (user_id_from_session == resource.owner_id) at the data layer, not just the route layer. Never trust client-supplied user_id.

**Scaffold ships:**
- Authz middleware that injects `req.session.userId` from JWT/session
- Repo / service layer ALWAYS uses `req.session.userId`, never `req.body.userId`
- Tests: adversarial test per protected endpoint (log in as A, request B's resource → 403)

### A02 — Cryptographic Failures

**Pattern:** modern hashing (Argon2id), TLS everywhere, no homegrown crypto.

**Scaffold ships:**
- **Passwords:** Argon2id with parameters `memory=19MiB, iterations=2, parallelism=1` (OWASP password storage cheat sheet)
- **Sessions:** JWT signed with HS256 + 256-bit secret OR opaque session tokens stored in DB (preferred for revocation)
- **Cookies:** `Secure=true; HttpOnly=true; SameSite=Lax` (or `Strict` for sensitive)
- **At rest:** if PII / payment data → field-level encryption with AES-256-GCM; key in KMS or env
- **In transit:** TLS 1.3 only; HSTS preload header; reject HTTP entirely

### A03 — Injection

**Pattern:** parameterized queries always; never string-interpolate user input into SQL / LDAP / OS commands.

**Scaffold ships:**
- ORM by default (Prisma / SQLAlchemy / Hibernate / sqlx) — these enforce parameterization
- If raw SQL needed → escape via driver's parameterizer ($1, $2, ?, etc.) — never via string concat
- Input validation at every boundary using **Zod** (TS) / **Pydantic** (Python) / **validator** (Go)
- No `eval()`, no `exec()`, no `subprocess(shell=True)`

**Test:** SQL injection attempt in any text input field → 400 with validation error, not 500 / data leak.

### A04 — Insecure Design

**Pattern:** threat-model the app's primary flows. Each PR adds the threat-model row for its feature.

**Scaffold ships:**
- `agent/security/threat-model.md` template (STRIDE per primary flow)
- Threat-model rows added to design plans (`agent/design/f{N}.md` Security section)
- Reflex Dim 5 (security) probes adversarial scenarios per feature

### A05 — Security Misconfiguration

**Pattern:** secure defaults, no debug mode in prod, minimal attack surface.

**Scaffold ships:**
- `.env.example` with placeholders; `.env` gitignored (every project, no exception)
- Production config: `NODE_ENV=production` / `DEBUG=false` / stack traces hidden
- HTTP headers: CSP (default-src 'self'), X-Content-Type-Options nosniff, X-Frame-Options DENY, Referrer-Policy strict-origin
- CORS: explicit allowlist, never `*` for credentialed endpoints
- DB: least-privilege user (no DROP, no superuser); separate read-only user for analytics

### A06 — Vulnerable + Outdated Components

**Pattern:** automated dependency scanning + pinned versions.

**Scaffold ships:**
- `package.json` / `requirements.txt` / `go.mod` with explicit versions (no `latest`, no caret ranges for security-critical)
- GitHub Dependabot config (`.github/dependabot.yml`) — weekly scan, auto-PR security patches
- CI step: `npm audit` / `pip audit` / `govulncheck` — fail build on high+ severity
- Lockfile committed (`package-lock.json` / `poetry.lock`)

### A07 — Identification + Authentication Failures

**Pattern:** strong auth flow with all the standard hardening.

**Scaffold ships:**
- Email verification on signup (token expires in 1h)
- Password reset via email token (expires in 15min, single-use)
- Rate limit on login: 5 attempts per IP per 15min, 10 per email per 15min
- Account lockout after 10 failed attempts (15min cooldown)
- Session expiry: 30 days inactive, 7 days absolute (config)
- 2FA optional via TOTP (recommended for admin / sensitive accounts)
- Logout: invalidate session server-side (don't trust client to clear)

### A08 — Software + Data Integrity Failures

**Pattern:** verify supply chain, sign artifacts, audit-log critical actions.

**Scaffold ships:**
- npm/pip pinned to lockfile + integrity hashes (SHA-512)
- CI/CD pipeline scripts under version control + reviewed via PR
- Audit log table: `audit_log(timestamp, user_id, action, resource_id, ip, details)` for create/update/delete on sensitive tables
- Cryptographic signing of release artifacts (cosign for containers, GPG for tarballs)

### A09 — Security Logging + Monitoring Failures

**Pattern:** log security-relevant events; alert on anomalies.

**Scaffold ships:**
- Structured JSON logs (timestamp, level, request_id, user_id, route, status, latency)
- Logged events: authn success/fail, authz denial, validation errors with input context (sanitized), exceptions
- Log retention: 90 days minimum, 1 year for audit-log table
- Alerts: failed-login spikes, 401/403 spikes, exception spikes, latency anomalies
- Integration: stdout JSON → cloud logs (CloudWatch / Datadog / Sentry / Better Stack)

**Never log:** passwords, tokens, full credit card, full SSN, request body for sensitive endpoints.

### A10 — Server-Side Request Forgery (SSRF)

**Pattern:** if app fetches user-supplied URLs, allowlist domains + reject internal IPs.

**Scaffold ships (only if applicable):**
- URL validator: blocks `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, `::1`, fc00::/7
- Hostname allowlist for any external fetch (e.g., image proxies)
- Egress proxy / firewall rules in production (block outbound except allowlisted)

## Auth scaffolding (canonical pattern)

Every kit-generated app with users gets:

```
src/auth/
  schema.ts              # Zod schemas for signup / login / reset
  password.ts            # Argon2id hash + verify
  session.ts             # createSession / validateSession / revokeSession
  middleware.ts          # requireAuth / requireRole
  routes/
    signup.ts            # POST /api/v1/auth/signup
    login.ts             # POST /api/v1/auth/login
    logout.ts            # POST /api/v1/auth/logout
    verify-email.ts      # GET /api/v1/auth/verify?token=
    reset-request.ts     # POST /api/v1/auth/reset
    reset-confirm.ts     # POST /api/v1/auth/reset/confirm
  __tests__/
    signup.test.ts
    login.test.ts
    rate-limit.test.ts
    adversarial.test.ts  # SQL injection, brute-force, token reuse, session fixation
```

## Input validation pattern (every endpoint, every boundary)

```typescript
// route handler — Next.js / Express style
import { signupSchema } from '@/auth/schema';

export async function POST(req: Request) {
  // Parse + validate. Throws ZodError on bad input → caught by error middleware → 400.
  const body = signupSchema.parse(await req.json());
  // body is now type-safe and validated. Handler never sees malformed input.
  ...
}
```

Pattern enforced everywhere: route boundaries, queue consumers, webhook handlers, file uploads.

## Middleware stack (canonical order)

```
request →
  1. requestId middleware       (assign UUID, propagate to logs)
  2. logging middleware          (request start log)
  3. CORS middleware             (allowlist check)
  4. Helmet / security headers   (CSP, X-Frame-Options, etc.)
  5. Rate limit middleware       (per-IP global + per-route specific)
  6. Body parser                 (size limit: 100kb default, larger for upload routes)
  7. CSRF middleware             (cookie + header double-submit)
  8. Auth middleware             (session validation; injects user)
  9. Authz middleware            (role / scope check; per-route)
  10. Validation                 (Zod / Pydantic schema parse)
  11. Handler                    (your business logic)
  12. Error formatter            (catch all errors, format consistently, no stack-trace leaks)
  13. Logging finalizer          (request end log with status + latency)
→ response
```

## Error handling — no stack-trace leaks

```typescript
function formatError(err: unknown): { status: number; body: ErrorBody } {
  if (err instanceof ZodError) {
    return { status: 400, body: { error: 'validation_failed', details: err.flatten() } };
  }
  if (err instanceof AuthError) {
    return { status: 401, body: { error: 'unauthorized' } };
  }
  if (err instanceof ForbiddenError) {
    return { status: 403, body: { error: 'forbidden' } };
  }
  if (err instanceof NotFoundError) {
    return { status: 404, body: { error: 'not_found' } };
  }
  // Unknown error — log full stack server-side, return generic 500 to client
  logger.error({ err, requestId }, 'unhandled error');
  return { status: 500, body: { error: 'internal_error', requestId } };
}
```

Production responses: `{ error: 'code', message: 'human-readable', details?: object }`. Never expose `stack`, `code`, or internal paths.

## Secret management

- **`.env.example`** committed with placeholders: `OPENAI_API_KEY=paste-your-key-here`
- **`.env`** in `.gitignore` (every project, no exception)
- **Production secrets** in vault (1Password / AWS Secrets Manager / HashiCorp Vault / Doppler) — never in repo, never in CI logs
- **CI:** secrets injected as encrypted env vars (GitHub Actions `secrets:` block)
- **Pre-commit hook:** scan staged files for known secret patterns (kit's `psk-sync-check.sh` already does this — 12 patterns)
- **Rotation:** documented procedure in `agent/security/secret-rotation.md`; rotate quarterly minimum

## API hardening defaults

- **Versioning:** `/api/v1/...` from day one (never `/api/...`)
- **Rate limiting:** global default 100 req/min per IP; per-route overrides for sensitive endpoints
- **HTTPS only:** redirect HTTP → HTTPS at edge (CDN / load balancer); HSTS header in app
- **Idempotency:** POST/PUT for write ops; idempotency-key header for retries on critical writes (payments, orders)
- **Pagination:** all list endpoints support `?limit=&cursor=` (cursor-based, not offset — scales)
- **Response shape:** consistent envelope `{ data: ..., meta: { ... } }` or RFC 7807 problem+json for errors
- **OpenAPI / spec:** `/api/v1/openapi.json` auto-generated from route definitions

## Frontend hardening

- **No `dangerouslySetInnerHTML`** without DOMPurify sanitization + comment explaining why it's safe
- **No `eval`, no `Function(string)`** in app code
- **External resources:** SRI hashes for any `<script src="https://...">` from CDN
- **CSP header:** `default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; ...` (refine over time)
- **No native dialogs** (`alert()` / `confirm()` / `prompt()`) — replace with custom UI per kit's response-format rule
- **Form auto-fill:** `autocomplete` attrs on every form field (helps users + screen readers)
- **CSRF:** double-submit cookie pattern OR SameSite=Strict on session cookies (modern browsers)

## Adversarial test pattern (per feature)

Every feature ships at least one **adversarial test** alongside the happy-path tests:

```typescript
// happy-path
test('user can read their own posts', async () => {
  const userA = await createUser();
  const post = await createPost(userA, { title: 'mine' });
  const got = await api.getPost(post.id, { auth: userA });
  expect(got.id).toBe(post.id);
});

// adversarial
test('user cannot read another user\'s posts', async () => {
  const userA = await createUser();
  const userB = await createUser();
  const post = await createPost(userA, { title: 'mine' });
  const res = await api.getPost(post.id, { auth: userB });
  expect(res.status).toBe(403);  // not 200, not 404 (would leak existence)
});
```

Reflex's Layer 3 (behavioral verification) demands this pattern — adversarial tests are not optional.

## Confirm-with-user gate

After Phase 6 scaffold:

```
Security baseline applied:
  ✓ Auth: Argon2id + JWT + email verify + reset flow
  ✓ Input validation: Zod schemas at every boundary
  ✓ Rate limit: 100 req/min default + 5/15min on /auth/login
  ✓ Headers: CSP + HSTS + X-Frame-Options DENY
  ✓ Error handling: no stack-trace leaks
  ✓ Secret hygiene: .env.example committed, .env gitignored
  ✓ Audit log table: audit_log(...)
  ✓ Adversarial test pattern in __tests__/

Want to:
  (a) Approve → continue to feature implementation
  (b) Add 2FA / MFA (TOTP)
  (c) Add SSO (SAML / OIDC)
  (d) Stricter rate limits (specify)
  (e) Add field-level encryption for [field]
  (f) Skip security baseline (NOT RECOMMENDED — only for prototypes you'll throw away)
```

## Anti-patterns

- **Never `auth: 'todo'`.** No "we'll add auth in v2." If the app has users, auth ships in v1.
- **Never log secrets.** Tokens, passwords, payment data — never in logs, even at debug level.
- **Never trust the client.** Every authz check happens server-side, even if the UI hides the button.
- **Never `*` CORS.** Allowlist explicit origins. If "any origin" needed → it's a public read-only endpoint, not a credentialed one.
- **Never roll your own crypto.** Use established libs (libsodium / web crypto / language standard).
- **Never disable security in prod.** No `NODE_ENV=development` in prod; no `DEBUG=true`; no test fixtures shipped.

## Compliance addendum

If Phase 2 research flagged GDPR / HIPAA / PCI / etc., scaffold the corresponding controls:

- **GDPR:** consent banner, data-export endpoint, data-delete endpoint, DPA template at `agent/legal/`
- **HIPAA:** BAA-required hosting note in PLANS, audit-log retention 6+ years, encryption-at-rest mandatory
- **PCI:** never store full card; use tokenizer (Stripe Elements); SAQ-A scope minimum
- **CCPA:** "Do not sell my info" link, deletion request endpoint
- **COPPA:** age-gate before signup, parental consent flow if under-13
