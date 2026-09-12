# Reusable AWS infrastructure

For independent dev, test, pre-production and production deployments, use the
[environment roots](../environments/README.md).

Five independent modules are under `modules/`. Each contains `main.tf`,
`variables.tf`, `outputs.tf`, and `versions.tf`. The complete deployment in
`examples/complete/` wires them together. Terraform >= 1.5 and AWS provider 5.x
are required, matching the provider major version used by the existing project.

The existing root S3 configuration and state are unchanged. Run commands from
`examples/complete`, which has separate state. Do not use the existing root
bucket name in this example or copy the root state into it.

| Module | Creates | Main required inputs | Useful outputs |
| --- | --- | --- | --- |
| `s3` | Private bucket, versioning, encryption, ownership controls, TLS-only policy | `bucket_name` | `bucket_id`, `bucket_arn` |
| `vpc` | VPC, public/private subnet pairs, internet gateway, routes, optional NAT gateways, S3 gateway endpoint | `name`, `cidr_block`, `subnets` | `vpc_id`, subnet and route table maps |
| `security-group` | Security group with named ingress/egress rules | `name`, `vpc_id` | `security_group_id` |
| `ec2` | Standalone instance with encrypted gp3 storage and IMDSv2 | `name`, `ami_id`, `subnet_id`, `security_group_ids` | `instance_id`, `private_ip` |
| `autoscaling` | Launch template, group, rolling refresh, CPU target tracking | `name`, `ami_id`, `subnet_ids`, `security_group_ids` | `autoscaling_group_name`, `launch_template_id` |

## Run the complete example

Install Terraform and configure AWS credentials using the normal AWS credential
chain (for example, an AWS CLI profile). No credentials are stored in these files.
The caller needs permissions to manage the resources and read AZs and the public
SSM AMI parameter; passing an instance profile also requires `iam:PassRole`.

```powershell
cd examples/complete
Copy-Item terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and replace bucket_name with a unique name.
$env:AWS_PROFILE = "default"
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=deployment.tfplan
terraform apply deployment.tfplan
```

This creates one standalone EC2 instance plus initially one Auto Scaling instance
in two private subnets across two AZs. Compute has no public IP or inbound access;
outbound HTTPS is allowed. S3 is reachable through the gateway endpoint, subject
to IAM permissions. An endpoint does not grant bucket access by itself.

NAT is off by default: private instances cannot reach the general internet,
public SSM endpoints, or package repositories. To use Session Manager, supply an
existing SSM-enabled instance profile and enable NAT, or separately provision
the necessary SSM interface endpoints. The example does not create IAM roles,
SSH access, load balancers, application software, DNS zones, VPNs, IPv6, or
custom network ACLs. It uses the VPC's default network ACL and security groups
for filtering. Public subnets have internet routes but do not auto-assign IPs.

Set `enable_nat_gateway = true` for outbound internet. The default creates one
NAT per AZ; `single_nat_gateway = true` shares one gateway, which reduces
redundancy and can incur cross-AZ traffic charges. Instances, disks, NAT, and
detailed monitoring may incur charges. No infrastructure is deployed merely by
creating these configuration files.

## Reuse a module

```hcl
module "logs" {
  source      = "../../modules/s3" # Adjust relative to your caller.
  bucket_name = "your-globally-unique-logs-bucket"
  tags        = { Environment = "dev" }
}
```

Configure the AWS provider in the calling root module. Child modules inherit it.
See each module's `variables.tf` for input descriptions and defaults. Security
group rule maps default to empty (no ingress or egress); use stable rule names
and exactly one `cidr_ipv4` or `source_security_group_id` in each rule. For TCP
or UDP provide both ports; protocol `-1` must omit ports. For ICMP, ports represent
type and code. Do not mix these standalone rule resources with inline rules.

VPC subnet map keys are stable resource identities. Supply non-overlapping IPv4
CIDRs inside the VPC and valid AZs in the selected region. The complete example
requires at least two available AZs.

Auto Scaling manages desired capacity after initial creation: Terraform ignores
subsequent changes to `capacity.desired` to avoid undoing scaling decisions.
Min/max remain managed. Launch template changes trigger rolling refreshes with
temporary extra capacity. Existing target groups can be attached through
`target_group_arns`; set `health_check_type = "ELB"` when using them.

Use an AMI matching the instance architecture. The example defaults to the latest
Amazon Linux 2023 x86_64 AMI; pin `ami_id` for controlled updates. The launch
template defaults to `/dev/xvda`, suitable for that AMI; set `root_device_name`
for AMIs with a different root device. The standalone and Auto Scaling
modules accept plain-text `user_data` and optional existing IAM instance profiles
and key pairs. SSH also requires an explicit ingress rule and network path.

S3 defaults to AES256 encryption; supply `kms_key_arn` for an existing customer
managed KMS key with suitable permissions. Nonempty bucket deletion is refused
by default. Empty all object versions before teardown, or explicitly opt into
`force_destroy` in the module call only when deletion is intended.

```powershell
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

State is local by default. For collaboration, configure an existing remote backend
with access controls and locking before deployment; the bucket this example
creates cannot bootstrap its own backend. Commit generated provider lock files;
state, working directories, plans, and private variable files are ignored.

Provider references: [launch templates](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template)
and [security group rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule).
