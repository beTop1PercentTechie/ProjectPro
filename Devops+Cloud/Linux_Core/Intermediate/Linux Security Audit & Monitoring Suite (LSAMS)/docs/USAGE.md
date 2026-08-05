# Usage

## Basic commands

```bash
sudo lsams --full                        # run every audit module (default)
sudo lsams --quick                       # fast subset: health, network, services
sudo lsams --modules=users,ssh           # run only the specified modules
sudo lsams --list-modules                # show all available module keys
sudo lsams --format=json                 # only generate a JSON report
sudo lsams --output-dir=/tmp/lsams-out   # write reports somewhere else
sudo lsams --config=/etc/lsams/lsams.conf  # use an alternate config file
sudo lsams --email --slack               # force-enable alerts for this run only
sudo lsams --no-color                    # disable ANSI colors (e.g. for CI logs)
sudo lsams --help
```

If you did not run `install.sh --symlink`, invoke the script directly instead:

```bash
sudo ./lsams.sh --full
```

## Exit codes

| Code | Meaning                                                          |
|------|-------------------------------------------------------------------|
| 0    | Audit completed; security score is at or above `ALERT_MIN_SCORE`  |
| 1    | Invalid arguments, or not run as root                             |
| 2    | Audit completed; security score is below `ALERT_MIN_SCORE`        |

This makes LSAMS easy to wire into monitoring pipelines: a non-zero exit
means "go look at the report."

## Reading the output

Each run prints a live, color-coded log to the console and to a timestamped
file under `logs/`. At the end it prints a summary line:

```
Security Score: 82/100  |  Risk Rating: MEDIUM
```

Reports are written to `reports/` in the formats configured by
`REPORT_FORMATS` (see [CONFIGURATION.md](CONFIGURATION.md)):

- `lsams_report_<host>_<timestamp>.txt`  - plain text, good for email bodies or terminals
- `lsams_report_<host>_<timestamp>.html` - shareable, styled report for a browser
- `lsams_report_<host>_<timestamp>.json` - machine-readable, for ingestion into a SIEM/dashboard

## Automating with cron

`cron/lsams_scheduler.sh` manages a dedicated file in `/etc/cron.d/lsams` so
it never touches your personal crontab:

```bash
sudo cron/lsams_scheduler.sh install "0 3 * * *"   # every day at 03:00
sudo cron/lsams_scheduler.sh remove
```

Cron output is appended to `logs/cron.log`.
