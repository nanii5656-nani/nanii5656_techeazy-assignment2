#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="us-east-1"
BUCKET_NAME="$1"   # required: pass bucket name as first arg
AMI="ami-0abcdef1234567890"  # replace
INSTANCE_TYPE="t3.micro"
KEY_NAME="" # optional: put key pair name or leave empty
PROFILE=""  # optional aws cli profile, e.g. "--profile myprofile"

if [ -z "$BUCKET_NAME" ]; then
  echo "Usage: $0 <bucket-name>"
  exit 1
fi

export AWS_REGION
echo "Using region $AWS_REGION"

# Create S3 bucket
echo "Creating bucket $BUCKET_NAME..."
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" ${PROFILE} \
  --create-bucket-configuration LocationConstraint=${AWS_REGION} || true

# Add lifecycle rule to delete objects after 7 days
cat > /tmp/lifecycle.json <<EOF
{
  "Rules": [
    {
      "ID": "DeleteAfter7Days",
      "Status": "Enabled",
      "Filter": {},
      "Expiration": { "Days": 7 }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" --lifecycle-configuration file:///tmp/lifecycle.json ${PROFILE}

# Create read-only policy document
cat > /tmp/readonly_policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action":[ "s3:ListBucket", "s3:GetObject" ],
      "Resource":[ "arn:aws:s3:::$BUCKET_NAME", "arn:aws:s3:::$BUCKET_NAME/*" ]
    }
  ]
}
EOF

# Create uploader policy document (allow create and put, deny read)
cat > /tmp/uploader_policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action":[ "s3:CreateBucket", "s3:PutObject", "s3:PutObjectAcl", "s3:PutObjectTagging", "s3:PutBucketAcl", "s3:PutBucketTagging", "s3:ListAllMyBuckets" ],
      "Resource": ["*"]
    },
    {
      "Sid": "DenyRead",
      "Effect": "Deny",
      "Action": ["s3:GetObject","s3:ListBucket"],
      "Resource": [ "arn:aws:s3:::$BUCKET_NAME", "arn:aws:s3:::$BUCKET_NAME/*" ]
    }
  ]
}
EOF

# Create roles and attach policies
ASSUME_JSON='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

echo "Creating role: assignment2_s3_read_only"
ROLE_READ_ARN=$(aws iam create-role --role-name assignment2_s3_read_only --assume-role-policy-document "$ASSUME_JSON" ${PROFILE} | jq -r .Role.Arn)
aws iam put-role-policy --role-name assignment2_s3_read_only --policy-name assignment2_s3_readonly_policy --policy-document file:///tmp/readonly_policy.json ${PROFILE}

echo "Creating role: assignment2_s3_uploader"
ROLE_UPLOADER_ARN=$(aws iam create-role --role-name assignment2_s3_uploader --assume-role-policy-document "$ASSUME_JSON" ${PROFILE} | jq -r .Role.Arn)
aws iam put-role-policy --role-name assignment2_s3_uploader --policy-name assignment2_uploader_policy --policy-document file:///tmp/uploader_policy.json ${PROFILE}

# Instance profile
aws iam create-instance-profile --instance-profile-name assignment2_uploader_profile ${PROFILE} || true
aws iam add-role-to-instance-profile --instance-profile-name assignment2_uploader_profile --role-name assignment2_s3_uploader ${PROFILE} || true

# Create key pair if user set KEY_NAME blank skip
if [ -n "$KEY_NAME" ]; then
  echo "Using key pair $KEY_NAME"
fi

# Build user-data (very similar to above)
read -r -d '' USERDATA <<'EOF'
#!/bin/bash
set -e
if ! command -v aws >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y unzip curl
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
fi

cat <<'SH' > /opt/shutdown-upload.sh
#!/bin/bash
BUCKET="__BUCKET__"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DEST_PREFIX="ec2-logs/${TS}"
if [ -f /var/log/cloud-init.log ]; then
  aws s3 cp /var/log/cloud-init.log s3://$BUCKET/${DEST_PREFIX}/cloud-init.log
fi
if [ -d /var/www/app/logs ]; then
  aws s3 cp --recursive /var/www/app/logs s3://$BUCKET/app/logs/${TS}/
fi
SH
chmod +x /opt/shutdown-upload.sh

cat <<'SRV' > /etc/systemd/system/shutdown-upload.service
[Unit]
Description=Upload logs to S3 at shutdown
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/bin/true
ExecStop=/opt/shutdown-upload.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SRV

systemctl daemon-reload
systemctl enable shutdown-upload.service
EOF

USERDATA="${USERDATA//__BUCKET__/$BUCKET_NAME}"

# Launch EC2 instance
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --region $AWS_REGION ${PROFILE} --query 'Subnets[0].SubnetId' --output text)
if [ -z "$SUBNET_ID" ]; then
  # fallback to first subnet in default VPC
  SUBNET_ID=$(aws ec2 describe-subnets --region $AWS_REGION ${PROFILE} --query 'Subnets[0].SubnetId' --output text)
fi

SG=$(aws ec2 create-security-group --group-name assignment2_sg --description "assignment2 sg" ${PROFILE} --vpc-id $(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text) --output json)
SG_ID=$(echo $SG | jq -r .GroupId)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 ${PROFILE} || true

echo "Launching EC2 instance..."
if [ -n "$KEY_NAME" ]; then
  INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI --count 1 --instance-type $INSTANCE_TYPE --subnet-id $SUBNET_ID --security-group-ids $SG_ID --iam-instance-profile Name=assignment2_uploader_profile --key-name $KEY_NAME --user-data "$USERDATA" ${PROFILE} --query 'Instances[0].InstanceId' --output text)
else
  INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI --count 1 --instance-type $INSTANCE_TYPE --subnet-id $SUBNET_ID --security-group-ids $SG_ID --iam-instance-profile Name=assignment2_uploader_profile --user-data "$USERDATA" ${PROFILE} --query 'Instances[0].InstanceId' --output text)
fi

echo "Launched instance $INSTANCE_ID"
echo "Uploader role ARN: $ROLE_UPLOADER_ARN"
echo "Read-only role ARN: $ROLE_READ_ARN"
echo "Bucket: $BUCKET_NAME"

echo "To verify listing as read-only role:"
echo "aws sts assume-role --role-arn $ROLE_READ_ARN --role-session-name verify-list | jq -r .Credentials"

echo "# PR test" >> README.md
git add README.md
git commit -m "Dummy commit to enable PR creation"
git push origin feat/assignment-2-clean
