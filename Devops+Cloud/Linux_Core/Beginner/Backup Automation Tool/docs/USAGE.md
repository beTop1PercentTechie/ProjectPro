# Usage

If you ran `install.sh --symlink`, the four tools are available anywhere as `bat-backup`, `bat-restore`, `bat-list`, `bat-status`. Otherwise, run them by full path: `bin/backup.sh`, `bin/restore.sh`, `bin/list-backups.sh`, `bin/backup-status.sh`.

## Running a backup

```bash
sudo bat-backup                    # run a real backup using config/backup.conf
sudo bat-backup --dry-run          # show what would happen, touch nothing
sudo bat-backup --verbose          # also print the exact tar command for each source
sudo bat-backup --config=/etc/backup-tool/backup.conf   # use an alternate config file
sudo bat-backup --no-color         # disable ANSI colors (e.g. for cron logs)
sudo bat-backup --help
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0    | Every configured source backed up successfully |
| 1    | Invalid arguments, the lock was already held, or the backup destination couldn't be prepared |
| 2    | One or more sources failed to back up (partial or total failure) |

Non-zero exit codes make it easy to alert on backup failures from cron or a monitoring system.

## Listing backups

```bash
sudo bat-list
```

```
Available Backups (/opt/backup-tool/backups)
==================================================================
   1. home_2026-08-27_02-00-01.tar.gz              1.20 MB   2026-08-27 02:00 (3h ago)
   2. etc_2026-08-27_02-00-04.tar.gz                45.30 KB  2026-08-27 02:00 (3h ago)
   ...
==================================================================
  Total: 8 backup(s), 4.50 MB
```

## Checking status

```bash
sudo bat-status
```

Shows the last run's time, status, per-source success/fail counts, total size, how many backups currently exist on disk, and the retention policy in effect. Exits `0` if the last run was a full `SUCCESS`, `2` otherwise - useful for a monitoring check.

## Restoring a backup

```bash
sudo bat-restore                                              # interactive: pick from a numbered list
sudo bat-restore --file=home_2026-08-27_02-00-01.tar.gz       # non-interactive, by filename
sudo bat-restore --file=home_2026-08-27_02-00-01.tar.gz --dest=/home/ubuntu/restore-test/home
```

If you don't pass `--dest`, the tool **always** picks a new folder under `restore-test/` rather than defaulting to any real system path - restoring over `/etc` or `/home` requires you to type that destination explicitly, on purpose.

Restoring into a destination that already has files in it is refused, to avoid mixing files from two different restores together. Point `--dest` at an empty or new directory.

## Automating with cron

`cron/backup-cron-scheduler.sh` manages a dedicated file in `/etc/cron.d/backup-automation`, so it never touches your personal crontab:

```bash
sudo cron/backup-cron-scheduler.sh install "0 2 * * *"   # every day at 02:00
sudo cron/backup-cron-scheduler.sh remove
```

Cron output is appended to `logs/cron.log`. Always run `bat-backup` manually at least once and confirm it works before relying on cron - debugging a scheduled job you've never seen run interactively is much harder.

## Recommended first steps

1. `sudo bat-backup --dry-run` - confirm your `SOURCE_DIRS` are all valid
2. `sudo bat-backup` - run it for real, against a safe test sandbox first (see [TESTING.md](TESTING.md))
3. `sudo bat-status` and `sudo bat-list` - confirm the results look right
4. `sudo bat-restore` - prove you can actually get the data back
5. Only then, point `SOURCE_DIRS` at real directories and schedule it with cron
