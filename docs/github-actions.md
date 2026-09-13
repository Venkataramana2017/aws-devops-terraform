# Terraform in GitHub Actions

Every push to any branch triggers validation and plans for all four environments,
including `dev*`, `feature*`, `main`, and branch names containing `/`. Pushes have
no file-path filter; documentation-only commits trigger the workflow too. Tag
pushes are excluded. The workflow file must be present on the pushed branch.
Plans require the configured AWS roles, backend, and plan-environment approvals.
Pushes never apply or destroy resources.

Same-repository PRs also plan all four environments and receive result comments.
A push to a branch with an open matching PR can trigger both push and PR runs.
Push runs report results in Actions; PR runs post the PR comments. Fork PRs receive formatting
and validation only, without AWS credentials. PR comments are results, not command
triggers; typing `apply` or `destroy` in a comment does not execute anything.

## One-time configuration

1. Push these files and merge the workflow onto the default branch.
2. Use `bootstrap/backend` to provision the one-time S3 backend bucket with versioning, encryption, and
   appropriate state/lock access permissions. Do not use the application bucket
   managed by these modules as the backend.
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
| `TF_STATE_BUCKET` | Existing backend bucket name |
| `TF_STATE_REGION` | Backend bucket region |
| `TF_BUCKET_NAME` | Globally unique application bucket name for this environment |
| `TF_VARS_JSON` | Optional JSON object overriding Terraform inputs, e.g. `{"enable_nat_gateway":true,"ami_id":"ami-..."}` |

Keep region, backend bucket, application bucket and input variables identical
between each plan/deployment pair. Only their IAM role should differ.
State keys are `aws-devops/dev/terraform.tfstate`, `aws-devops/test/terraform.tfstate`,
`aws-devops/pre/terraform.tfstate`, and `aws-devops/prod/terraform.tfstate`.
The workflow supplies bucket and region to the committed backend blocks.
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
review and are not reused for deployment; merge intended changes first. A manual
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

References: [GitHub manual workflow inputs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
and [AWS OIDC configuration](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).
