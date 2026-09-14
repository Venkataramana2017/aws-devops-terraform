# One-time Terraform state bucket

This independent bootstrap root creates a dedicated state bucket in `us-east-1`
by default, named `bucket-backend-terraform-313932316713-us-east-1`.
The bucket has versioning, AES256 encryption, public access blocking,
bucket-owner-enforced ownership, and a TLS-only policy. `prevent_destroy` and
`force_destroy = false` protect it from accidental Terraform deletion.

It uses local state intentionally, so it can create the backend before any
environment depends on it. Keep an access-controlled backup of this bootstrap
state. Do not run this bootstrap from a disposable CI runner with fresh local
state on every run, and do not remove its state after creating the bucket.

## Create once

Authenticate to AWS locally first (for example your existing SSO profile).
From the repository root:

```powershell
$env:AWS_PROFILE = "your-profile"
aws sts get-caller-identity
terraform -chdir=bootstrap/backend init
terraform -chdir=bootstrap/backend plan -out=bootstrap.tfplan
terraform -chdir=bootstrap/backend apply bootstrap.tfplan
```

Review the account returned by STS. To override the bucket name or region, pass
`-var='bucket_name=your-unique-state-bucket'` or `-var='aws_region=us-east-1'`
to the plan command. If the computed bucket name already exists, investigate
ownership and state before choosing a new name or importing it; do not blindly
re-create or take over a bucket.

## Initialize environment backends

Terraform >= 1.10 is required for native S3 locking. Each environment now has a
committed `backend.tf` with the shared bucket, region, and its own key. From the repository root:

```powershell
$stateBucket = terraform -chdir=bootstrap/backend output -raw bucket_name
$stateRegion = terraform -chdir=bootstrap/backend output -raw region
foreach ($target in @('dev', 'test', 'pre', 'prod')) {
  terraform "-chdir=environments/$target" init -migrate-state "-backend-config=bucket=$stateBucket" "-backend-config=region=$stateRegion"
  if ($LASTEXITCODE -ne 0) { throw "Backend initialization failed for $target" }
}
```

For existing local environment state, review the migration prompt and retain
its backup. New empty environments initialize without uploading resources.
The original repository-root S3 state is separate and is not migrated by these
commands. Do not copy that state into an environment key.

The workflow configures the same bucket and region directly; GitHub
`TF_STATE_BUCKET` and `TF_STATE_REGION` variables are not used. It uses the same
committed backend blocks and keys as local Terraform. AWS roles need backend
bucket listing, state object read/write, and lock object read/write/delete
permissions. Environment deployments do not own or destroy this bucket.

Reference: [HashiCorp S3 backend and lock permissions](https://developer.hashicorp.com/terraform/language/backend/s3).
