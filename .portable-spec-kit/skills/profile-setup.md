<!-- Section Version: v0.5.5 -->
### First Session — Profile Setup (no profile found anywhere)
1. Detect username: `git config user.name` → slugified (lowercase, spaces → dashes) — used for filename
2. Fetch GitHub profile via `gh api user` for full name/bio (if available and authenticated — if not, ask user manually)
3. Greet user by full name: "Welcome, {Name}! Let me set up your development profile."
4. Ask 3 preference questions (Enter = use recommended, or type custom):

   **Communication style?**
   - (a) direct and concise ← RECOMMENDED
   - (b) direct, data-driven, prefers comprehensive analysis with tables and evidence
   - (c) conversational and collaborative, prefers discussing ideas and thinking through problems together
   - (or type your own)
   - Press Enter to use recommended (a)

   **Working pattern?**
   - (a) iterative — starts brief, expands scope, builds ambitiously over time ← RECOMMENDED
   - (b) plan-first — defines full specs and architecture before writing any code
   - (c) prototype-fast — gets something working quickly, then refines and polishes
   - (or type your own)
   - Press Enter to use recommended (a)

   **AI delegation?**
   - (a) AI does 70%, user guides 30% — AI proposes approach, user approves before execution ← RECOMMENDED
   - (b) AI does 90%, user reviews 10% — present ready-to-act outputs, not questions
   - (c) 50/50 collaboration — discuss and decide together before each major step
   - (or type your own)
   - Press Enter to use recommended (a)

5. Show profile summary: "Your profile: ... Looks good? (Enter = yes, or type changes)"
6. Save to `~/.portable-spec-kit/user-profile/user-profile-{username}.md` (global)
7. Copy to `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md` (committed)

### New Project Setup (profile exists in global)
1. Load profile from global `~/.portable-spec-kit/user-profile/user-profile-{username}.md`
2. Show profile to user: "Using your profile: ..."
3. "Keep or customize for this project? (Enter = keep)"
   - **(a) Keep** → copy to `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md` as-is
   - **(b) Customize** → ask 3 questions with CURRENT answer highlighted + RECOMMENDED:
     - Each question shows current global answer as CURRENT and framework default as RECOMMENDED
     - Press Enter to keep current
     - Or pick a/b/c or type custom
     - Show summary → confirm
     - Save to `workspace/.portable-spec-kit/user-profile/user-profile-{username}.md`

---

## Profile Storage

```
Global (home directory — asked once, works everywhere):
~/.portable-spec-kit/user-profile/
└── user-profile-{username}.md

Workspace (committed — persists across pulls, per-user):
workspace/.portable-spec-kit/user-profile/
├── user-profile-{username}.md
├── user-profile-teammate.md
└── ...
```

**Cross-OS home directory:**
- macOS/Linux: `~/.portable-spec-kit/user-profile/`
- Windows: `%USERPROFILE%\.portable-spec-kit\user-profile\`

**Username detection:** `git config user.name` → slugified (lowercase, spaces → dashes). Use `gh api user` for fetching full name/bio for greeting, not for filename.

## Profile Format
```
# User Profile
> Auto-created on first session. Edit anytime.

- **Name** — Education. Expertise.
- Communication style: {selected or custom}
- Working pattern: {selected or custom}
- AI delegation: {selected or custom}
```
