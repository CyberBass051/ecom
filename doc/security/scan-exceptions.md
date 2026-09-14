# Security scan exceptions — Phase 1

Two scanners run in CI (Checkov, and a second scanner emitting `AWS-*`
IDs — likely Trivy; confirm and note here once verified). They frequently
flag the same underlying issue under different IDs. This doc is
organized by **decision**, not by check ID — when a new ID shows up for
a standing decision already listed here, add it as a cross-reference to
the existing entry, don't write a new paragraph.

Anything not covered by a standing policy below and not listed under
"Fixed" is a real gap — treat it as such, don't assume it's accepted.

## Standing policy: no customer-managed KMS keys yet

No sensitive data (PII, payment info) exists in this system yet. A CMK
adds real key-management overhead with no corresponding risk reduction
at this stage. Revisit before Phase 3 (Stripe/payment data).

Covers: `CKV_AWS_119`/`AWS-0025` (DynamoDB), `CKV_AWS_173` (Lambda env
vars), `CKV_AWS_158`/`AWS-0017` (CloudWatch log group), `CKV_AWS_145`
(S3 default encryption).

## Standing policy: no custom domain yet

CloudFront is served on its default `*.cloudfront.net` domain for
Phase 1 — proving the architecture doesn't require DNS/ACM setup yet.
Custom-domain wiring (ACM in us-east-1, Route53 alias) is a
`recruiter-portfolio-site` / cyberbass.live-linking decision, tracked
there, not duplicated here.

Covers: `CKV_AWS_174` (TLS 1.2 minimum — tied to a custom ACM cert),
`CKV2_AWS_42` (custom SSL certificate).

## Standing policy: single-environment demo, no production traffic yet

This is a portfolio dev environment with no real user traffic, no
uptime SLA, and no multi-region requirement. Controls that exist to
protect production availability/compliance posture at scale aren't
proportionate here yet.

Covers: `CKV_AWS_310` (CloudFront origin failover — single origin per
type, no redundancy need), `CKV_AWS_374` (CloudFront geo restriction —
no business reason to block countries on a public portfolio demo),
`CKV_AWS_144` (S3 cross-region replication — single static asset, no
DR requirement), `CKV2_AWS_62` (S3 event notifications — no operational
consumer for them yet).

## Standing policy: WAF deferred

A WAFv2 Web ACL (and its Log4j-specific AWS Managed Rule) adds real
monthly cost and rule-tuning overhead, disproportionate to a low-traffic
portfolio demo. The ALB project already demonstrates WAFv2 competency
separately — this isn't a knowledge gap, it's a cost/traffic-proportionality
call for this specific project. Revisit if this ever takes real public
traffic.

Covers: `CKV_AWS_68` (CloudFront WAF), `CKV2_AWS_47` (WAF Log4j AMR).

## Not applicable to this design (fixing would make it worse, not better)

- **CKV_AWS_116 — Lambda DLQ.** `get-products` is invoked synchronously
  by API Gateway; no async failure mode for a DLQ to catch. The
  `order_consumer` Lambda (SQS-triggered) has a DLQ — that's the correct
  place for this control.
- **CKV_AWS_117 — Lambda in a VPC.** DynamoDB is reached over the public
  AWS API. VPC placement would add cold-start latency and NAT cost for
  no benefit.
- **CKV_AWS_309 — API Gateway route authorization.** `GET /products` is
  an intentionally public catalog endpoint.

## Accepted for Phase 1, revisit later

- **CKV_AWS_272 — Lambda code signing.** Disproportionate setup
  (Signing Profile + pipeline step) for a single read-only Lambda.

## Fixed, not exempted

- **CKV_AWS_364** — Lambda permission `SourceArn`, scoped to this API's
  execution ARN.
- **CKV_AWS_50** — X-Ray tracing (`Active` mode).
- **CKV_AWS_115** — Lambda reserved concurrency, capped at 5.
- **CKV_AWS_76 / CKV_AWS_86 / CKV_AWS_18** — Access logging: API Gateway
  stage, CloudFront distribution, and S3 server access logs all land in
  a dedicated `${project}-logs-*` bucket.
- **CKV_AWS_338** — Log retention ≥ 1 year (API access log group: 365
  days; CloudFront/S3 log bucket: 365-day lifecycle expiration).
- **CKV_AWS_21** — S3 versioning enabled on the site bucket.
- **CKV2_AWS_61** — Lifecycle rule expiring noncurrent versions after
  90 days (site bucket).
- **CKV2_AWS_32** — CloudFront response headers policy attached
  (HSTS, X-Frame-Options: DENY, X-Content-Type-Options, referrer
  policy, XSS protection).
