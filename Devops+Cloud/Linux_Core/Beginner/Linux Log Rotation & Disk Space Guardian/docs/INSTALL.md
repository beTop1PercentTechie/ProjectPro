# Installation

## Requirements

- Ubuntu Server (tested target: AWS EC2)
- Bash 4.4+
- Root/sudo access
- Standard GNU utilities: `du`, `df`, `find`, `awk`, `sed`, `gzip`, `stat`
- `curl` (for Slack/Telegram alerts)
- `mailutils` or another local MTA (for email alerts) - optional
- `git` (to clone the repository) - optional

## Steps

1. Clone or copy the project onto the target server:

   ```bash
   git clone <repository-url> disk-guardian
   cd disk-guardian
   ```

2. Run the installer as root:

   ```bash
   sudo ./install.sh --symlink
   ```

   This creates the `data/` and `logs/` directories, makes every script
   executable, and symlinks `bin/diskguardian` to `/usr/local/bin/diskguardian`
   so you can run `diskguardian` from anywhere. Omit `--symlink` to skip that
   last step.

3. Review and adjust the configuration:

   - [`config/guardian.conf`](../config/guardian.conf) - thresholds, scan paths, alert channels
   - [`config/rotation_policy.conf`](../config/rotation_policy.conf) - per-path log rotation rules

4. Do a dry run first - it evaluates every decision without touching a
   single file:

   ```bash
   sudo diskguardian --full --dry-run
   ```

5. Run for real:

   ```bash
   sudo diskguardian --monitor   # lightweight: tracking + alerting
   sudo diskguardian --full      # adds space-hog scanning + log rotation
   ```

6. Schedule the recommended cron cadence (a frequent lightweight pass, plus
   a less-frequent full sweep):

   ```bash
   sudo cron/guardian_scheduler.sh install "*/5 * * * *" "0 3 * * *"
   ```

## Uninstalling

```bash
sudo ./uninstall.sh
```

This removes the `/usr/local/bin/diskguardian` symlink and any installed
cron jobs. It does not delete the project directory, your configuration,
history data, or previously generated reports/logs.
