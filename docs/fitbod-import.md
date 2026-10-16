# Fitbod CSV export format

Notes from an export taken 2026-10-15: 29,406 rows, 1,234 workout days (2021-01-25 to 2026-10-15), 2,182 distinct timestamps, 159 distinct exercises.

## Header
```
Date,Exercise,Reps,Weight(kg),Duration(s),Distance(m),Incline,Resistance,isWarmup,Note,multiplier
```

One row per **set**. Workouts are listed newest first, but the sets *within* a workout are in the order they were done (warm-ups come first and weights ramp up).

| Column | Example | Notes |
|---|---|---|
| Date | `2026-10-15 21:33:03 +0000` | UTC. Every set in a workout shares the same timestamp, so group by Date to get sessions. |
| Exercise | `Deadlift` | Free-text name. |
| Reps | ` 10` | Has a leading space, so trim it. |
| Weight(kg) | `61.235042773811365` | Entered in lb and stored as kg (61.235 kg = 135 lb). Convert with ÷ 0.45359237 and round to the nearest 0.5 lb. |
| Duration(s) | `225.0` | For timed or cardio exercises. |
| Distance(m) | `8046.72` | For cardio such as Cycling. |
| Incline, Resistance | `0.0` | Always 0 in this export. |
| isWarmup | `true` / `false` | |
| Note | `2x @ 42"  1x @ (walk up) "48` | Free text that can contain stray `"` characters, so the parser must tolerate unbalanced quotes. |
| multiplier | ` 1.0` / ` 2.0` | Has a leading space. 2.0 looks like weight is per side or per dumbbell (for example Hammerstrength Shrug); 4.0 appears on dumbbell lunges and split squats; 0.0 on cardio and assisted pull-ups. Keep it as stored. |

About 1,055 timestamps hold a single exercise, mostly cardio (Cycling, Stair Stepper, Running) logged separately from the lifting workout on the same day.

## Most frequent exercises
Barbell Shoulder Press, Barbell Bench Press, Cable Tricep Pushdown, Barbell Incline Bench Press, Back Squat, Machine Fly, Cable Row, Deadlift, Lat Pulldown, Dumbbell Shrug, Cable Face Pull, Low Cable Chest Fly, Cycling, Barbell Hip Thrust, Leg Press.

## How LiftLog imports it
Code is in `LiftLog/Import/`.

- **Workouts:** rows that share a Date become one workout. Fitbod stores one time per workout, so start and end are the same.
- **Set order:** sets keep the file's order, which is the order they were done.
- **Cardio:** single-exercise sessions stay as their own workouts.
- **Re-importing:** a workout whose Date is already in the app is skipped, so importing a newer export only adds new workouts.
- **Unreadable lines** (no valid date or exercise, or wrong number of columns) are skipped and counted in the summary.
- **Routines:** lifting workouts (3+ exercises) from the 6 months before the newest one are grouped when they share at least half their exercises. Each group of 3+ workouts becomes a routine (6 at most) made of the exercises done in at least half of them, in the order of the most recent workout. A group too similar to an existing routine is skipped. Past workouts are linked to the closest routine. On the 2026-10-15 export this finds 3 routines: push, pull and legs.
