#!/usr/bin/env bash
set -euo pipefail
for key in TARGET TF_VAR_bucket_name TF_VAR_aws_region STATE_BUCKET STATE_REGION ROLE_ARN; do
  [[ -n "${!key:-}" ]] || { echo "Missing GitHub environment variable: $key"; exit 1; }
done
[[ "$TARGET" =~ ^(dev|test|pre|prod)$ ]] || exit 1
# Generated only on the runner; existing local environment roots stay unchanged.
if [[ -e backend.tf ]]; then
  echo 'An existing backend.tf conflicts with the workflow-generated backend. Configure one backend only.'
  exit 1
fi
printf 'terraform {\n  backend "s3" {}\n}\n' > backend.generated.tf
jq -nr --arg bucket "$STATE_BUCKET" --arg region "$STATE_REGION" --arg key "aws-devops/$TARGET/terraform.tfstate" \
  '"bucket = \($bucket | tojson)\nregion = \($region | tojson)\nkey = \($key | tojson)\nencrypt = true\nuse_lockfile = true"' > backend.generated.hcl
# Never evaluate user-supplied variable text as shell code.
printf '%s' "$TF_VARS_JSON" | jq -e 'if type == "object" then . else error("TF_VARS_JSON must be an object") end' > ci.auto.tfvars.json
