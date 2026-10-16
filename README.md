# LiftLog

A simple, uncluttered iPhone workout log. It replaces Fitbod for someone who repeats the same routines and doesn't want recommendations.

- **Platform:** iPhone only. Native SwiftUI, with data stored on the device using SwiftData.
- **Apple Health:** reads steps and heart rate (heart rate comes from WHOOP via Apple Health), and can optionally save workouts to Health.
- **History:** imports the full Fitbod CSV export.

See [docs/PLAN.md](docs/PLAN.md) for the build plan and [docs/fitbod-import.md](docs/fitbod-import.md) for the export format.

## Development

Built on the Mac in Xcode. This repo keeps the Mac and the Windows PC in sync.
Personal data exports go in `data/`, which git ignores, so they are never uploaded.
