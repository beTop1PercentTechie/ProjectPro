# Installation

## Requirements

- Ubuntu 24.04 LTS (or another modern systemd-based distro)
- Bash 4.4+
- Root/sudo access
- Standard GNU utilities: `awk`, `grep`, `sed`, `find`, `cut`, `ps`, `ss`, `systemctl`, `journalctl`
- `curl` (for Slack/Telegram alerts)
- `mailutils` or another local MTA (for email alerts) - optional
- `git` (to clone the repository) - optional

## Steps

1. Clone or copy the project onto the target server:

   ```bash
   git clone <repository-url> lsams
   cd lsams
   ```

2. Run the installer as root:

   ```bash
   sudo ./install.sh --symlink
   ```

   This creates the `reports/` and `logs/` directories, makes every script
   executable, and symlinks `bin/lsams` to `/usr/local/bin/lsams` so you can
   run `lsams` from anywhere. Omit `--symlink` to skip that last step.

3. Review and adjust the configuration:

   - [`config/lsams.conf`](../config/lsams.conf) - thresholds, report formats, alert channels
   - [`config/compliance_rules.conf`](../config/compliance_rules.conf) - enable/disable individual compliance checks

4. Run a first audit:

   ```bash
   sudo lsams --quick     # fast subset: health, network, services
   sudo lsams --full      # every module
   ```

5. (Optional) Schedule recurring audits:

   ```bash
   sudo cron/lsams_scheduler.sh install "0 3 * * *"   # daily at 03:00
   ```

## Uninstalling

```bash
sudo ./uninstall.sh
```

This removes the `/usr/local/bin/lsams` symlink and any installed cron job.
It does not delete the project directory, your configuration, or any
previously generated reports/logs.
