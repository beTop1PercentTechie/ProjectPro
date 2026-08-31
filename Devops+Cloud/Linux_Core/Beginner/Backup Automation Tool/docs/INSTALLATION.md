# Installation

## Requirements

- Ubuntu 24.04 LTS (or another modern Linux distribution)
- Bash 4.4+
- Root/sudo access (needed to read other users' files and write to system log locations)
- Standard GNU utilities: `tar`, `gzip`, `find`, `stat`, `awk`, `sed`
- `rsync` - only required if you enable `USE_RSYNC_STAGING` (optional feature)
- `git` - to clone the repository (optional)

## Steps

1. Clone or copy the project onto the target server:

   ```bash
   git clone <repository-url> backup-tool
   cd backup-tool
   ```

2. Run the installer as root:

   ```bash
   sudo ./install.sh --symlink
   ```

   This creates `backups/`, `logs/`, `reports/`, and `restore-test/`, makes every script executable, and (with `--symlink`) links the four `bin/` scripts onto `/usr/local/bin` as `bat-backup`, `bat-restore`, `bat-list`, and `bat-status`, so you can run them from anywhere. Omit `--symlink` to skip that step and always run the scripts by their full path instead.

3. Edit `config/backup.conf` - at minimum, set `SOURCE_DIRS` to the directories you actually want backed up. **Start with a safe test sandbox, not real system directories** - see [TESTING.md](TESTING.md).

4. Preview a run without touching anything:

   ```bash
   sudo bat-backup --dry-run
   ```

5. Run a real backup:

   ```bash
   sudo bat-backup
   ```

6. Check the result:

   ```bash
   sudo bat-status
   sudo bat-list
   ```

7. Once you trust it, schedule it:

   ```bash
   sudo cron/backup-cron-scheduler.sh install "0 2 * * *"
   ```

## Uninstalling

```bash
sudo ./uninstall.sh
```

Removes the `/usr/local/bin` symlinks and any installed cron job. It does **not** delete your configuration, existing backups, or logs - remove those manually if you no longer need them.
