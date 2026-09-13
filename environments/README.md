# Separate environments

Each directory is an independent Terraform root that calls the same reusable
modules. `pre` means pre-production. No existing deployment or state is moved.

| Directory | Name prefix / tag | VPC CIDR | Initial ASG min / desired / max |
| --- | --- | --- | --- |
| `dev` | `devops-dev` / `dev` | `10.30.0.0/16` | 1 / 1 / 3 |
| `test` | `devops-test` / `test` | `10.40.0.0/16` | 1 / 1 / 3 |
| `pre` | `devops-pre` / `pre` | `10.50.0.0/16` | 2 / 2 / 4 |
| `prod` | `devops-prod` / `prod` | `10.60.0.0/16` | 2 / 2 / 4 |

Each also creates one standalone EC2 instance. All default to `t3.micro`, two AZs,
private compute, no ingress, outbound HTTPS, and NAT disabled. These are starting
configurations; size and configure each environment for your application.

## Deploy one environment

From the repository root, for example:

```powershell
cd environments/dev
Copy-Item terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: replace bucket_name with a globally unique name.
$env:AWS_PROFILE = "your-dev-profile"
terraform init -backend-config="bucket=bucket-backend-terraform-313932316713-us-east-1" -backend-config="region=us-east-1"
terraform validate
terraform plan -out=deployment.tfplan
terraform apply deployment.tfplan
```

Repeat in `environments/test`, `environments/pre`, or `environments/prod` with
that environment's credentials and unique bucket name. You can use separate AWS
accounts through profiles; directories alone do not enforce account isolation.
No Terraform workspaces are required. Run commands from the selected directory,
not from the repository root, which still contains the original S3 deployment.

Each directory uses a separate S3 state key in the shared backend bucket. Follow
[the one-time backend setup](../bootstrap/backend/README.md) before deployment.
Private variable files and local state backups are ignored; provider lock files
are tracked. Never copy state between environments.

Override `vpc_cidr`, `instance_type`, `capacity`, `aws_region`, `ami_id`, NAT
options, and instance profile independently in each `terraform.tfvars`.
Keep name prefixes and bucket names distinct. The VPC input requires a /16;
public /24 subnets use offsets 1 and 2, private /24 subnets use 11 and 12.

Pin a compatible AMI for controlled pre/prod releases. Without a pinned AMI,
the latest AL2023 x86_64 image is looked up during planning. Private instances
need NAT or appropriate interface endpoints plus IAM permissions for SSM
management. Enabling NAT with `single_nat_gateway = false` creates one per AZ.

## Shared remote state

Committed backend.tf files enable S3 locking and separate environment keys.
The bucket `bucket-backend-terraform-313932316713-us-east-1` and region `us-east-1`
are configured in each backend. For state migration, see the
[backend bootstrap guide](../bootstrap/backend/README.md). Terraform >= 1.10 is required.
