# ELK Stack Usage Guide

This guide explains how to use your ELK (Elasticsearch, Logstash, Kibana) stack for log management, search, and visualization.

---

## 1. Overview
- **Elasticsearch**: Search and analytics engine. Stores and indexes your data.
- **Logstash**: Data processing pipeline. Ingests, transforms, and forwards logs to Elasticsearch.
- **Kibana**: Visualization tool. Explore and visualize data stored in Elasticsearch.

---

## 2. Service Management
- Start/stop/restart services:
  ```sh
  sudo systemctl start|stop|restart elasticsearch
  sudo systemctl start|stop|restart logstash
  sudo systemctl start|stop|restart kibana
  ```
- Check status:
  ```sh
  sudo systemctl status elasticsearch
  sudo systemctl status logstash
  sudo systemctl status kibana
  ```

---

## 3. Configuration Files
- **Elasticsearch**: `/etc/elasticsearch/elasticsearch.yml`
- **Logstash**: `/etc/logstash/logstash.yml`, pipelines in `/etc/logstash/conf.d/`
- **Kibana**: `/etc/kibana/kibana.yml`

Edit these files to change settings (network, authentication, pipelines, etc.), then restart the service.

---

## 4. Ingesting Logs
- Place Logstash pipeline configs in `/etc/logstash/conf.d/` (e.g., `input`, `filter`, `output` blocks).
- Example pipeline:
  ```
  input {
    file {
      path => "/var/log/syslog"
      start_position => "beginning"
    }
  }
  filter {
    grok {
      match => { "message" => "%{SYSLOGBASE}%{GREEDYDATA:msg}" }
    }
  }
  output {
    elasticsearch {
      hosts => ["localhost:9200"]
      index => "syslog-%{+YYYY.MM.dd}"
    }
  }
  ```
- Reload Logstash after changes:
  ```sh
  sudo systemctl restart logstash
  ```

---

## 5. Accessing Kibana
- Open your browser and go to: `http://localhost:5601`
- Use the web UI to:
  - Create index patterns
  - Build dashboards and visualizations
  - Search and analyze logs

---

## 6. Security Best Practices
- Enable authentication and TLS in all configs
- Restrict access to trusted IPs
- Regularly update ELK components
- Monitor logs for errors and suspicious activity
- Backup configs and data

---

## 7. Troubleshooting
- Check logs:
  - Elasticsearch: `/var/log/elasticsearch/`
  - Logstash: `/var/log/logstash/`
  - Kibana: `/var/log/kibana/`
- Use `journalctl -u <service>` for systemd logs
- Common issues: permissions, port conflicts, config errors

---

## 8. References
- [Elastic Stack Documentation](https://www.elastic.co/guide/en/elastic-stack-get-started/current/get-started-elastic-stack.html)
- [Logstash Pipeline Examples](https://www.elastic.co/guide/en/logstash/current/pipeline.html)
- [Kibana User Guide](https://www.elastic.co/guide/en/kibana/current/index.html)

---

## 9. Backing Up ELK Configuration with Synology Drive

To ensure your ELK stack configuration is safely backed up, you can use the Synology Drive Client installed on this server. Here’s how to do it:

### What to Back Up
- **Elasticsearch config:** /etc/elasticsearch/
- **Logstash config:** /etc/logstash/
- **Kibana config:** /etc/kibana/
- **Custom pipelines:** /etc/logstash/conf.d/
- **ELK documentation:** /opt/jeylogscat/

### Steps
1. **Create a backup folder** (if not already done):
   - Example: /opt/jeylogscat/elk_backup
2. **Copy configuration and documentation:**
   ```sh
   sudo cp -r /etc/elasticsearch /opt/jeylogscat/elk_backup/
   sudo cp -r /etc/logstash /opt/jeylogscat/elk_backup/
   sudo cp -r /etc/kibana /opt/jeylogscat/elk_backup/
   cp -r /opt/jeylogscat/*.md /opt/jeylogscat/elk_backup/
   ```
3. **Configure Synology Drive Client** to sync /opt/jeylogscat/elk_backup to your Synology NAS.
   - Open Synology Drive Client GUI or use the CLI.
   - Add /opt/jeylogscat/elk_backup as a sync folder.
   - Select your Synology NAS destination folder.
   - Start the sync process.

### Tips
- Schedule regular syncs for up-to-date backups.
- Test restoring from backup to ensure integrity.
- Secure backup folders with proper permissions.

---

## 10. Example Synology Drive Client Configuration for ELK Backup

To ensure a complete backup of your ELK stack, the following local files and folders should be included:

### Local Folders to Sync
- `/etc/elasticsearch/` (Elasticsearch config)
- `/etc/logstash/` (Logstash config and pipelines)
- `/etc/kibana/` (Kibana config)
- `/opt/jeylogscat/` (ELK documentation and local backups)
- `/var/lib/elasticsearch/` (Elasticsearch data, optional and can be large)
- `/var/lib/logstash/` (Logstash data, optional)

### Synology NAS Target
- **NAS Host:** jeynas01
- **Remote Folder:** `/volume1/JeyFiles/Jeremie/Informatique/Lab@Home/BackupSrv/jeysrv03/elk`

### Steps to Configure
1. Open Synology Drive Client on your server.
2. Add a new sync task:
   - **Local folder:** Add each of the folders above (or create a parent folder, e.g., `/opt/jeylogscat/elk_backup`, and copy all relevant files/folders into it).
   - **Remote folder:** Set to `/volume1/JeyFiles/Jeremie/Informatique/Lab@Home/BackupSrv/jeysrv03/elk` on jeynas01.
3. Choose sync direction (two-way or upload-only recommended for backup).
4. Save and start the sync task.

### Automation Example (Optional)
To automate copying all relevant files to a single backup folder before sync, add a cron job:
```sh
sudo mkdir -p /opt/jeylogscat/elk_backup
sudo cp -r /etc/elasticsearch /opt/jeylogscat/elk_backup/
sudo cp -r /etc/logstash /opt/jeylogscat/elk_backup/
sudo cp -r /etc/kibana /opt/jeylogscat/elk_backup/
sudo cp -r /var/lib/elasticsearch /opt/jeylogscat/elk_backup/
sudo cp -r /var/lib/logstash /opt/jeylogscat/elk_backup/
cp -r /opt/jeylogscat/*.md /opt/jeylogscat/elk_backup/
```

Then sync `/opt/jeylogscat/elk_backup` to your NAS.

---
**Note:** Backing up data folders (`/var/lib/elasticsearch`, `/var/lib/logstash`) can be large and may require stopping services for consistency. For config-only backup, exclude these folders.

---

Generated by GitHub Copilot (GPT-4.1)

## Backup entry - 20251222T124618Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T124618Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T125215Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T125215Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T130244Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T130244Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T131213Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T131213Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T131313Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T131313Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T131325Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T131325Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T131459Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T131459Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T131612Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T131612Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T131717Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T131717Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T131837Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T131837Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T132305Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T132305Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T133302Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T133302Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T133500Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T133500Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T134717Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T134717Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251222T134920Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251222T134920Z
- Dry-run: 0
- Log: /opt/jeylogscat/backup.log


## Backup entry - 20251223T150324Z

- Backed up paths: /etc/elasticsearch /etc/logstash /etc/kibana /var/lib/elasticsearch /etc/ssl
- Destination: /opt/jeylogscat/backups/20251223T150324Z
- Dry-run: 1
- Log: /opt/jeylogscat/backup.log

