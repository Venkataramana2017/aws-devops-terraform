# Terraform in GitHub Actions

Every push to a branch other than `main` triggers validation and plans for all four environments,
including `dev*`, `feature*`, and branch names containing `/`. Pushes have
no file-path filter; documentation-only commits trigger the workflow too. Tag
pushes are excluded. The workflow file must be present on the pushed branch.
Plans require the configured AWS roles, backend, and plan-environment approvals.
Pushes never apply or destroy resources.

Same-repository PRs also plan all four environments and receive result comments.
A push to a branch with an open matching PR can trigger both push and PR runs.
Push runs report results in Actions; PR runs post the PR comments. Fork PRs receive formatting
and validation only, without AWS credentials.

After the current PR commit is approved, a collaborator with repository write
access can post an environment followed by `//plan`, `//apply`, or `//destroy`
in the PR conversation. An explicit environment is required on every command:
`dev`, `test`, `pre`, or `prod`. For example, post `dev //plan`, `test //apply`,
or `prod //destroy`. Environment and command can be on separate lines in the
same comment. Separate comments do not share an environment selection.
Commands are case-insensitive and each comment must contain only one command.
The PR must be open, non-draft, and from this repository. Approval must come from
another collaborator with write access for the current head commit, with no
outstanding changes requested. Approval and the head SHA are checked again when
jobs start, including after deployment approval waits. New commits require new approval.

Comment runs check out the approved PR head commit. `//apply` creates a fresh plan;
`//destroy` creates a fresh destroy plan. Both execute that run's saved plan after
configured environment approval. `//plan` never executes changes. Only the selected
environment is planned or changed by a comment command. Results are posted
back to the PR. The workflow must first be merged into the default branch for
GitHub to deliver `issue_comment` events.

## One-time configuration

1. Push these files and merge the workflow onto the default branch.
2. Use `bootstrap/backend` to provision the one-time S3 backend bucket with versioning, encryption, and
   appropriate state/lock access permissions. Environment deployments do not create
   application buckets; the backend bucket is managed separately.
3. Configure AWS OIDC trust for this repository. Use separate plan and deployment
   roles; planning requires resource read permissions and backend state/lock
   access, while deployment requires resource management and any needed
   `iam:PassRole`. Avoid administrator access.
4. Create eight GitHub environments: `dev-plan`, `test-plan`, `pre-plan`,
   `prod-plan`, and `dev`, `test`, `pre`, `prod`.
5. Enable **required reviewers** and prevent self-review for the deployment
   environments. Limit deployment environments to the default branch. Also
   protect the plan environments with review: inspect PR code before allowing it
   to receive AWS credentials. Terraform configuration can execute code during
   a plan. GitHub environment protection availability depends on your repository
   and GitHub plan. YAML alone cannot configure or guarantee reviewer approval.
6. Add these environment-level **variables** in each environment:

| Variable | Value |
| --- | --- |
| `AWS_ROLE_ARN` | Plan role in `*-plan`; deployment role in the corresponding deployment environment |
| `AWS_REGION` | Resource region, for example `us-east-1` |
| `TF_VARS_JSON` | Optional JSON object overriding Terraform inputs, e.g. `{"enable_nat_gateway":true,"ami_id":"ami-..."}` |

Keep region, backend bucket and input variables identical
between each plan/deployment pair. Only their IAM role should differ.
State keys are `aws-devops/dev/terraform.tfstate`, `aws-devops/test/terraform.tfstate`,
`aws-devops/pre/terraform.tfstate`, and `aws-devops/prod/terraform.tfstate`.
The workflow and committed backend blocks use `bucket-backend-terraform-313932316713-us-east-1`
in `us-east-1`. GitHub `TF_STATE_BUCKET` and `TF_STATE_REGION` variables are no longer used.
Initialize local environment roots with the same bucket and region used by CI. If you already applied
locally, migrate that state into the matching backend before running CI, using
the instructions in `environments/README.md`. Never apply the same environment
against both local and remote state.

The AWS OIDC trust subject for each role must name its exact GitHub environment,
for example `repo:OWNER/REPOSITORY:environment:dev-plan` or
`repo:OWNER/REPOSITORY:environment:dev`, with audience `sts.amazonaws.com`.
Restrict who can change workflows and who can approve deployments.

## Plan, apply, or destroy

In **Actions â†’ Terraform â†’ Run workflow**:

1. Select the default branch and `dev`, `test`, `pre`, or `prod`.
2. Select `plan`, `apply`, or `destroy`.
3. For changes, type the exact confirmation, e.g. `apply-dev` or `destroy-prod`.
4. Optionally enter a PR number to receive plan and execution comments.
5. Run the workflow. Review the plan output, then approve the deployment job
   when GitHub prompts a configured required reviewer.

Apply/destroy execute the **saved plan** from that same run and commit after the
deployment approval. Destroy first generates a destroy plan. PR plans are for
review and are not reused for deployment. Comment commands deploy the approved
PR commit without requiring a merge. A manual
run deploys the selected default-branch commit, not the optional PR's branch.
If state changes during approval, the saved plan can be rejected as stale; start
a new run and review its new plan. State locking and per-environment concurrency
serialize access; no running Terraform job is automatically cancelled.

Plan artifacts expire after one day and can contain sensitive values. Access to
repository Actions artifacts and logs must be restricted appropriately. PR
comments contain counts and links, not complete plan contents. Downloaded plans
are only used within their originating workflow run. Re-run the entire workflow
if an artifact expires or an execution job needs another attempt.

Creating these files does not configure AWS trust, GitHub environment protections,
or create AWS resources. Nonempty S3 buckets refuse destruction by default.

## Refresh provider checksums

CI uses read-only provider lock files. Keep `.terraform.lock.hcl` committed in
`bootstrap/backend` and each environment, including checksums for the Linux
runner and Windows development machines. After changing provider requirements,
run these commands from the repository root and commit the updated lock files:

```bash
for root in bootstrap/backend environments/dev environments/test environments/pre environments/prod; do
  terraform -chdir="$root" init -backend=false -input=false
  terraform -chdir="$root" providers lock -platform=linux_amd64 -platform=windows_amd64
  terraform -chdir="$root" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$root" validate -no-color
done
```

These commands verify configuration without accessing the remote state or applying
resources. See [HashiCorp's provider lock documentation](https://developer.hashicorp.com/terraform/cli/commands/providers/lock).

References: [GitHub manual workflow inputs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
and [AWS OIDC configuration](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).
