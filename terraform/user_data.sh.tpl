#!/bin/bash
set -e

# Terraform substituted variable
BUCKET="${bucket_name}"

# Path for application logs
APP_LOG_PATH="/var/www/app/logs"

# Create upload script
cat <<'EOF' > /usr/local/bin/upload-logs.sh
#!/bin/bash
set -e

# Current timestamp
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Upload system logs
aws s3 cp /var/log/cloud-init.log s3://$BUCKET/ec2-logs/$TS/cloud-init.log || true
aws s3 cp /var/log/syslog s3://$BUCKET/ec2-logs/$TS/syslog || true

# Upload application logs
if [ -d "$APP_LOG_PATH" ]; then
  aws s3 cp --recursive "$APP_LOG_PATH" s3://$BUCKET/app/logs/$TS/ || true
fi
EOF

chmod +x /usr/local/bin/upload-logs.sh

# Register as systemd service
cat <<'EOF' > /etc/systemd/system/upload-logs.service
[Unit]
Description=Upload logs to S3 on shutdown

[Service]
Type=oneshot
ExecStart=/usr/local/bin/upload-logs.sh
RemainAfterExit=yes

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

systemctl enable upload-logs.service
