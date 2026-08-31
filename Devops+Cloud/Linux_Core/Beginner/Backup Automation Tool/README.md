# Backup Automation Tool

A Bash-based automation tool that backs up multiple directories, compresses them with `tar`/`gzip`, applies a configurable retention policy, and lets you restore from any backup - all runnable by hand or fully automated with cron.

Designed for Ubuntu 24.04+ LTS; built and tested end-to-end (including a full retention/rotation cycle and a byte-for-byte restore round trip) during development.

## Features

- **Multi-directory backups** - back up any number of configured source directories in one run
- **tar + gzip compression** - each source becomes one timestamped `.tar.gz` archive
- **Timestamped, collision-safe naming** - `home_2026-08-27_02-00-00.tar.gz`; different source paths never overwrite each other, even if they share a folder name
- **Automatic directory creation** - the backup destination is created if it doesn't exist
- **Configurable retention policy** - keep the newest N backups per source, delete the rest automatically, only after a verified successful backup
- **Restore mechanism** - list, select, validate, extract, and verify - defaults to a safe test location, never a real system path, unless you say otherwise
- **Size, duration, and status reporting** - every run reports exactly how much data moved and how long it took
- **Detailed timestamped logs** plus a **short human-readable summary report** after every run
- **Cron automation** via a dedicated, isolated `/etc/cron.d` entry
- **Overlap protection** - a lock file stops a scheduled run from colliding with a manual one
- **Pre-flight disk space and permission checks** - fails fast, before any data is touched, with a clear reason
- **Optional rsync staging** for sources that mutate too quickly for a direct `tar` snapshot to be fully consistent

## Quick start

```bash
git clone <repository-url> backup-tool
cd backup-tool
sudo ./install.sh --symlink

sudo bat-backup --dry-run     # see what would happen, touch nothing
sudo bat-backup               # run it for real
sudo bat-status                # check the result
sudo bat-list                  # see what's stored
sudo bat-restore               # get a backup back
```

**Start with a safe test sandbox, not real system directories** - see [docs/TESTING.md](docs/TESTING.md) before pointing `SOURCE_DIRS` at `/etc` or `/home`.

## Architecture

```
Backup Automation Tool/
├── bin/                      # Thin entry points - orchestration only
│   ├── backup.sh
│   ├── restore.sh
│   ├── list-backups.sh
│   └── backup-status.sh
├── config/
│   └── backup.conf           # What to back up, where, retention, safety limits
├── lib/                      # All the actual logic lives here
│   ├── logger.sh             # Timestamped, color-coded logging (console -> stderr, file -> LOG_FILE)
│   ├── validation.sh         # Every pre-flight check: sources, destination, disk space, archive integrity
│   ├── backup-functions.sh   # Config loading, the tar/gzip work, retention, optional rsync staging
│   └── report.sh             # The human-readable summary report
├── cron/
│   └── backup-cron-scheduler.sh   # Installs/removes the scheduled job
├── tests/
│   ├── run_tests.sh
│   ├── test-validation.sh
│   ├── test-backup.sh
│   └── test-restore.sh
├── docs/
│   ├── ARCHITECTURE.md
│   ├── INSTALLATION.md
│   ├── CONFIGURATION.md
│   ├── USAGE.md
│   ├── TESTING.md
│   ├── TROUBLESHOOTING.md
│   └── EC2_DEPLOYMENT.md
├── backups/   reports/   logs/   restore-test/   (generated at runtime, gitignored)
├── install.sh
└── uninstall.sh
```

**Config holds settings, `lib/` holds logic, `bin/` holds orchestration.** No `bin/` script implements business logic itself - it sources the `lib/` functions it needs and calls them in order. Full rationale for every major design decision (why a lock file, why `.partial` filenames, why retention groups by source name, why log output goes to stderr) is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Requirements

- Ubuntu 24.04+ LTS (or another modern Linux distribution)
- Bash 4.4+, `tar`, `gzip`, `find`, `stat` - all standard on any Linux install
- `rsync` - only if you enable the optional rsync-staging feature
- Root/sudo access
- `git` - to clone/version this project
- `cron` - for automatic scheduling

## Installation

```bash
sudo ./install.sh --symlink
```

Full details: [docs/INSTALLATION.md](docs/INSTALLATION.md).

## Configuration

Everything is in [`config/backup.conf`](config/backup.conf). Every variable explained: [docs/CONFIGURATION.md](docs/CONFIGURATION.md).

## Usage

Full CLI reference, exit codes, and examples: [docs/USAGE.md](docs/USAGE.md).

## Backup workflow

```
Load config -> validate sources -> create destination if needed -> generate timestamp
   -> for each source: tar + gzip -> verify archive -> apply retention
   -> write logs throughout -> generate summary report
```

## Restore workflow

```
List available backups -> select one -> validate archive integrity
   -> choose destination (defaults to a safe restore-test/ folder)
   -> extract -> verify files were actually restored
```

## Retention policy

Keep the newest `RETENTION_COUNT` backups **per source directory**; anything older is deleted automatically, but only right after that source's new backup has been verified as intact. A failed backup attempt never triggers retention - it would be deleting good, restorable backups to make room for one that doesn't exist. Verified with the exact scenario this feature is built around: 10 existing backups, `RETENTION_COUNT=7` -> 3 removed, 7 remain (see `tests/test-backup.sh`).

## Cron setup

```bash
sudo cron/backup-cron-scheduler.sh install "0 2 * * *"
```

Installs a dedicated `/etc/cron.d/backup-automation` entry - never your personal crontab. Always run a manual backup successfully first; debugging a scheduled job you've never seen run interactively is much harder than debugging one you have.

## Testing

```bash
bash tests/run_tests.sh
```

Real `tar`/`gzip` round trips against temporary sandboxes, not mocks - including a byte-for-byte binary file comparison after restore and the full 10-backups/retention=7 rotation scenario. See [docs/TESTING.md](docs/TESTING.md) for the manual test scenarios worth running by hand too.

## Troubleshooting

[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) covers every error message this tool actually produces and what to do about it.

## Future improvements

Deliberately **not** part of the core tool, to keep it understandable - but natural next steps if you want to take this further:

- Shipping backups off the local disk (S3, another host) - see [docs/EC2_DEPLOYMENT.md](docs/EC2_DEPLOYMENT.md#8-where-should-the-actual-backups-end-up)
- Archive encryption and checksums for tamper detection
- Email/Slack notifications on failure
- A systemd timer as an alternative to cron
- A `--verbose`/structured CLI argument parser with more flags
- Backup metadata (a small JSON sidecar per archive) for programmatic status checks

## License

MIT - see [LICENSE](LICENSE).
