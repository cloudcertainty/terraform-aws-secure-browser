# Changelog

All notable changes to this module are documented here. The module version
tracks the Cloud Certainty Secure Browser release it deploys by default.

## 0.1.6

- First release: deploys Cloud Certainty Secure Browser 0.1.6 into your AWS
  account through its CloudFormation template. The template carries its own
  release (the container image pinned by digest, which also carries the Lambda
  and web code); `product_version` selects the template.
- Works in any Region with Kinesis Video Streams WebRTC, Amplify Hosting,
  Cognito and Fargate. `template_url` defaults to the vendor's public us-east-1
  bucket (`https://cloudcertainty-secure-browser-us-east-1.s3.us-east-1.amazonaws.com/<product_version>/main.yaml`)
  whatever the deploy Region; there are no per-Region release buckets.
- The stack installs the product code from the Marketplace image into a private
  bucket in your account with a one-off installer task (about a minute, at
  create and at each upgrade), in `task_subnet_ids`.
- Every template parameter has an input. `oidc_email_verified_claim` sets the
  template's `OidcEmailVerifiedClaim` (use `xms_edov` for Microsoft Entra ID).
  The support-only overrides `image_uri` (`ImageUriOverride`, digest-pinned
  Marketplace images only) and `artifact_version_override`
  (`ArtifactVersionOverride`) are passed only when set.
- `update_checks` (default `true`): daily check for new releases, shown in the
  admin console and announced on the stack's SNS topic; `update_notification_email`
  subscribes an email address to it. Outputs `product_version` and
  `update_topic_arn`.
- Supports AWS IAM Identity Center, SAML, OIDC (client secret read from Secrets
  Manager) and Cognito-only sign-in.
- Plan-time checks mirror the template's rules: the Region must support AWS
  Marketplace metering, subnets must belong to the VPC, and the OIDC and SAML
  settings must be consistent. Input validation matches the template's allowed
  values and patterns.
