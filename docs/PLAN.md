# Build plan

## Principles
- Show only what's needed during a workout.
- No recommendations, social features, accounts or subscriptions.
- Strength estimates and trends describe past training only; they never suggest what to lift.
- Weights are shown in **lb**. Fitbod stores kg, so values are converted on import.

## Screens
1. **Today**: saved routines (tap one to start) and today's step count.
2. **Workout**: exercises pre-filled with last session's weights and reps; tap to mark a set done; optional rest timer.
3. **History**: past sessions, newest first. Tap a workout for its sets; tap an exercise for a chart of estimated one-rep max over time, a trend extended 3 months ahead, and every past workout with its sets and reps.
   - **Muscle map**: front and back body diagram shaded by how much each muscle was trained in a workout, week or month.
4. **Settings**: import a Fitbod CSV; manage routines and exercises.

## Apple Health
- **Steps:** read and shown on Today.
- **Heart rate:** read after each workout for that session's time window (WHOOP writes heart rate to Health); the session keeps its average and peak.
- **Saving workouts:** optionally write each session to Health as a traditional strength training workout.

## Data model (SwiftData)
- `Exercise`: name
- `Routine`: name, ordered exercises
- `WorkoutSession`: start, end, routine, average/peak heart rate
- `SetEntry`: session, exercise, order, reps, weight (kg), duration, distance, isWarmup, note

## Milestones
1. ✅ Xcode project skeleton and data model
2. ✅ Fitbod CSV import, with routines built from the most common workouts
3. History, per-exercise charts, estimated 1RM and strength trend
4. Muscle map: primary/secondary muscles for each exercise (drafted using references such as MuscleWiki, then reviewed) and an openly licensed body diagram
5. Workout logging screen
6. Today screen and routines (rename, edit, reorder)
7. HealthKit: steps, then heart rate, then saving workouts
8. Install on iPhone
