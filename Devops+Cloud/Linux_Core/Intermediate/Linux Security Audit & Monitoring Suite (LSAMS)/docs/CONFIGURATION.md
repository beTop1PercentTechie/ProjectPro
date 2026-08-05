# Configuration Reference

All settings live in [`config/lsams.conf`](../config/lsams.conf), a plain
Bash file sourced at startup. Anything you omit falls back to the default
defined in [`lib/core/config_loader.sh`](../lib/core/config_loader.sh).

## Paths

| Variable    | Default            | Description                    |
|-------------|---------------------|--------------------------------|
| `REPORT_DIR`| `<install>/reports` | Where generated reports are written |
| `LOG_DIR`   | `<install>/logs`    | Where run logs are written      |

## Report options

| Variable                 | Default        | Description |
|---------------------------|----------------|-------------|
| `REPORT_FORMATS`          | `txt,html,json`| Comma-separated formats to generate |
| `REPORT_RETENTION_DAYS`   | `30`           | Auto-delete reports older than N days (`0` disables) |

## System health thresholds (percent)

| Variable               | Default | Description |
|-------------------------|---------|-------------|
| `CPU_WARN_THRESHOLD`   | `80`    | 1-minute load average, as % of available cores |
| `MEM_WARN_THRESHOLD`   | `80`    | RAM utilization |
| `DISK_WARN_THRESHOLD`  | `80`    | Per-filesystem usage warning |
| `DISK_CRIT_THRESHOLD`  | `90`    | Per-filesystem usage critical |

## Authentication analysis

| Variable                    | Default | Description |
|-------------------------------|---------|-------------|
| `FAILED_LOGIN_THRESHOLD`     | `5`     | Failed attempts from one IP to flag as brute-force |
| `FAILED_LOGIN_WINDOW_MIN`    | `10`    | Time window (minutes) considered for the threshold above |
| `ACCOUNT_INACTIVE_DAYS`      | `90`    | Days without login before a human account is flagged inactive |

## Scoring weights

Each finding deducts points from a starting score of 100 (floored at 0):

| Variable          | Default | Points deducted per finding |
|--------------------|---------|-------------------------------|
| `SCORE_CRITICAL`  | `15`    | Per CRITICAL finding |
| `SCORE_HIGH`      | `10`    | Per HIGH finding |
| `SCORE_MEDIUM`    | `5`     | Per MEDIUM finding |
| `SCORE_LOW`       | `2`     | Per LOW finding |

Risk rating is derived from the final score:

| Score range | Risk rating |
|-------------|-------------|
| 90-100      | LOW         |
| 70-89       | MEDIUM      |
| 40-69       | HIGH        |
| 0-39        | CRITICAL    |

## Alerting

| Variable               | Default | Description |
|--------------------------|---------|-------------|
| `ALERT_MIN_SCORE`       | `70`    | Alerts only fire when the score is below this |
| `ENABLE_EMAIL_ALERT`    | `false` | Enable email notifications |
| `ALERT_EMAIL_TO`        | -       | Recipient address |
| `ALERT_EMAIL_FROM`      | `lsams@<hostname>` | Sender address |
| `ENABLE_SLACK_ALERT`    | `false` | Enable Slack notifications |
| `SLACK_WEBHOOK_URL`     | -       | Incoming Webhook URL |
| `ENABLE_TELEGRAM_ALERT` | `false` | Enable Telegram notifications |
| `TELEGRAM_BOT_TOKEN`    | -       | Bot token from @BotFather |

The email alert attaches the run's HTML report directly (falling back to the
TXT report if HTML wasn't in `REPORT_FORMATS`), via GNU Mailutils' `mail -A`.
Slack and Telegram alerts only include the score/risk and the report's file
path on the server - they do not upload the file itself.
| `TELEGRAM_CHAT_ID`      | -       | Destination chat/channel ID |

Each alert channel can also be force-enabled for a single run with
`--email`, `--slack`, or `--telegram`, regardless of the config file.

## Compliance checklist

[`config/compliance_rules.conf`](../config/compliance_rules.conf) toggles
individual checks in the compliance module on or off (`true`/`false`), so
you can adapt the checklist to your organization's policy without touching
any code. See [MODULES.md](MODULES.md#08-compliance-check) for what each
rule verifies.
