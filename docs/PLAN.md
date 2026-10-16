# Build plan

## Principles
- Show only what's needed during a workout.
- No recommendations, social features, accounts or subscriptions.
- Strength estimates and trends describe past training only; they never suggest what to lift.
- Weights are shown in **lb**. Fitbod stores kg, so values are converted on import.

## Look
Dark, card-based screens modelled on Fitbod's feel: see [design.md](design.md). Shared pieces live in `LiftLog/Design`.

## Screens
1. **Today**: saved routines (tap one to see its exercises and start). New Routine makes one from any exercises; a routine's ⋯ menu edits (name, exercises, order) or deletes it; long-press a routine to move it up or down. Today's step count comes with HealthKit.
2. **Workout**: start from a routine on Today (or empty). Exercises come pre-filled with last time's sets; tap an exercise to edit reps and weight and tick each set done; add sets or exercises; an optional rest timer counts down after each set. Finish drops any sets you didn't do. A workout in progress survives closing the app and can be resumed from Today.
3. **Log**: past workouts on a timeline, newest first, with sets, volume and the exercises done. Tap a workout for its sets; tap an exercise for its chart.
4. **Exercises**: every exercise, built-in and imported, with the muscles it works. Tap one for Results (every workout's sets) and Trends (estimated one-rep max, weight, volume and reps over time, a personal record line, and a trend extended 3 months ahead).
   - **Muscles** (from Log): front and back body diagram shaded by how much each muscle was trained this week, month or 6 months, with sets per muscle. The same diagram heads each workout and exercise.
5. **Settings**: import a Fitbod CSV; manage routines and exercises.

## Apple Health
- **Steps:** read and shown on Today.
- **Heart rate:** read after each workout for that session's time window (WHOOP writes heart rate to Health); the session keeps its average and peak.
- **Saving workouts:** optionally write each session to Health as a traditional strength training workout.

## Data model (SwiftData)
- `Exercise`: name, primary/secondary muscles, equipment, kind (weight, bodyweight, assisted, timed, cardio), cached set count
- `Routine`: name, ordered exercises
- `WorkoutSession`: start, end, routine, average/peak heart rate, cached set count / volume / exercise names
- `SetEntry`: session, exercise, order, reps, weight (kg), duration, distance, isWarmup, note, multiplier

The built-in exercise list is `LiftLog/Resources/ExerciseCatalogue.json` (about 440 exercises with muscles). It's added to the database on launch, and imported exercises get their muscles from it.

## Milestones
1. ✅ Xcode project skeleton and data model
2. ✅ Fitbod CSV import, with routines built from the most common workouts
3. ✅ History, per-exercise charts, estimated 1RM and strength trend
4. ✅ UI redesign: Fitbod-style dark look, shared design pieces, exercise catalogue with muscle groups, app icon
5. ✅ Muscle map: the app's own front/back body diagram, shaded by sets per muscle over a week, month or 6 months
6. ✅ Workout logging: start a routine (or an empty workout), sets pre-filled from last time, tick sets done, add sets and exercises, rest timer, finish or discard
7. ✅ Routines: make new ones, rename, add / remove / reorder exercises, reorder routines on Today, delete
8. ✅ HealthKit: steps on Today, heart rate (from WHOOP) read for each finished workout, workouts saved to Health; all three are switches in Settings
9. Install on iPhone
