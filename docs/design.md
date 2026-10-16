# Design brief: LiftLog's look (milestone 4)

LiftLog's screens should feel like Fitbod's, because that's what you're used to. This is what makes Fitbod's screens work, what LiftLog copies, and what it deliberately leaves out. Reference screenshots live in `data/fitbod-screenshots/` (gitignored, never committed).

## What makes Fitbod's screens work

### Colour
- **Dark by default.** Near-black background (`#131319`-ish), with slightly lighter charcoal cards (`#1F1F27`) and a third, lighter grey for pressed/selected states and pills.
- **One accent: coral red** (`#F0405E`-ish). Used sparingly: the active tab, chart lines and bars, "+" buttons, the Start Workout button, links. Nothing else is red.
- **Two support colours.** Mint green (`#8EE8C8`) means "done" (set checkmarks, the number inside a set field). Pale yellow (`#FCF3A0`) means "record / personal best" (trophy, PR banner, the dotted PR line on charts).
- Text is white for primary, mid-grey (`#9A9AAA`) for secondary, with muted all-caps labels (`CALORIES`, `VOLUME`) for stat titles.

### Typography
- **Big italic bold headings** ("Overall Strength", "Past Workouts", "back day", "8 Exercises"). This is the single most recognisable thing about the app. Section headings are ~28pt italic black; workout titles are ~40pt.
- **Huge numbers** for the headline stat on a card (79.4, 60, 1,700) at ~56pt bold italic, with the unit small beside it ("lb in 1 rep").
- **Small caps labels** with letter-spacing above stats (`EXERCISES  VOLUME  CALORIES`).
- Body text is a clean geometric sans. Set values in input fields are an italic monospace (`8`, `60`).
- Tab bar labels are small and plain.

### Layout and density
- Generous side margins (~16pt) and lots of vertical breathing room between sections. Fitbod is *not* dense: one idea per card, big tap targets.
- **Cards with 16pt rounded corners**, no borders, no shadows — just a lighter fill on the dark background. Full-width, stacked, 12pt apart.
- **Floating, pill-shaped tab bar** with 4 tabs, icon over label, active tab in a lighter pill with a red icon.
- Round 44pt icon buttons at the top (back arrow, share, more) instead of a standard nav bar. Title centred, plain (not italic).
- Horizontal **segmented pill** for Results / Trends and Week / Month / 6 Months / Year.

### How a workout is shown (Log / History)
- **Timeline list.** A thin vertical line runs down the left; each workout hangs off it with a dot and a date header (`THU, OCTOBER 15` left, duration `1:10:03` right).
- Each workout is a card: muscle thumbnail + **lowercase title** ("back day"), then a 3-up stat strip (EXERCISES / VOLUME / CALORIES), then a one-line exercise summary ("Deadlift, Lat Pulldown, Cable Face Pull and 5 more"), then a "1 Record" row with a trophy when a PR was set.
- A compact **week calendar** strip at the top (SU–SA) with minutes under days that had a workout.
- A "Workouts: 2182" header stat.

### How sets are shown
- **Workout detail**: big centred header (muscle thumbnails, italic title, duration, 3 stats), then "8 Exercises" and a list. Each exercise is a thumbnail with a green checkmark badge, the exercise name, and **one line per set: `10 reps x 135 lb`** in grey. Warm-ups aren't labelled; they're just the lighter first rows.
- When an exercise set an estimated-1RM record, a yellow trophy row sits under it: "Est. 1 Rep Max — 79.4 lb ›".
- **Exercise history (Results tab)**: grouped by date with an italic date heading ("Yesterday", "Monday, Oct 12"), a "Working sets" label, then numbered hexagon badges 1–4 with `8 reps x 60 lb`, then "Est. 1 Rep Max — 79.4 lb in 1 Rep".
- **Logging** (later milestone): two big outlined fields per set, Reps and Weight (lb), green hexagon check on the left, "Add Set" in red.

### Charts
- One metric per card: title, huge current value, "Logged Oct 15, 2026", then the chart. Est. 1RM, Weight and Reps are **line charts with dots** on every point; Volume is a **bar chart**. All in accent red.
- Y-axis labels on the **right**, faint horizontal gridlines, no x-axis labels on the card view ("Most Recent Performances" caption instead; last ~10 workouts).
- The full-screen chart has Week / Month / 6 Months / Year, x-axis buckets (`13-19`, `20-26`), a **dotted yellow PR line**, a yellow "Personal Record" card, and a plain "Your Average" card.

### Navigation
- 4 tabs: Workout, Body, Targets, Log. Stack navigation inside each; details push with a back arrow; pickers and menus come up as bottom sheets with a grab handle and a red × to close.

## What LiftLog copies
- Dark theme, the red/mint/yellow trio, charcoal cards, italic bold headings, huge stat numbers, small-caps labels.
- Timeline history with date headers, lowercase routine names, stat strip, exercise summary line.
- Workout detail with centred header, "N Exercises", one line per set.
- Exercise detail with Results (sets by date) and Trends (metric cards with charts), plus the full-screen chart with time ranges and a PR line.
- Floating tab bar look (SwiftUI's own tab bar on iOS 26 already floats; it just needs the colours).
- Bottom sheets for pickers.

LiftLog draws its own icons (SF Symbols) and never uses Fitbod's logo, photos, muscle artwork or wordmark. Muscle thumbnails come with milestone 5's muscle map; until then exercise rows get an SF Symbol in a rounded square.

## What LiftLog leaves out
- Recommendations, "Up Next", Coach notes, Switch workout, "Generate new weights".
- Recovery scores, mSTRENGTH scores, Overall Strength bars, benchmark lifts.
- Weekly set targets hexagons, weekly goals, streaks, milestones badges.
- Calories (we don't have them), exertion ratings / reps in reserve.
- Promotional cards ("Strength Scores just got an upgrade", "Weekly report is ready"), Learn More links, share buttons.
- Equipment / gym / plan settings.
- Exercise videos and photos.

## Screen-by-screen plan
| Screen | Now | After |
|---|---|---|
| Tab bar | Today / History / Settings, blue | Today / Log / Exercises / Settings, red accent, dark |
| Today | Plain list of routine names like "Back Squat, Leg Press + 4 more" | Italic "Today", routine cards with lowercase names (`push`, `pull`, `legs`), exercise count, last done; Start is milestone 6 |
| History → **Log** | Plain list, 3 text lines per workout | Workouts count + week strip; timeline with date headers; cards with title, EXERCISES / SETS / VOLUME, exercise summary |
| Workout detail | Grouped list with "Date / Duration" rows | Centred header (title, date, duration, VOLUME / SETS / RECORDS), "N Exercises", exercise rows with `10 reps x 135 lb` lines, trophy row for an est. 1RM PR |
| Exercises | Plain alphabetical list | Alphabetical with letter headers, search, sorted "Most logged" option, set count on the right |
| Exercise detail | Summary rows, chart, workout list | Results / Trends segmented pill. Results: sets grouped by date with numbered badges and Est. 1RM. Trends: Est. 1RM (line), Weight (line), Volume (bar), Reps (line) cards; tap one for the full-screen chart with Week / Month / 6M / Year, PR line and PR + average cards. Keep the 6-month trend line as a subtle dashed extension. |
| Settings | Plain list | Dark grouped cards; same content |

## Data fixes in the same milestone
- **Assisted exercises** (Fitbod `multiplier = 0.0`: Assisted Pull Up, Assisted Neutral Grip Pull Up, Assisted Dip). The weight is *assistance*, so a 1RM makes no sense and goes the wrong way as you get stronger. They'll chart **assistance (lb), lower is better**, and show sets as `8 reps · 45 lb assist`.
- **Volume** = reps × weight × multiplier where multiplier is 2 or 4 (per-side / per-dumbbell), so it matches Fitbod's "30,710 lb".
- **History speed**: it loads every set of 2,182 workouts just to count them. The list will fetch sessions only and compute set counts and volume lazily per visible row (or store them on the session at import).

## Design tokens (LiftLog/Design)
- `Palette`: background, card, cardRaised, accent, done (mint), record (yellow), textPrimary, textSecondary, textMuted. Light-mode values exist but the app sets dark as the default.
- `Type`: `.heroTitle` (40 italic black), `.sectionTitle` (28 italic black), `.statValue` (44 bold italic, monospaced digits), `.statLabel` (12 caps, tracking 1.5), `.body`, `.secondary`, `.setLine` (17 regular, monospaced digits).
- `CardStyle` view modifier: card fill, 16pt radius, 16pt padding.
- `StatTile`: label over value with unit; `StatStrip`: 3 tiles separated by hairlines.
- `SetLine`: `10 reps x 135 lb` row with optional numbered hexagon badge.
- `MetricCard`: title, big value + unit, "Logged …", chart slot.
- `SegmentedPill`: the Results / Trends control.
