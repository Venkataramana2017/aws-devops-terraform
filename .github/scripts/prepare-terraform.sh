#!/usr/bin/env bash
set -euo pipefail
for key in TARGET TF_VAR_aws_region STATE_BUCKET STATE_REGION; do
  [[ -n "${!key:-}" ]] || { echo "Missing GitHub environment variable: $key"; exit 1; }
done
[[ "$TARGET" =~ ^(dev|test|pre|prod)$ ]] || exit 1
if [[ -z "${ROLE_ARN:-}" ]]; then
  echo 'Missing GitHub Actions variable: AWS_ROLE_ARN (mapped to ROLE_ARN).'
  echo "Set it in Settings > Environments > $TARGET-plan for plans, or $TARGET for execution."
  echo 'Alternatively, set a repository Actions variable if the same role is intended for all jobs.'
  exit 1
fi
# Backend blocks and environment state keys are checked into each environment.
[[ -f backend.tf ]] || { echo 'Missing environment backend.tf'; exit 1; }
jq -nr --arg bucket "$STATE_BUCKET" --arg region "$STATE_REGION" --arg key "aws-devops/$TARGET/terraform.tfstate" \
  '"bucket = \($bucket | tojson)\nregion = \($region | tojson)\nkey = \($key | tojson)\nencrypt = true\nuse_lockfile = true"' > backend.generated.hcl
# Never evaluate user-supplied variable text as shell code.
printf '%s' "$TF_VARS_JSON" | jq -e 'if type == "object" then . else error("TF_VARS_JSON must be an object") end' > ci.auto.tfvars.json
