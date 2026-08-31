# Troubleshooting

| Symptom | Likely cause | What to do |
|---------|---------------|------------|
| `Source is not readable (permission denied)` | The tool isn't running as root, or the source directory's permissions genuinely block access | Run with `sudo`. If it still fails, check `ls -la` on the parent directory. |
| `Another backup run appears to be in progress (lock held: ...)` | A previous run crashed without cleaning up, or is genuinely still running | Check `ps aux \| grep backup.sh` first. If nothing is really running, remove the lock manually: `sudo rm -rf <LOCK_FILE>` (the path is shown in the error message). |
| `Not enough disk space at ...` | The backup destination's filesystem is close to full | Free up space, lower `MIN_FREE_DISK_MB` if the threshold is overly conservative, or point `BACKUP_ROOT` at a filesystem with more room. |
| `Archive failed integrity check (corrupt or incomplete)` | The backup process was killed partway through, or the disk filled up mid-write | This is exactly what `.partial` naming and `validate_archive` are for - a bad archive is deleted automatically rather than left behind looking valid. Just re-run the backup. |
| Retention isn't deleting anything, even with many backups | `RETENTION_COUNT=0` disables retention entirely; or the archives don't share the same sanitized source-name prefix (e.g. you changed `SOURCE_DIRS` paths between runs) | Check `RETENTION_COUNT` in your config, and confirm `ls backups/` shows a consistent `<name>_*.tar.gz` prefix per source. |
| `restore.sh` refuses with "Destination already exists and is not empty" | You're restoring into a folder that already has files (possibly from a previous restore) | Choose a new, empty `--dest`. This check exists specifically to stop two restores from silently mixing files together. |
| `USE_RSYNC_STAGING is true but 'rsync' is not installed` | `rsync` isn't installed, but the config enables staging | Either `apt-get install rsync`, or set `USE_RSYNC_STAGING=false`. The backup still completes either way - this is a warning, not a failure. |
| Cron never seems to run the backup | The cron job wasn't installed, or the cron daemon itself isn't running | Check `cat /etc/cron.d/backup-automation` exists and looks correct; check `sudo systemctl status cron` shows `active (running)`. Always verify the script works with a manual run before trusting cron with it. |
| `command not found: bat-backup` (etc.) | `install.sh` was never run, or was run without `--symlink` | Run `sudo ./install.sh --symlink`, or just call the script by its full path: `bin/backup.sh`. |
| A script says "Permission denied" when you try to run it directly (`./backup.sh`) | Files copied from another machine (e.g. via `scp` from Windows) often lose their executable bit | Run it via the interpreter instead: `bash bin/backup.sh`, or `chmod +x bin/*.sh lib/*.sh` and try again. |

## The one habit that matters more than any single fix above

After making a change - editing the config, fixing a script, pushing an update to a server - **verify it independently** rather than trusting that it worked:

```bash
bash -n bin/backup.sh          # syntax-check a script you just edited
grep -n "SOURCE_DIRS" config/backup.conf   # confirm a config change actually landed
sudo bat-status                # confirm the tool's own view of reality matches your expectation
```

A command reporting success and the thing it was supposed to do actually having happened are two different claims. Check both.
