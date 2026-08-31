# Testing

## Automated test suite

```bash
bash tests/run_tests.sh
```

Runs `test-validation.sh`, `test-backup.sh`, and `test-restore.sh` - all pure Bash, no external framework, no root required. They create real temporary directories, run real `tar`/`gzip`/`find` commands, and clean up after themselves. Nothing here touches your actual configured `SOURCE_DIRS` or `BACKUP_ROOT`.

Coverage includes:
- `validate_source_dir`, `validate_backup_root`, `validate_archive`, `check_disk_space` - each success and failure path
- A real backup-then-extract round trip, including a binary file compared byte-for-byte
- The exact retention scenario this project is built around: **10 existing backups, `RETENTION_COUNT=7` -> exactly 3 removed, 7 remain**, with the specific files checked by name (not just the count)
- A failed backup attempt does **not** trigger retention
- A corrupted/truncated archive is rejected before extraction is attempted
- A regression test for a real bug found during development: a function that both logs and returns a value via `$(...)` must never leak its log text into the captured value (see [ARCHITECTURE.md](ARCHITECTURE.md#why-log-output-goes-to-stderr-not-stdout))

## Manual testing with a safe sandbox

Never point `SOURCE_DIRS` at real system directories (`/etc`, `/home`, `/var/www`) while you're still learning how the tool behaves. Build a throwaway sandbox instead:

```bash
mkdir -p ~/backup-lab/source/{home,etc,var-www,opt}
echo "sample profile data"      > ~/backup-lab/source/home/profile.txt
echo "root:x:0:0::/root:/bin/bash" > ~/backup-lab/source/etc/passwd
mkdir -p ~/backup-lab/source/var-www/html
echo "<h1>Test Site</h1>"       > ~/backup-lab/source/var-www/html/index.html
echo "app config"               > ~/backup-lab/source/opt/app.conf

mkdir -p ~/backup-lab/backup-storage ~/backup-lab/restore-test
```

Point a copy of the config at it:

```bash
cp config/backup.conf /tmp/sandbox-backup.conf
```

Edit `/tmp/sandbox-backup.conf`:
```bash
SOURCE_DIRS="/home/ubuntu/backup-lab/source/home,/home/ubuntu/backup-lab/source/etc,/home/ubuntu/backup-lab/source/var-www,/home/ubuntu/backup-lab/source/opt"
BACKUP_ROOT="/home/ubuntu/backup-lab/backup-storage"
```

Then run everything against the sandbox first:
```bash
bin/backup.sh --config=/tmp/sandbox-backup.conf --dry-run
bin/backup.sh --config=/tmp/sandbox-backup.conf
bin/list-backups.sh --config=/tmp/sandbox-backup.conf
bin/restore.sh --config=/tmp/sandbox-backup.conf
```

Only once you're comfortable with what each command actually does should you point `SOURCE_DIRS` at real directories.

## Manual test scenarios worth running by hand

| # | Scenario | How to trigger it | Expected result |
|---|----------|--------------------|-------------------|
| 1 | Normal backup | Run `backup.sh` against the sandbox | All sources succeed, report says `SUCCESS` |
| 2 | Missing source directory | Add a nonexistent path to `SOURCE_DIRS` | That source is reported as `FAILED`; the others still succeed |
| 3 | Permission problem | `chmod 000` a sandbox source directory, then back it up | Clear "not readable" error, not a cryptic tar failure |
| 4 | Backup destination unavailable | Point `BACKUP_ROOT` at a path you can't write to | The run stops before any tar/gzip work begins |
| 5 | Retention with 10 backups, retention=7 | Run a backup 10 times against one source with `RETENTION_COUNT=7` | 7 remain, 3 removed (also covered automatically in `tests/test-backup.sh`) |
| 6 | Restore a backup | `restore.sh --file=... --dest=...` | Files extracted match the originals |
| 7 | Corrupt archive | `truncate -s 100 backups/some-backup.tar.gz`, then try to restore it | Rejected before extraction, not partially extracted |
| 8 | Empty source directory | Back up a directory with nothing in it | Succeeds, produces a small valid archive |
| 9 | Multiple backup runs in a row | Run `backup.sh` 3 times quickly | Each produces a distinctly timestamped archive, no overwrites |
| 10 | Cron execution | Install the cron job, wait for (or manually trigger) a scheduled run | `logs/cron.log` shows the same output as a manual run |
