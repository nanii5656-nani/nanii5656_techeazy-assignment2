# DevOps Assignment 2 – Infrastructure Automation

This project extends the previous automation to provision AWS resources and automate log archival using **Terraform**, **AWS CLI**, and **Bash scripting**.  

---

## 📋 Assignment Summary

This project objectives are:

1. Create two IAM roles:
   - **Read-only role**: can only list or get objects from S3 (no writes).
   - **Upload role**: can create S3 buckets and upload objects, but **cannot read or download** objects.
2. Attach the upload role to an EC2 instance via an instance profile.
3. Provision a **private S3 bucket**, where its name is configurable; if not provided, execution should fail with error.
4. After the EC2 instance shuts down, upload its logs (e.g. `/var/log/cloud-init.log` or other custom logs) to the S3 bucket.
5. Upload application logs (from the first assignment) under the prefix `app/logs/`.
6. Add an S3 lifecycle rule to delete logs older than 7 days.
7. Use the read-only role to verify that uploaded files can be listed but not modified.

---

## 🛠 Tools & Technologies Used

- Terraform (in `terraform/` directory)  
- CloudFormation (in `cloudformation/` directory)  
- AWS CLI / Bash scripts (in `aws-cli/` directory)  
- IAM policies, Instance Profiles, S3 lifecycle, shutdown scripts  
- Bash / shell scripting for log upload  

---

## 🏗 Directory Structure

- aws-cli/
  - assignment2_cli.sh
- cloudformation/
  - assignment2.yaml
- terraform/
  - main.tf
  - variables.tf
  - user_data.sh.tpl
- .gitignore

---

## ⚙️ Prerequisites

- **AWS Account** with IAM user (Programmatic access + proper permissions for EC2, IAM, S3, CloudFormation, STS).  
- **Tools**:
  ```bash
  sudo apt update && sudo apt install -y git jq unzip curl
  # AWS CLI v2
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install
  # Terraform
  wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip -O /tmp/terraform.zip
  unzip /tmp/terraform.zip -d /tmp && sudo mv /tmp/terraform /usr/local/bin/
  # Optional: GitHub CLI
  type -p gh >/dev/null || sudo apt install -y gh

---

**📝 Setup & Deployment**
**Terraform**
1. cd assignment-2/terraform
2. terraform init
3. terraform plan -var="bucket_name=your-unique-bucket-name" -var="ami=ami-0xxxx"
4. terraform apply -var="bucket_name=your-unique-bucket-name" -var="ami=ami-0xxxx" -auto-approve

Creates:
*  IAM Roles: read-only (A) & uploader (B)
* Private S3 bucket with 7-day lifecycle
* EC2 instance with instance profile and shutdown log upload

---

**Test Instance & Logs**

1. SSH if key provided
  * ssh -i /path/to/key.pem ubuntu@<PUBLIC_IP>
2. sudo mkdir -p /var/www/app/logs
  * echo "hello $(date)" | sudo tee /var/www/app/logs/test.log
3. Run upload script manually or shutdown
  *  sudo /opt/shutdown-upload.sh
  *  sudo shutdown -h now
4.  Verify logs in S3
   * aws s3 ls s3://your-unique-bucket-name --recursive

---

**Verify Role A (read-only)**

This script assumes a read-only role (Role A) and lists all objects in the specified S3 bucket.

#!/bin/bash
ROLE_ARN="$1"
BUCKET="$2"

creds=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name verify-list --duration-seconds 900)

export AWS_ACCESS_KEY_ID=$(echo "$creds" | jq -r '.Credentials.AccessKeyId')

export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | jq -r '.Credentials.SecretAccessKey')

export AWS_SESSION_TOKEN=$(echo "$creds" | jq -r '.Credentials.SessionToken')

aws s3 ls "s3://$BUCKET/" --recursive


* RUN :-

bash verify_list.sh arn:aws:iam::123456789012:role/assignment2_s3_read_only your-unique-bucket-name

---

**CloudFormation & AWS CLI**

bash assignment-2/aws-cli/assignment2_cli.sh your-unique-bucket-name

---

**After all these push these into github**

* git init
* git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPO.git
* git add .
* git commit -m
* git branch -M main
* git push -u origin main

  

