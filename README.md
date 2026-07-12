# CoreFit

Personal, offline-first fitness tracker for Android. No accounts, no cloud,
no analytics — every byte stays on the device.

## Features

- **Activity profiles**: Running, Walking, Cycling, Hiking.
- **Live GPS tracking** on an OpenStreetMap map (`flutter_map`, no API keys)
  with pause/resume. Distance and time only accumulate while actually
  recording — pause models a structural gap, not a UI flag.
- **Battery-aware recording**: per-activity distance filters, GPS fully off
  while paused, and background tracking via geolocator's Android foreground
  service (exists only while recording).
- **Post-activity save screen**: title, notes, perceived exertion (1–10),
  gear used.
- **Stats tab** (`fl_chart`): monthly and yearly views with Previous/Next
  navigation through past periods, filterable by activity type.
- **Challenges**: weekly/monthly/yearly goals over distance, moving time, or
  activity count. Built-in defaults plus fully custom ones. Progress is always
  derived from activity history, never stored, so it can't desync.
- **Gear tracking** with lifetime distance per item.
- **Health Connect sync** (`health` package): completed workouts are written
  as exercise sessions. Write-only, opt-in.
- **Data ownership**: one-file JSON export/import of the entire database via
  the system file dialog.

## Architecture

```
lib/
├── models/        # Pure Dart, JSON-serializable. No Flutter imports.
├── services/      # Singletons: database (Hive CE), tracking, health, export.
├── screens/       # UI. One file per screen.
└── utils/         # Geo math, formatting, activity-type UI mapping.
```

Storage is Hive CE with records stored as JSON strings — the on-disk format
is the export format. Full activities (GPS tracks) live in a lazy box;
a lightweight summary index box serves all list/stats/challenge queries, so
historical scans never load track points.

## Build

```sh
flutter pub get
flutter build apk --release
```

Requires Android 8.0+ (API 26, Health Connect floor).

## Testing

```sh
flutter test
```
