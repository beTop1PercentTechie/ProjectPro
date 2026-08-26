# Linux Log Rotation & Disk Space Guardian

A Bash-based agent that continuously tracks disk usage *trends* (not just
static thresholds), pinpoints exactly which files/directories are eating
space, safely rotates and compresses oversized logs, and fires preemptive
alerts before a "disk full" event takes down production services.

Built for Ubuntu Server on AWS EC2.

## Features

- **Real-time tracking with growth-rate trend detection** - samples every
  monitored mount, persists a history, and computes KB/hour growth plus a
  projected "hours until full" - catching a fast-filling disk long before
  a static `%`-used threshold would.
- **Exact space-consumer identification** - `du`-ranked top directories and
  `find`-ranked large individual files, so the report says exactly what to
  clean up, not just that disk usage is high.
- **Safe log rotation & compression** - a configurable size/age policy per
  path, copy-then-truncate rotation (safe for files a process still has
  open), gzip compression, and retention-based cleanup of old copies.
- **Preemptive alerting with a remediation action log** - alerts fire on
  usage% *or* projected time-to-full, whichever comes first, and every
  rotation/compression/deletion/alert is permanently recorded in
  `logs/actions.log` - a full audit trail of what the agent actually did.
- **Dry-run mode** - evaluate every decision and log what would happen
  without touching a single file.
- **TXT/HTML/JSON reports** and optional Email/Slack/Telegram alerting.
- **Cron automation** - a frequent lightweight monitor pass plus a
  less-frequent full sweep, installed with one command.

## Quick start

```bash
git clone <repository-url> disk-guardian
cd disk-guardian
sudo ./install.sh --symlink

sudo diskguardian --full --dry-run   # see what it would do first
sudo diskguardian --monitor          # lightweight: tracking + alerting
sudo diskguardian --full             # adds space-hog scan + log rotation
```

Reports land in `logs/reports/`; the permanent action ledger is
`logs/actions.log`; disk-usage history is `data/disk_history.csv`.

## Project layout

```
Linux Log Rotation & Disk Space Guardian/
├── guardian.sh                  # Main entry point: CLI parsing & orchestration
├── bin/
│   └── diskguardian             # Relocatable wrapper, symlinked onto PATH by install.sh
├── install.sh                   # Sets up directories/permissions, optional PATH symlink
├── uninstall.sh                 # Reverses install.sh
├── config/
│   ├── guardian.conf            # Thresholds, scan paths, alert channels
│   └── rotation_policy.conf     # Per-path log rotation rules (size/age/keep/compress)
├── lib/
│   ├── core/                    # Shared foundation used by every module
│   │   ├── colors.sh            # Terminal color codes
│   │   ├── logger.sh            # Timestamped, color-coded logging
│   │   ├── utils.sh             # Shared helpers (require_root, kb_to_human, ...)
│   │   ├── config_loader.sh     # Loads config/guardian.conf with safe defaults
│   │   ├── history_store.sh     # Disk-usage sample store + growth-rate math
│   │   ├── events.sh            # This run's observations (usage/hogs/alerts)
│   │   ├── action_log.sh        # The remediation ledger (rotate/compress/delete/alert)
│   │   └── report_engine.sh     # Renders TXT/HTML/JSON reports
│   └── modules/                 # One file per requirement (see docs/MODULES.md)
│       ├── 01_disk_tracker.sh   # Real-time tracking + growth-rate trend detection
│       ├── 02_space_hogs.sh     # du/find top consumers
│       ├── 03_log_rotator.sh    # Safe rotate + compress by size/age policy
│       └── 04_alerting.sh       # Preemptive threshold + forecast alerting
├── alerts/
│   ├── email_notify.sh
│   ├── slack_notify.sh
│   └── telegram_notify.sh
├── cron/
│   └── guardian_scheduler.sh    # Installs/removes the two-tier cron schedule
├── tests/
│   ├── run_tests.sh             # Test runner (discovers test_*.sh)
│   └── test_core_lib.sh         # Unit tests: growth-rate math, events, action log
├── docs/
│   ├── INSTALL.md
│   ├── USAGE.md
│   ├── CONFIGURATION.md
│   └── MODULES.md
├── data/                        # Disk-usage history + alert cooldown state (gitignored)
└── logs/                        # Run logs, actions.log, reports/ (gitignored)
```

## How it fits together

1. `guardian.sh` resolves its own install directory, loads `lib/core/*.sh`,
   then `config/guardian.conf`.
2. It opens the event store and action ledger
   ([`lib/core/events.sh`](lib/core/events.sh),
   [`lib/core/action_log.sh`](lib/core/action_log.sh)), then runs the
   requested modules **in a fixed dependency order**: `track` → `hogs` →
   `rotate` → `alert`.
3. `01_disk_tracker.sh` samples `df` and appends to
   `data/disk_history.csv`; `lib/core/history_store.sh` turns that history
   into a growth rate and a time-to-full forecast.
4. `04_alerting.sh` reuses those numbers to decide CRITICAL/WARNING,
   independent of `02_space_hogs.sh` and `03_log_rotator.sh`, which report
   and act through the same two stores.
5. `lib/core/report_engine.sh` reads the event store and action ledger and
   renders the requested report formats; `guardian.sh` then dispatches any
   pending external notifications, cooldown-gated per mount.

Modules never build report fragments or talk to `curl`/`mail` directly -
they only call `add_event`/`log_action`. That separation is what lets you
add a new check, a new report format, or a new alert channel without
touching anything else.

## Documentation

- [docs/INSTALL.md](docs/INSTALL.md) - installation and requirements
- [docs/USAGE.md](docs/USAGE.md) - CLI reference, exit codes, cron setup, rotation safety
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md) - every config variable explained
- [docs/MODULES.md](docs/MODULES.md) - what each module does, and how to add one

## Running the test suite

```bash
bash tests/run_tests.sh
```

## Security & safety notes

- Log rotation never follows symlinks, never touches non-regular files,
  and defers (rather than truncates) a file modified within
  `ROTATION_QUIET_PERIOD_SEC` seconds.
- Rotation uses copy-then-truncate, matching `logrotate`'s own
  `copytruncate` tradeoff - a process with the file already open keeps
  writing to the same inode.
- `--dry-run` exercises every decision path and logs the outcome without
  modifying anything - always test a new `rotation_policy.conf` rule this
  way first.
- Every remediation action is permanently recorded in `logs/actions.log`,
  independent of report retention, so "what did the agent do" is always
  answerable.

## License

MIT - see [LICENSE](LICENSE).
