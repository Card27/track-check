# CLAUDE.md — Lost Thread / Track-Check

Auto-read by Claude Code every session. Do not delete.

---

## Stack & File Structure

Single file app — everything lives in `index.html`.
Do not create separate files or add a build process.

```
C:\Users\narky\Desktop\track-check\
├── index.html    ← entire app
└── CLAUDE.md     ← this file
```

- Frontend: Vanilla HTML, CSS, JavaScript — no frameworks
- Backend: Supabase (REST via fetch)
- Fonts: Bebas Neue, JetBrains Mono, Inter (Google CDN)
- Hosting: Vercel (auto-deploys on git push, ~30s)
- Git: Git Bash on Windows, account card27, repo track-check

**Push after every change:**
```bash
cd C:\Users\narky\Desktop\track-check
git add . && git commit -m "description" && git push
```

---

## Supabase

- URL: https://taplnkmpbyeovqwflxqs.supabase.co
- Project ref: taplnkmpbyeovqwflxqs
- Auth: always use `session.access_token` as Bearer token — never anon key for authenticated requests
- RLS on all tables: `auth.uid() = user_id`
- All FK constraints reference `auth.users(id) ON DELETE CASCADE` — NOT public.users (that table was dropped)

---

## Schema

All tables include `id, user_id, created_at`. RLS enabled on all.

| Table | Unique constraint | Notes |
|---|---|---|
| profiles | id = auth.users.id | display_name, age, gender, height_cm, weight_lbs, unit_preference, conditions (text[]) |
| body_logs | (user_id, log_date) | weight_lbs numeric |
| workout_logs | (user_id, log_date) | day_type, exercises/cardio/stabilization jsonb |
| feeling_logs | **none** | mental, physical, gut, energy, clarity, stress, sleep_quality, stiffness_minutes, subluxations, notes — multiple rows/day intentional |
| food_logs | (user_id, log_date) | meals/cheats jsonb; total_calories/protein/carbs/fat **numeric** (never integer) |
| supplement_logs | (user_id, log_date) | supplements jsonb |
| water_logs | (user_id, log_date) | total_oz, entries jsonb |
| flare_logs | (user_id, log_date) | status, triggers text[], notes |
| foods | none (global) | No user_id. Public read. source, external_id, macros per 100g, inflammatory_score, serving_size_g |
| recipes | user_id only | Private per user. ingredients jsonb, yield-based macros per serving |

---

## Critical Patterns — Never Deviate

### Save pattern — PATCH first, POST fallback
All tables with `(user_id, log_date)` unique constraint must use this.
Plain POST causes 409 conflicts on same-date rows.

```javascript
async function saveLog(table, userId, dateStr, payload) {
  const base = `${SUPA_URL}/rest/v1/${table}`;
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${session.access_token}`,
    'apikey': SUPA_ANON_KEY,
  };

  const patch = await fetch(`${base}?user_id=eq.${userId}&log_date=eq.${dateStr}`, {
    method: 'PATCH',
    headers: { ...headers, 'Prefer': 'return=minimal' },
    body: JSON.stringify(payload)
  });
  if (patch.ok) return true;

  const post = await fetch(base, {
    method: 'POST',
    headers: { ...headers, 'Prefer': 'return=minimal' },
    body: JSON.stringify({ user_id: userId, log_date: dateStr, ...payload })
  });
  return post.ok;
}
```

### feeling_logs — always INSERT
Never PATCH or upsert. Multiple timestamped entries per day are intentional.

### Date strings — never use toISOString()
`toISOString()` returns UTC and rolls back one day in US timezones.

```javascript
// WRONG
new Date().toISOString().split('T')[0]

// ALWAYS USE THIS
function getLocalDateStr(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}
```

### Data precision
Never round numeric values. Macro and measurement columns are `numeric` type, not integer.

---

## Design System

```css
--bg: #0a0a0a
--accent: #dd2222
--accent2: #ff4444
--green: #44cc77
--red: #e04444
--blue: #4488ee
--purple: #8866dd
--text: #eeeef5
--dim: #7777a0
```

- Dark theme only — no light mode
- Mobile first, max-width 480px
- No confirmation dialogs, single-tap interactions
- Cards: border-radius 8–10px, subtle borders, no heavy shadows
- Fonts: Bebas Neue (headings), JetBrains Mono (numbers), Inter (body)

---

## App Structure

Bottom nav: **DASH / TODAY / WEEK**
Header: hamburger menu (☰) → Profile, Trigger List, App Settings

**DASH:** feeling widget (emoji tap-to-save + expandable 6-dimension detail), weight KPI, week strip
**TODAY tabs:** Workout, Food, Body, Meds, Water, Flare
**WEEK:** lift progression, weight trend, flare history

---

## Scheduled Workout — Exercise Types & Cardio Data

### Exercise type classification (used in `renderScheduledWorkout`, ~line 2210)
- `isTimed`    = `!!time && !sets && !reps` → single Duration (min) input
- `isSetsHold` = `!!sets && !!time && !reps` → SET rows each with hold-time input
- `isSetsReps` = `!!sets && !!reps` → SET rows with reps input
- `isCardio`   = `isTimed && name in [walk, jog, run, bike]` → cardio card (see below)

Custom field inputs (weight/resistance) only render when `custom_name` is non-empty — no default lbs field.

### Cardio saved data in `workout_logs.scheduled_exercises` JSONB

Simple mode:
```json
{ "name": "Walk", "type": "cardio", "done": true, "completed": true,
  "duration": 32, "speed": 3.2, "incline": 1.5, "intervals": [],
  "consecutive_successes": 1, "logged_at": "..." }
```

Interval mode (`speed`/`incline` null at top level, intervals non-empty):
```json
{ "name": "Walk", "type": "cardio", "done": true, "completed": true,
  "duration": 28, "speed": null, "incline": null,
  "intervals": [
    { "duration": 5, "speed": 2.5, "incline": 0 },
    { "duration": 8, "speed": 3.5, "incline": 2 }
  ], "consecutive_successes": 1, "logged_at": "..." }
```

Live state: `schedExState[exId].cardio = { duration, speed, incline, intervalMode, intervals[] }`

Cardio helper functions: `schedCardioField`, `schedCardioToggleInterval`, `schedCardioAddSeg`, `schedCardioRemoveSeg`, `schedCardioSegField`

---

## Coding Rules

- Vanilla JS only — no external libraries unless explicitly asked
- Comments on complex logic
- Use CSS variables for all colors/fonts (already established)
- Mobile-first CSS
- Stack all instructions into a single prompt — no sequential steps
- **Never read the full index.html** — use CLAUDE.md for patterns and target functions/sections by name and TOC line number only
- After every change, remind user: `git add . && git commit -m "description" && git push`

---

## Session Log

<!-- Append a one-line entry after each session. Format: -->
<!-- [YYYY-MM-DD] Added/Fixed: [what], function [name], ~line [N] -->

[2026-06-20] Fixed: timed exercise card type detection (isTimed/isSetsHold/isCardio), renderScheduledWorkout, ~line 2203
[2026-06-20] Fixed: ghost lbs input on exercises with no custom_name, renderScheduledWorkout, ~line 2277
[2026-06-20] Added: cardio cards (Walk/Jog/Run/Bike) with speed/incline/interval mode, renderScheduledWorkout + schedExSaveOne, ~line 2210
[2026-06-20] Added: weather bar on DASH (#weather-bar, fetchAndLogWeather), Open-Meteo geolocation, weather_logs PATCH/POST, pressure trend
[2026-06-21] Added: Update Schedule (merge) mode on schedule upload — modal now offers Replace vs Update; confirmUpdateSchedule() merges partial Excel into existing plan by week/day, appends non-duplicate exercises, shows days-updated/added toast; saveWorkoutSchedule gains optional toastMsg param, ~lines 1187-1204, 4870, 4919
