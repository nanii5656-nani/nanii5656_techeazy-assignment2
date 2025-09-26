# Techeazy DevOps Assignment 2 – S3 / EC2 Logs Upload Automation

## 📋 Assignment Summary

This project implements the second task of the DevOps assignment from Techeazy. The objectives are:

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
├── aws-cli/
│ ├── upload-logs.sh
│ └── verify-list.sh
├── cloudformation/
│ ├── main-template.yaml
├── terraform/
│ ├── main.tf
│ ├── iam.tf
│ ├── ec2.tf
│ └── s3.tf
├── .gitignore
└── README.md
