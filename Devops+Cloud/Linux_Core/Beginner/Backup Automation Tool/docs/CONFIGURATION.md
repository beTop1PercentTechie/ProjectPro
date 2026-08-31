# Configuration Reference

All settings live in [`config/backup.conf`](../config/backup.conf), a plain Bash file sourced at startup. Anything you omit falls back to the default defined in `lib/backup-functions.sh:load_config`.

## What to back up

| Variable      | Default | Description |
|---------------|---------|-------------|
| `SOURCE_DIRS` | (must be set) | Comma-separated list of directories to back up. No trailing slashes. |

## Where things live

| Variable      | Default              | Description |
|---------------|----------------------|-------------|
| `BACKUP_ROOT` | `<install>/backups`  | Where `.tar.gz` archives are written |
| `LOG_DIR`     | `<install>/logs`     | Per-run log files |
| `REPORT_DIR`  | `<install>/reports`  | Per-run summary reports |

## Retention

| Variable          | Default | Description |
|-------------------|---------|-------------|
| `RETENTION_COUNT` | `7`     | How many of the newest backups to keep **per source directory**. Older ones are deleted automatically after each successful backup of that source. `0` disables retention entirely (nothing is ever deleted). |

## Safety checks

| Variable            | Default                    | Description |
|----------------------|-----------------------------|-------------|
| `MIN_FREE_DISK_MB`  | `200`                       | Refuse to start a backup if the destination filesystem has less than this many megabytes free |
| `LOCK_FILE`         | `<install>/.backup.lock`    | Prevents two backup runs from overlapping (e.g. a slow manual run colliding with a scheduled one) |

## Excluding files

| Variable       | Default | Description |
|----------------|---------|-------------|
| `TAR_EXCLUDES` | (empty) | Comma-separated glob patterns passed to `tar --exclude`, e.g. `*.tmp,*.log,node_modules,.git` |

## Optional advanced feature: rsync staging

| Variable             | Default                          | Description |
|-----------------------|-----------------------------------|-------------|
| `USE_RSYNC_STAGING`  | `false`                           | When `true`, each source is mirrored with `rsync -a --delete` into a staging copy before `tar` archives it, instead of `tar` reading the live source directly. See [ARCHITECTURE.md](ARCHITECTURE.md#the-optional-rsync-staging-path) for when this is actually worth enabling. If `rsync` isn't installed, the tool logs a warning and backs up the source directly instead of failing. |
| `RSYNC_STAGING_DIR`  | `<install>/.rsync-staging`        | Where staged copies are kept |

## Example: a minimal config

```bash
SOURCE_DIRS="/home,/etc,/var/www,/opt"
RETENTION_COUNT=7
MIN_FREE_DISK_MB=500
```

Everything else uses its default.
