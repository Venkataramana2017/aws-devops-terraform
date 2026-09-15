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
# Edit terraform.tfvars for the environment.
$env:AWS_PROFILE = "your-dev-profile"
terraform init -backend-config="bucket=bucket-backend-terraform-313932316713-us-east-1" -backend-config="region=us-east-1"
terraform validate
terraform plan -out=deployment.tfplan
terraform apply deployment.tfplan
```

Repeat in `environments/test`, `environments/pre`, or `environments/prod` with
that environment's credentials and inputs. You can use separate AWS
accounts through profiles; directories alone do not enforce account isolation.
No Terraform workspaces are required. Run commands from the selected directory,
not from the repository root. Application S3 buckets are not created.

Each directory uses a separate S3 state key in the shared backend bucket. Follow
[the one-time backend setup](../bootstrap/backend/README.md) before deployment.
Private variable files and local state backups are ignored; provider lock files
are tracked. Never copy state between environments.

Override `vpc_cidr`, `instance_type`, `capacity`, `aws_region`, `ami_id`, NAT
options, and instance profile independently in each `terraform.tfvars`.
Keep name prefixes distinct. The VPC input requires a /16;
public /24 subnets use offsets 1 and 2, private /24 subnets use 11 and 12.

Pin a compatible AMI for controlled pre/prod releases. Without a pinned AMI,
the latest AL2023 x86_64 image is looked up during planning. Private instances
need NAT or appropriate interface endpoints plus IAM permissions for SSM
management. Enabling NAT with `single_nat_gateway = false` creates one per AZ.

## GitHub Actions variables

Plan jobs use GitHub environments `dev-plan`, `test-plan`, `pre-plan`, and
`prod-plan`. Apply/destroy jobs use `dev`, `test`, `pre`, and `prod`.
Variables configured on `dev` are not available to `dev-plan`.

In **Settings > Environments > environment name > Environment variables**, set
`AWS_ROLE_ARN` to the IAM role ARN that the job should assume through GitHub OIDC.
Configure it for both the plan and execution environments you use. The role's
OIDC trust policy must allow the corresponding GitHub environment.
The workflow reads Actions **variables**, not secrets, for this value.

`AWS_REGION` is optional and defaults to `us-east-1`, matching the Terraform
defaults. Set it to override the deployment region. `TF_VARS_JSON` is an optional
JSON object containing Terraform input overrides and defaults to `{}`.
Repository Actions variables can supply shared values; environment variables
can supply environment-specific values. Automatic push/PR plans target dev only.
Each selected plan and execution job needs an available `AWS_ROLE_ARN`.

## Sequential GitHub Actions approvals

Manual runs always start at dev. The environment input selects the last stage:
`prod` runs dev, test, pre, prod in that order; `test` runs dev, test.
Select one action for the entire run: plan, apply, or destroy. For apply/destroy,
enter `apply-through-prod` or `destroy-through-prod` (replace prod with the chosen
last environment) as confirmation. Select `feature_devops` in the **Use workflow
from** branch dropdown. Manual operations are restricted to that branch.
Keep a workflow with `workflow_dispatch` on the default branch so GitHub displays
the Run workflow button. If environment deployment branch restrictions are
configured, they must also allow `feature_devops`.

For apply/destroy, each stage creates a plan, waits for execution approval, and
applies that exact saved plan. Only successful execution unlocks the next stage.
Destroy follows the same dev-first order. Plan-only runs advance after a
successful plan without an execution job. Failures or rejected approvals stop
later stages. Execution downloads the artifact ID returned by its plan job, so
an execution-only retry uses the original saved plan even when the run attempt
number changes. Saved plans expire after one day; start a fresh run if approval
takes longer or Terraform reports a stale plan.

Use one deployment approval per environment, after its plan succeeds:

- In Settings > Environments, disable **Required reviewers** on `dev-plan`,
  `test-plan`, `pre-plan`, and `prod-plan`, then save the protection rules.
- Keep **Required reviewers** enabled on `dev`, `test`, `pre`, and `prod`.
  Add yourself and leave **Prevent self-review** unchecked for self-approval.

Dev plans automatically, then waits for approval to apply/destroy. After dev
finishes, test plans automatically and waits for its own deployment approval;
pre and prod follow the same sequence. Plan-only runs need no deployment approval.
GitHub displays **Review deployments > Approve and deploy** when a stage is
waiting. Reject to stop the run. These approval rules must be configured in
GitHub; declaring an environment in YAML alone does not pause a job. Required
reviewer availability depends on repository visibility and your GitHub plan.

Approved PR commands use the same sequence: `test //apply` runs dev then test;
`prod //destroy` plans and destroys each environment from dev through prod, with
the configured approval gates. The current PR commit must remain approved.
Push and pull-request events perform static checks and dev planning only.

## Shared remote state

Committed backend.tf files enable S3 locking and separate environment keys.
The bucket `bucket-backend-terraform-313932316713-us-east-1` and region `us-east-1`
are configured in each backend. For state migration, see the
[backend bootstrap guide](../bootstrap/backend/README.md). Terraform >= 1.10 is required.
