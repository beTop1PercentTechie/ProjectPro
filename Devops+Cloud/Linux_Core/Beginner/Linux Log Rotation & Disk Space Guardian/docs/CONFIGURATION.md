# Configuration Reference

All settings live in [`config/guardian.conf`](../config/guardian.conf), a
plain Bash file sourced at startup. Anything you omit falls back to the
default defined in
[`lib/core/config_loader.sh`](../lib/core/config_loader.sh).

## Paths

| Variable               | Default                  | Description |
|-------------------------|---------------------------|-------------|
| `DATA_DIR`             | `<install>/data`          | Disk-usage history CSV and alert cooldown state |
| `LOG_DIR`              | `<install>/logs`          | Run logs and the durable `actions.log` |
| `REPORT_DIR`           | `<install>/logs/reports`  | Generated reports |
| `ROTATION_POLICY_FILE` | `config/rotation_policy.conf` | Per-path log rotation rules |

## Monitored mounts

| Variable          | Default | Description |
|--------------------|---------|-------------|
| `MONITORED_MOUNTS`| `auto`  | `auto` = every real, local filesystem `df` reports; or a comma-separated list, e.g. `/,/var,/home` |

## Static usage thresholds (percent)

| Variable               | Default | Description |
|-------------------------|---------|-------------|
| `DISK_WARN_THRESHOLD`  | `75`    | Usage percent that triggers a WARNING |
| `DISK_CRIT_THRESHOLD`  | `90`    | Usage percent that triggers a CRITICAL |

## Growth-rate trend detection

This is what makes Guardian more than a static threshold check: it also
looks at *how fast* a mount is filling up and projects forward.

| Variable                    | Default | Description |
|-------------------------------|---------|-------------|
| `GROWTH_SAMPLE_WINDOW_MIN`   | `60`    | History window (minutes) used to compute the current growth rate |
| `FORECAST_WARN_HOURS`        | `24`    | Fire a WARNING if projected time-to-full drops below this, even if usage% is still low |
| `FORECAST_CRITICAL_HOURS`    | `6`     | Same, but CRITICAL |
| `MIN_SAMPLES_FOR_FORECAST`   | `3`     | Minimum samples in the window before a forecast is trusted |
| `HISTORY_RETENTION_DAYS`     | `30`    | How long raw samples are kept in `data/disk_history.csv` |

## Space-hog scanning (`du`/`find`)

| Variable               | Default                              | Description |
|--------------------------|----------------------------------------|-------------|
| `SCAN_PATHS`            | `/var/log,/home,/tmp,/var/tmp,/opt`   | Directories scanned for top consumers |
| `TOP_N_CONSUMERS`       | `10`                                    | How many top directories/files to report |
| `LARGE_FILE_SIZE_MB`    | `100`                                   | Individual files at or above this size are flagged |
| `DU_MAX_DEPTH`          | `3`                                     | `du --max-depth` used when ranking subdirectories |

## Log rotation defaults

Used only for files that match no rule in
[`rotation_policy.conf`](../config/rotation_policy.conf).

| Variable                     | Default | Description |
|--------------------------------|---------|-------------|
| `DEFAULT_MAX_SIZE_MB`         | `100`   | Rotate once a file exceeds this size |
| `DEFAULT_MAX_AGE_DAYS`        | `14`    | Rotate once a file is older than this |
| `DEFAULT_KEEP_COUNT`          | `5`     | Rotated+compressed copies retained per file |
| `DEFAULT_COMPRESS`            | `true`  | gzip the rotated copy |
| `ROTATION_QUIET_PERIOD_SEC`   | `30`    | Skip a file modified more recently than this (avoids mid-write truncation) |
| `DRY_RUN`                     | `false` | Log intended rotations/deletions without touching any file |

## Alerting

| Variable               | Default | Description |
|--------------------------|---------|-------------|
| `ENABLE_EMAIL_ALERT`    | `false` | Enable email notifications |
| `ALERT_EMAIL_TO`        | -       | Recipient address |
| `ALERT_EMAIL_FROM`      | `guardian@<hostname>` | Sender address |
| `ENABLE_SLACK_ALERT`    | `false` | Enable Slack notifications |
| `SLACK_WEBHOOK_URL`     | -       | Incoming Webhook URL |
| `ENABLE_TELEGRAM_ALERT` | `false` | Enable Telegram notifications |
| `TELEGRAM_BOT_TOKEN`    | -       | Bot token from @BotFather |
| `TELEGRAM_CHAT_ID`      | -       | Destination chat/channel ID |
| `ALERT_COOLDOWN_MIN`   | `60`    | Minimum minutes between two external notifications for the same mount |

Every alert - whether or not it was actually sent externally - is always
recorded in the report and in `logs/actions.log`; the cooldown only
suppresses repeat *external* notifications (email/Slack/Telegram), never
the internal audit trail. Each channel can also be force-enabled for a
single run with `--email`, `--slack`, or `--telegram`.

## Reports

| Variable                 | Default    | Description |
|---------------------------|------------|-------------|
| `REPORT_FORMATS`          | `txt,json` | Comma-separated formats to generate (`txt`, `html`, `json`) |
| `REPORT_RETENTION_DAYS`   | `30`       | Auto-delete reports (and prune `actions.log`) older than N days |

## Rotation policy file

[`config/rotation_policy.conf`](../config/rotation_policy.conf) defines
per-path rules, checked top to bottom (first match wins):

```
GLOB_PATTERN|MAX_SIZE_MB|MAX_AGE_DAYS|KEEP_COUNT|COMPRESS
```

Example:

```
/var/log/nginx/*.log|100|7|5|true
```

Rotate `/var/log/nginx/*.log` once a file exceeds 100MB *or* is older than
7 days, keep the 5 most recent compressed copies, and gzip them. See
[MODULES.md](MODULES.md#03-log_rotator) for the full matching and safety
logic.
