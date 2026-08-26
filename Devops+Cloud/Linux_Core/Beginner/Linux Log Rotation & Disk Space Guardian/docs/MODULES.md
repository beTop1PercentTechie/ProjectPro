# Module Reference

Every module lives in `lib/modules/`, is sourced by
[`guardian.sh`](../guardian.sh) on demand, and reports through `add_event`
(see [`lib/core/events.sh`](../lib/core/events.sh)) and, for anything that
actually changes a file, `log_action` (see
[`lib/core/action_log.sh`](../lib/core/action_log.sh)). Run
`diskguardian --list-modules` to see the exact keys accepted by
`--modules=`. Modules always execute in the fixed order below, regardless
of the order you list them in, because `alert` depends on numbers `track`
computes during the same run.

## 01: track

**File:** `01_disk_tracker.sh` · **Function:** `run_disk_tracker`

Requirement #1 - real-time tracking with growth-rate trend detection.

For every monitored mount (see `MONITORED_MOUNTS`), reads current usage via
`df`, appends a sample to `data/disk_history.csv`, then asks
[`lib/core/history_store.sh`](../lib/core/history_store.sh) for:

- **Growth rate** - KB/hour, computed from the oldest and newest sample
  inside `GROWTH_SAMPLE_WINDOW_MIN`
- **Forecast** - projected hours until the mount is full, given that rate
- **Trend** - `LEARNING` (not enough samples yet), `STABLE`, or `GROWING`

This is the difference between a static "you're at 80%" check and an agent
that says "you're at 60%, but growing 2GB/hour and will be full in 5
hours." The computed numbers are cached to a temp file for `04_alerting.sh`
to reuse without re-querying `df`/history.

## 02: hogs

**File:** `02_space_hogs.sh` · **Function:** `run_space_hogs`

Requirement #2 - identify the exact directories/files consuming space.

For each path in `SCAN_PATHS`: `du -k --max-depth=$DU_MAX_DEPTH` ranks the
top `TOP_N_CONSUMERS` subdirectories by size, and
`find -type f -size +${LARGE_FILE_SIZE_MB}M` lists individual large files,
largest first. Both are reported as INFO events with the exact path and
size - never just "disk is full," always "here is what's using it."

## 03: rotate

**File:** `03_log_rotator.sh` · **Function:** `run_log_rotator`

Requirement #3 - safe auto-rotation and compression of oversized/aged logs.

1. Loads rules from [`rotation_policy.conf`](../config/rotation_policy.conf)
   (first match wins), falling back to `DEFAULT_*` settings for anything
   unmatched.
2. Expands each rule's glob pattern, skipping files already processed by
   an earlier, more specific rule and anything that already looks like a
   rotation artifact (`*.gz` or a `.YYYYMMDD-HHMMSS` suffix).
3. For each remaining file, checks the trigger (`size >= MAX_SIZE_MB` or
   `age >= MAX_AGE_DAYS`). If triggered but the file was modified within
   `ROTATION_QUIET_PERIOD_SEC`, the rotation is deferred (logged as
   `SKIP`) rather than risking a mid-write truncation.
4. Rotates via **copy-then-truncate**: `cp -p file file.<timestamp>`, then
   `: > file` to zero the live file in place (same inode - a process with
   it already open keeps writing correctly). Optionally `gzip`s the copy.
5. Prunes rotated copies of that file beyond `KEEP_COUNT`, oldest first.
6. Every rotation and deletion is recorded via `log_action` with the exact
   bytes freed.

`DRY_RUN=true` (or `--dry-run`) runs steps 1-3 and logs what step 4-5
would do, without touching any file - see [USAGE.md](USAGE.md#safety-notes-on-log-rotation).

## 04: alert

**File:** `04_alerting.sh` · **Function:** `run_alerting`

Requirement #4 - preemptive alerting with a remediation action log.

Reads the per-mount metrics `01_disk_tracker.sh` cached this run and
raises CRITICAL/WARNING on **either** signal:

- Static: `use_pct >= DISK_CRIT_THRESHOLD` / `DISK_WARN_THRESHOLD`
- Trend: projected hours-to-full `<= FORECAST_CRITICAL_HOURS` / `FORECAST_WARN_HOURS`

The trend signal is what makes this "preemptive" - a mount at 40% usage
but filling at a rate that empties it in 4 hours raises a CRITICAL alert
before the static threshold ever would. Every alert is written to the
event store (always in the report) and to `logs/actions.log` (the same
audit trail as rotations); a per-mount cooldown
(`ALERT_COOLDOWN_MIN`, persisted in `data/alert_cooldown.state`) only
gates the external notification (email/Slack/Telegram), never the
internal record.

## Adding a new module

1. Create `lib/modules/NN_your_module.sh` following the pattern of an
   existing module: one `run_*` entry point calling private `_`-prefixed
   helpers, reporting through `add_event` and, for anything that changes a
   file, `log_action`.
2. Register it in the `MODULE_REGISTRY` array near the top of
   [`guardian.sh`](../guardian.sh) - **position matters**, since modules run
   in registry order, not the order `--modules=` lists them.
3. Add a unit test if the module contains non-trivial parsing/math.
4. Document it here.
