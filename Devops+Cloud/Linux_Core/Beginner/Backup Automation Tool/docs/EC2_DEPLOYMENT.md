# Deploying to AWS EC2

## The flow

```
Local machine -> GitHub -> EC2 -> git clone -> configure -> test -> cron -> automatic backups
```

## 1. Push the project to GitHub first

See [the Git/GitHub section of the README](../README.md#version-control) if you haven't already.

## 2. Connect to your EC2 instance over SSH

```bash
ssh -i /path/to/your-key.pem ubuntu@<ec2-public-ip>
```

`ssh` connects to a remote machine using a private key instead of a password - AWS gave you the matching `.pem` key file when you launched the instance. Keep it private; anyone with that file can log in as you.

## 3. Verify the tools this project needs are actually present

Don't assume a fresh EC2 instance has everything:

```bash
bash --version
git --version
tar --version
gzip --version
rsync --version      # only needed if you plan to enable USE_RSYNC_STAGING
systemctl status cron
```

If `cron` isn't running:
```bash
sudo systemctl enable --now cron
```

If `rsync` is missing and you want it:
```bash
sudo apt-get update && sudo apt-get install -y rsync
```

## 4. Clone the project

```bash
git clone <your-repository-url> backup-tool
cd backup-tool
```

## 5. Configure it for this server

Edit `config/backup.conf` - set `SOURCE_DIRS` to what actually needs backing up on *this* server. Start with a safe test sandbox (see [TESTING.md](TESTING.md)) even on EC2, before pointing it at real directories.

## 6. Install and test

```bash
sudo bash install.sh --symlink
sudo bat-backup --dry-run
sudo bat-backup
sudo bat-status
```

## 7. Schedule it

```bash
sudo cron/backup-cron-scheduler.sh install "0 2 * * *"
cat /etc/cron.d/backup-automation
```

## 8. Where should the actual backups end up?

A backup that lives on the same disk as the data it's protecting doesn't protect against that disk failing, the instance being terminated, or the volume being deleted by mistake. For a real deployment, treat `BACKUP_ROOT` as a *local staging area* and copy archives off the instance - to S3, to another instance, or downloaded via `scp` - rather than leaving this as the only copy. This project's core scope is the local backup/rotation/restore mechanism; shipping archives off-box is listed as a production-style improvement (see the README's Future Improvements section) rather than built in, so it can be added deliberately once you've decided where those backups should actually live.
