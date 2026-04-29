# Skill — UI Design System (v0.6.14+)

> **When loaded:** Phase 5 of `project-orchestration.md` — kit generates a polished design system before scaffolding code.
> **What it does:** produces a complete, stack-aware design system as `agent/design/ui-system.md` (tokens) + per-stack token export (Tailwind config / SwiftUI extension / Material theme / CSS custom props).
> **Why:** apps without a design system end up with inconsistent UI that's painful to re-skin. Apps with one feel polished from day one.

The kit ships polished defaults that are **not opinionated about brand** — palette, font, spacing are derived from the project's domain (e.g., a finance app gets blue + serif; a creative tool gets vibrant + sans). The agent tunes per-project, but the structure is consistent.

## Inputs

- **Domain** (from research dimension 1) — informs aesthetic
- **Constraints** (from Phase 1) — mobile-first / accessibility / dark mode required
- **User preference** (optional) — *"I want a dark, minimal feel"* / *"playful, colorful"*
- **Stack** (from PLANS) — determines export format

## What the design system contains

### 1. Color tokens (8-color palette × 2 modes)

Light + dark mode required by default (system or user-preference toggle). Eight semantic roles:

| Token | Light mode example | Dark mode example | Use |
|---|---|---|---|
| `primary` | `#3B82F6` (indigo-500) | `#60A5FA` (indigo-400) | Brand actions, links |
| `accent` | `#A855F7` (purple-500) | `#C084FC` (purple-400) | Secondary highlights, badges |
| `success` | `#10B981` (emerald-500) | `#34D399` (emerald-400) | Confirmations, positive |
| `warn` | `#F59E0B` (amber-500) | `#FBBF24` (amber-400) | Warnings, pending states |
| `error` | `#EF4444` (red-500) | `#F87171` (red-400) | Errors, destructive |
| `info` | `#06B6D4` (cyan-500) | `#22D3EE` (cyan-400) | Informational |
| `surface` | `#FFFFFF` / `#F9FAFB` / `#F3F4F6` (3 layers) | `#0A0A0A` / `#171717` / `#262626` | Backgrounds, cards |
| `text` | `#111827` / `#374151` / `#6B7280` (3 emphasis levels) | `#F9FAFB` / `#D1D5DB` / `#9CA3AF` | Foreground, prose |

**Contrast minimums (WCAG AA):**
- `text` on `surface` ≥ 4.5:1 (body text)
- `text-secondary` on `surface` ≥ 4.5:1 (small text)
- `primary` on `surface` ≥ 3:1 (large text + UI components)

The agent picks specific hex values per project — base on domain (finance → cool blues; food → warm oranges; healthcare → calm greens; productivity → neutral grays + one accent).

### 2. Typography scale

Two font choices: **heading font** + **body font**. Stack-aware defaults:

| Stack | Heading | Body |
|---|---|---|
| Web (Next.js) | Inter Tight (Google Fonts) | Inter (Google Fonts) |
| iOS (SwiftUI) | SF Pro Rounded | SF Pro Text |
| Android (Compose) | Google Sans Display | Google Sans Text |
| Desktop (Tauri) | Inter Tight | Inter |

Type scale (8 sizes — modular 1.250 ratio = "major third"):

| Token | rem | px (base 16) | Use |
|---|---|---|---|
| `xs` | 0.75 | 12 | Captions, footnotes |
| `sm` | 0.875 | 14 | Body small, labels |
| `base` | 1 | 16 | Body |
| `lg` | 1.125 | 18 | Lead, large body |
| `xl` | 1.25 | 20 | Card titles |
| `2xl` | 1.5 | 24 | Section heads (H3) |
| `3xl` | 1.875 | 30 | Page heads (H2) |
| `4xl` | 2.25 | 36 | Display (H1) |

Line-heights:
- Tight (1.25) for headings 2xl+
- Normal (1.5) for body lg / base
- Relaxed (1.625) for prose-heavy content

Font weights: 400 / 500 / 600 / 700 (avoid 100-300, hard to read on screens).

### 3. Spacing grid (4/8 base)

Always multiples of 4px. Common scale:

| Token | px | Use |
|---|---|---|
| `0.5` | 2 | hairline borders |
| `1` | 4 | tight gaps |
| `2` | 8 | inline icon-text |
| `3` | 12 | form-field internal |
| `4` | 16 | card internal padding |
| `6` | 24 | section spacing |
| `8` | 32 | between cards |
| `12` | 48 | major section dividers |
| `16` | 64 | hero / page top |
| `24` | 96 | full-page section |

**Rule:** never use values not on the grid. `13px` instead of `12px` is a code smell.

### 4. Component primitives (12 minimum)

Every project ships with these 12 working components (stack-aware implementations):

1. **Button** — variants: `primary` / `secondary` / `ghost` / `destructive` × sizes: `sm` / `md` / `lg` × states: default / hover / focus / active / disabled / loading
2. **Input** — text, with label / helper / error states + icon-prefix support
3. **Select / Dropdown** — accessible (combobox pattern), keyboard nav, search
4. **Card** — header / body / footer slots, shadow + border variants
5. **Modal** — overlay + esc-to-close + focus trap + return-focus on close
6. **Toast** — 4 severities (success/warn/error/info), auto-dismiss + action button
7. **Table** — sortable headers, sticky-header, row selection, pagination
8. **Navbar** — logo + primary nav + user menu + mobile drawer
9. **Sidebar** — collapsible, multi-level, mobile-overlay
10. **Breadcrumb** — accessible (aria-current), truncation for long paths
11. **Tabs** — keyboard nav (arrow keys), aria-selected, lazy content
12. **Skeleton** — loading placeholder for cards + tables + lists

Each ships with a **Storybook entry** (or stack equivalent — SwiftUI Previews, Compose Previews, etc.) showing all states.

### 5. Motion presets

Three durations + three easings:

| Duration | Use |
|---|---|
| `instant` 100ms | Hover, focus indicators |
| `quick` 200ms | Click feedback, tooltip enter |
| `smooth` 400ms | Modal open, drawer slide, page transitions |

Easings (CSS / SwiftUI / Compose-equivalent):
- `ease-out` (`cubic-bezier(0.0, 0.0, 0.2, 1)`) for entering elements (deceleration)
- `ease-in` (`cubic-bezier(0.4, 0.0, 1.0, 1.0)`) for leaving
- `ease-in-out` (`cubic-bezier(0.4, 0.0, 0.2, 1)`) for elements that move within view

**Motion-reduce respect:** every animation gates on `prefers-reduced-motion: reduce` — instant transitions for users who opt out.

### 6. Breakpoints (mobile-first)

| Token | Min-width | Devices |
|---|---|---|
| `sm` | 640px | Large phones, small tablets |
| `md` | 768px | Tablets |
| `lg` | 1024px | Desktop, laptops |
| `xl` | 1280px | Large desktop |
| `2xl` | 1536px | Wide desktop, ultrawide |

Default to `sm`-up styling unless the design is desktop-only (rare). Test at 320px (iPhone SE) and 1920px (full HD).

### 7. Accessibility tokens

Built into every component:

- **Focus ring:** 2px solid `primary` + 2px offset + visible only on `:focus-visible` (not `:focus`)
- **Contrast modes:** `prefers-contrast: more` swaps to high-contrast palette
- **Keyboard nav:** every interactive element keyboard-reachable; tab order matches visual order; skip-link for nav-heavy pages
- **ARIA:** semantic HTML first; ARIA only where native lacks
- **Screen reader:** sr-only utility class; ARIA-live regions for dynamic content (toasts, errors); descriptive button labels (no icon-only without aria-label)

## Stack-specific exports

### Web (Tailwind + shadcn/ui pattern)

`tailwind.config.ts` extends with:

```ts
theme: {
  extend: {
    colors: { primary: { DEFAULT: '#3B82F6', dark: '#60A5FA' }, ... },
    fontFamily: { heading: ['"Inter Tight"', 'sans-serif'], body: ['Inter', 'sans-serif'] },
    fontSize: { '2xl': ['1.5rem', { lineHeight: '1.25' }], ... },
    spacing: { '4': '1rem', '6': '1.5rem', ... },
    transitionDuration: { 'instant': '100ms', 'quick': '200ms', 'smooth': '400ms' },
    screens: { sm: '640px', md: '768px', lg: '1024px', xl: '1280px', '2xl': '1536px' },
  }
}
```

CSS custom properties in `globals.css`:

```css
:root {
  --color-primary: 59 130 246;  /* RGB triplet for opacity support */
  --color-surface: 255 255 255;
  ...
}
.dark { --color-primary: 96 165 250; ... }
```

12 components ship under `src/components/ui/` (button.tsx / input.tsx / ...).

### iOS (SwiftUI)

```swift
extension Color {
  static let primary = Color("Primary")  // adaptive light/dark via Asset Catalog
  static let surface = Color("Surface")
}
extension Font {
  static let appHeading2xl = Font.custom("SF Pro Rounded", size: 24).weight(.semibold)
}
```

12 components in `Sources/UI/Components/`.

### Android (Compose Material 3)

```kotlin
val LightColors = lightColorScheme(
  primary = Color(0xFF3B82F6),
  surface = Color(0xFFFFFFFF),
  ...
)
val Typography = Typography(headlineMedium = TextStyle(fontFamily = GoogleSansDisplay, fontSize = 24.sp), ...)
```

12 components under `ui/components/`.

### Vanilla CSS

CSS custom properties in `:root` + `.dark`. Component CSS in `components/*.css`. Build a `@import` aggregator.

## Confirm-with-user gate

Show summary palette + sample components rendered (or paste a `dribbble.com`-style mockup). Ask:

```
Design system ready:
  - Palette: [primary hex] / [accent hex] / [...]
  - Heading font: [name]
  - 12 components scaffolded in src/components/ui/

Want to:
  (a) Approve → scaffold project (Phase 6)
  (b) Tweak colors (specify which)
  (c) Different font pairing (specify)
  (d) Add more components beyond the 12
  (e) Different aesthetic ("more playful" / "more minimal" / etc.)
```

## Anti-patterns

- **Don't ship without dark mode.** Even "light-only" projects benefit from at least a CSS-prefers-dark check + future-proofed tokens.
- **Don't hard-code colors / fonts / spacing in components.** Always use tokens. `bg-blue-500` is wrong; `bg-primary` is right.
- **Don't skip motion-reduce.** Animations without `prefers-reduced-motion` are accessibility regressions.
- **Don't pile on components.** 12 is enough for an MVP. Add the 13th when a feature genuinely needs it.
- **Don't reinvent shadcn / SwiftUI / Material defaults.** Extend them; don't replace them.

## Honesty: this is a starting point, not perfection

The kit's design system is **professional-baseline-grade**, not award-winning-grade. A real designer can take this and refine. But for projects without a designer, this is dramatically better than "I made it up as I went" UI — which is what most agent-generated apps look like today.
