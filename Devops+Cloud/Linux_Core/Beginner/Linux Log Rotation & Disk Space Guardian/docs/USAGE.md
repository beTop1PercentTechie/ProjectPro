# Usage

## Basic commands

```bash
sudo diskguardian --full                     # every module: track, hogs, rotate, alert
sudo diskguardian --monitor                  # fast subset: track, alert only
sudo diskguardian --modules=rotate           # run only the specified module(s)
sudo diskguardian --list-modules             # show all available module keys
sudo diskguardian --dry-run --full           # log intended actions, touch nothing
sudo diskguardian --format=json              # only generate a JSON report
sudo diskguardian --output-dir=/tmp/out      # write reports somewhere else
sudo diskguardian --config=/etc/guardian.conf  # use an alternate config file
sudo diskguardian --email --slack            # force-enable alerts for this run only
sudo diskguardian --no-color                 # disable ANSI colors (e.g. for CI logs)
sudo diskguardian --help
```

If you did not run `install.sh --symlink`, invoke the script directly instead:

```bash
sudo ./guardian.sh --full
```

## Why two run modes?

- **`--monitor`** runs only `track` (sample disk usage, update growth-rate
  history) and `alert` (evaluate thresholds/forecasts). Both are cheap -
  safe to run every few minutes via cron so a sudden spike gets caught in
  near-real-time.
- **`--full`** adds `hogs` (a `du`/`find` sweep to name the exact
  directories/files consuming space) and `rotate` (log rotation/compression).
  These touch the filesystem more and cost more I/O, so they belong on a
  slower cadence (hourly/daily).

`cron/guardian_scheduler.sh` installs exactly this split by default.

## Exit codes

| Code | Meaning                                                          |
|------|-------------------------------------------------------------------|
| 0    | Run completed; overall status is OK                                |
| 1    | Invalid arguments, or not run as root                             |
| 2    | Run completed; overall status is CRITICAL                          |
| 3    | Run completed; overall status is WARNING                           |

Non-zero exit codes make it easy to wire Guardian into a monitoring
pipeline or a CI/CD gate.

## Reading the output

Each run prints a live, color-coded log to the console and to a timestamped
file under `logs/`. Every rotation, compression, or deletion is additionally
recorded forever in `logs/actions.log` - the remediation audit trail - even
after the run's own log file is pruned.

Reports land in `logs/reports/` in the formats configured by
`REPORT_FORMATS` (see [CONFIGURATION.md](CONFIGURATION.md)):

- `guardian_report_<host>_<timestamp>.txt`  - plain text, good for a terminal or email body
- `guardian_report_<host>_<timestamp>.html` - shareable, styled report for a browser
- `guardian_report_<host>_<timestamp>.json` - machine-readable, for a dashboard/SIEM

Disk usage history (used for growth-rate trend detection) is stored at
`data/disk_history.csv` and pruned automatically after `HISTORY_RETENTION_DAYS`.

## Automating with cron

`cron/guardian_scheduler.sh` manages a dedicated file in
`/etc/cron.d/diskguardian` so it never touches your personal crontab:

```bash
sudo cron/guardian_scheduler.sh install "*/5 * * * *" "0 3 * * *"
sudo cron/guardian_scheduler.sh remove
```

Cron output is appended to `logs/cron.log`.

## Safety notes on log rotation

- A file is only ever rotated via copy-then-truncate (`cp` the original
  aside, then truncate the live file to zero bytes in place). This keeps
  the live file's inode stable, so a process that already has it open for
  writing keeps writing to the same file - the same tradeoff `logrotate`'s
  `copytruncate` option makes, and the same small race window it has (a
  few bytes written between the copy and the truncate can be lost).
- A file modified within `ROTATION_QUIET_PERIOD_SEC` is skipped for that
  run rather than rotated, to avoid truncating a file mid-write.
- `--dry-run` runs every check and logs exactly what would happen, without
  touching a single file - always test a new `rotation_policy.conf` rule
  this way first.
