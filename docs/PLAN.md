# Build plan

## Principles
- Show only what's needed during a workout.
- No recommendations, recovery maps, social features, accounts or subscriptions.
- Weights are shown in **lb**. Fitbod stores kg, so values are converted on import.

## Screens
1. **Today**: saved routines (tap one to start) and today's step count.
2. **Workout**: exercises pre-filled with last session's weights and reps; tap to mark a set done; optional rest timer.
3. **History**: past sessions, newest first; per-exercise chart of weight over time.
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
1. Xcode project skeleton and data model
2. Fitbod CSV import, with routines built from the most common workouts
3. History screen and per-exercise charts
4. Workout logging screen
5. Today screen and routines
6. HealthKit: steps, then heart rate, then saving workouts
7. Install on iPhone
