# Realtor OS: project notes

Personal CRM for one realtor (Chris, Oakwyn Realty, East Vancouver). Mobile-first, used one-handed from the iPhone home screen. **This repo is public: never put client names, phone numbers, emails or keys in it.**

## The design rule
Open it, see who needs you today, act, log, done. A feature belongs if it ends with **a person and an action**. If it ends with looking at a chart, it doesn't belong in this app (a separate page is fine).

## How it's built
- **One file: `index.html`** (vanilla JS/HTML/CSS, no build step). Live at `vancouverseach-debug.github.io/realtor-os` via GitHub Pages from `main`.
- **Data:** every bucket is saved to `localStorage` first via `save(key,val)`, then synced to **Supabase** (`ROS` module). Buckets: `ros_leads, ros_past, ros_market, ros_focus_done, ros_showings, ros_notes, ros_stats`. Newest edit wins per bucket. A device joining with different data is asked which list to keep, and a backup goes in `ros_backup`. Changes from another device redraw in place (`applyCloudChanges`).
- **Supabase** (project in Canada Central): table `ros_store` with row-level security (own rows only) plus `ros_history` hourly snapshots kept 30 days. SQL in `supabase/setup.sql`. Sign-ups are disabled; one user.
- **AI:** `callAI(prompt, maxTokens, files)` calls the Supabase edge function `ai` (`supabase/functions/ai/index.ts`), which holds `ANTHROPIC_API_KEY` as a secret and accepts PDF/image attachments. **Never put an API key in index.html.** Model: Claude Haiku 4.5.
- **Auto-update:** bump `<meta name="ros-build">` on every change; the app offers "New version ready" when the live build differs.
- **Dates:** always local Vancouver days: `todayISO()`, `daysSince()`, `parseDay()`, `agoText()`. Never `toISOString().slice(0,10)` for "today" (that's UTC, which is tomorrow after 5pm).
- **Lead cards** build their insides only when opened (`renderLeadCard` + `toggleCard`). Keep it that way; building every card was the old slowness.

## Pipeline and urgency
- `getUrgencyState(l)`: NOW / UPCOMING / WAITING / WARM / CHECK IN, based on who owes the next action.
- Pipeline sections: **Deals in Motion** = `LIVE_DEAL_STAGES` (Listed, Offer Submitted/Received, Subjects). **Active Clients** = `WORKING_STAGES` (Listing Appointment, Agreement Signed, Active Search). Then Buyer Leads, Seller Leads, Cold / Re-engage.
- **Cold priority overrides stage** (`isColdLead`): cold leads go to Re-engage only and keep their stage for when they come back.

## AI features and their guardrails
- **Smart add:** a pasted or dictated note becomes a lead that fills the Full form for review. It never invents phone, email or name.
- **Follow-ups and the morning briefing** get **dated** activity history (`aiTimeline`), and are told that "tomorrow" inside a note is relative to the note's date.
- **Stats (Tools → Stats)** reads GVR / Fraser Valley reports (e.g. the ShowingTime "REALTOR® Report", one per area):
  1. AI **only copies printed numbers**, one file per call (`extractPrompt`).
  2. The **app computes** totals, YoY/MoM, sales-to-active and buyer's (<12%) / balanced / seller's (>20%) per type (`calcType`, `calcArea`).
  3. Copy is written from the computed **fact sheet** only (`copyPrompt`, `recFacts`).
  4. Every %, $ and count in the copy and in client drafts is checked (`uncheckedNumbers`); neighbourhood numbers only count if that neighbourhood is named. One retry, then an orange warning.
  - Why: the first real run invented "East Van sales up 8.9%" (actually Hastings condos' YoY change).
- **Areas:** leads and past clients have `area` (canonical board sub-areas, `canonArea`). The monthly **market-update run** writes one text per person from their own area's facts, then tap Text/Email and the touch is logged. It skips anyone contacted in the last 5 days.

## Client message voice
Friendly, casual and short, like a text from Chris. Give something useful, then invite a reply. Not pushy or corporate. No "touching base", "checking in", "excited", "amazing", "smart moves", "hope you're well". No sign-off on texts.

## Demo mode
`?demo` opens the app with made-up clients, no login, no cloud, and sample AI answers (`demoAI`). Storage keys are prefixed `demo:` so it can never touch real data; `?demo=reset` reseeds. For showing the app to people.

## Testing
Tests run the real page in jsdom with a mocked Supabase and AI (kept outside the repo). They cover sync and device choice, 8:30pm-Vancouver date edge cases, Smart add, the pipeline, the full stats flow on the real Aug 2026 Vancouver East report numbers, the update run, and speed with 80 leads. Run the suite before every push; nothing gets pushed red.

## Decided / parked
- Paragon direct access: no (needs a board data agreement; scraping risks the licence). CSV exports or the IDX/Repliers route are possible later.
- Google Sheets and Gemini as backends: replaced by Supabase + Claude.
- Area dashboards with charts: rejected as drift. Per-client "their market" lines are fine.
- Selling it: test with a few Oakwyn agents first (needs multi-user). Price unsettled (ideas ranged $15–50/mo).

## Open ideas (not built)
- Coaching briefing: one action, one risk/opportunity, one pattern, with area numbers.
- "Their market" line on each lead card (neighbourhood + type numbers; neighbourhoods are already extracted).
- Offer tracker with a subject-removal countdown; open house mode; next-steps prompt on stage change.
- Multi-user for an Oakwyn pilot.
