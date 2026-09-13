# Checkov scan exceptions — Phase 1

Findings from the `terraform-plan` Checkov scan that are deliberately not
fixed, and why. Anything not listed here that Checkov flags should be
treated as a real gap, not assumed to be an accepted exception.

## Not applicable to this design (fixing would make it worse, not better)

- **CKV_AWS_116 — Lambda DLQ.** `get-products` is invoked synchronously by
  API Gateway; there is no async failure mode for a DLQ to catch. The
  `order_consumer` Lambda (SQS-triggered, Phase 1 orders path) does have a
  DLQ — that's the correct place for this control.
- **CKV_AWS_117 — Lambda in a VPC.** DynamoDB is reached over the public
  AWS API, not inside a VPC. Placing this Lambda in a VPC would add
  cold-start latency and NAT Gateway cost for no security benefit.
- **CKV_AWS_309 — API Gateway route authorization.** `GET /products` is an
  intentionally public product catalog endpoint. `NONE` is correct here.
  Order-write endpoints (`POST /orders`, Phase 2+) will require an
  authorizer once Cognito is in place.

## Accepted for Phase 1, revisit later

- **CKV_AWS_272 — Lambda code signing.** Requires a Signing Profile and
  signing pipeline step; disproportionate setup cost for a single
  read-only Lambda. Revisit if this becomes a multi-team or
  supply-chain-sensitive deployment.
- **CKV_AWS_173 — Lambda env var encryption with a CMK.** Lambda
  environment variables are encrypted at rest with an AWS-managed key by
  default. A customer-managed CMK is stronger but adds key-management
  overhead not justified by `TABLE_NAME` (non-secret) as the only value
  stored.
- **CKV_AWS_119 — DynamoDB encryption with a CMK.** Same reasoning —
  AWS-owned encryption is enabled by default; no sensitive data justifies
  the added CMK management overhead yet. Revisit before storing payment
  or PII data (Phase 3).
- **CKV_AWS_158 — CloudWatch Log Group encryption with a CMK.** Applies to
  `api_access` (API Gateway access logs). Logged fields are request IDs,
  route keys, status, latency — no payload bodies, no PII. Same CMK
  deferral reasoning as above; revisit if request/response bodies are
  ever logged.

## Fixed, not exempted

- **CKV_AWS_364 — Lambda permission SourceArn.** Fixed — scoped to this
  API's execution ARN.
- **CKV_AWS_50 — X-Ray tracing.** Fixed — `tracing_config { mode =
  "Active" }`.
- **CKV_AWS_115 — Reserved concurrency.** Fixed — capped at 5.
- **CKV_AWS_76 — API Gateway access logging.** Fixed — dedicated log
  group, 14-day retention.
- **CKV_AWS_338 — Log group retention < 1 year.** Fixed — `api_access`
  retention set to 365 days.
