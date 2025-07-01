#!/bin/bash
set -e
eval "$(jq -r '@sh "URL=\(.url)"')"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${URL#https://}"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$PROVIDER_ARN" >/dev/null 2>&1; then
  jq -n --arg arn "$PROVIDER_ARN" '{"arn": $arn}'
else
  jq -n '{"arn": ""}'
fi
