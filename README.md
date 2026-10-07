# Cloud Certainty Secure Browser – Terraform module

Deploy [Cloud Certainty Secure Browser](https://cloudcertainty.com/secure-browser/) into your own AWS account with Terraform or OpenTofu.

**Links:** [Product page](https://cloudcertainty.com/secure-browser/) · [Documentation](https://cloudcertainty.com/secure-browser/docs/)

Cloud Certainty Secure Browser is zero-trust remote browser isolation that runs entirely in your account:
- Each user session is an ephemeral Chromium container with no inbound network access.
- The session is streamed to the user's browser over encrypted WebRTC.
- Admins control clipboard, file transfer, printing, URL access, timeouts and IP allowlists for each user or group.

This module deploys the product's official CloudFormation template as a single `aws_cloudformation_stack`. The template is the same one you would launch from AWS Marketplace, at the release you pin with `product_version`. The module adds plan-time validation and Terraform-friendly inputs and outputs.

**Any Region.** Deploy in any AWS Region that has Kinesis Video Streams WebRTC, Amplify Hosting, Amazon Cognito and ECS Fargate: just configure the AWS provider for that Region. The template is always read from the vendor's public bucket in us-east-1 (`https://cloudcertainty-secure-browser-us-east-1.s3.us-east-1.amazonaws.com/<product_version>/main.yaml`), which CloudFormation accepts for a stack in any Region.

**How the code gets into your account.** All Lambda and web code ships inside the subscription-protected AWS Marketplace container image; nothing executable is publicly downloadable. When the stack is created, and on every upgrade, it runs a one-off Fargate *installer* task from that image in your `task_subnet_ids` (about a minute, billed like one session-minute). The task checks your Marketplace subscription and copies the code into a private, encrypted S3 bucket in your account (stack output `ArtifactsBucketName`), from which the Lambda functions and the portal are deployed. The bucket is emptied and deleted with the stack.

## Prerequisites

1. **Subscribe on AWS Marketplace.** Subscribe to *Cloud Certainty Secure Browser* in the AWS account you deploy to. The subscription is what allows the account to pull the image (which also carries the product code), and it bills you per session-hour. Without it, the stack fails at the installer step (`ArtifactInstall`, exit code 3) and rolls back.
2. **A VPC with subnets that have outbound internet access.** Use private subnets with a NAT gateway (recommended), or public subnets with `task_subnets_are_public = true`. Browser tasks never accept inbound connections. The installer task uses the same subnets and needs outbound HTTPS to ECR (us-east-1, the Marketplace registry), AWS Marketplace Metering, S3 and CloudWatch Logs.
3. **Permissions.** The identity running Terraform needs permission to create the stack's resources, including named IAM roles and an S3 bucket. Alternatively, pass a CloudFormation service role in `cloudformation_role_arn`. With `kms_key_arn`, that identity also needs `kms:Decrypt` on the key, because Lambda reads the function code from the encrypted bucket with the deploying identity's permissions.
4. **Versions.** Terraform >= 1.5 (or OpenTofu) and the AWS provider v6.

## Usage

```hcl
module "secure_browser" {
  source  = "cloudcertainty/secure-browser/aws"
  version = "~> 0.1"

  name_prefix           = "acme"
  vpc_id                = "vpc-0123456789abcdef0"
  task_subnet_ids       = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]
  identity_provider     = "IAMIdentityCenter"
  bootstrap_admin_email = "it-admin@acme.com"

  tags = {
    Owner       = "it-security"
    CostCenter  = "1234"
    Environment = "prod"
  }
}

output "portal_url" {
  value = module.secure_browser.portal_url
}
```

Open `portal_url`, sign in, and start a session. The admin console is at `<portal_url>/admin`.

### Signing in with AWS IAM Identity Center

AWS doesn't let IAM Identity Center custom SAML applications be created as code, so this takes two applies:

1. `terraform apply` with `saml_metadata_url` left empty.
2. In IAM Identity Center, choose **Applications → Add application → Add custom SAML 2.0 application**:
   - **Application ACS URL:** the `saml_acs_url` output.
   - **Application SAML audience:** the `saml_audience_uri` output.
   - **Attribute mappings:** `Subject` → `${user:email}` (format `emailAddress`), and `email` → `${user:email}`.
   - Assign users or groups, then copy the **IAM Identity Center SAML metadata file** URL.
3. Set `saml_metadata_url` to that URL and run `terraform apply` again.

Use the same steps for any SAML 2.0 identity provider with `identity_provider = "SAML"`.

### Signing in with OIDC (Entra ID, Okta, Google Workspace, …)

Create the client secret in Secrets Manager **outside Terraform**, so it never appears in Terraform state. Then pass its ARN:

```hcl
data "aws_secretsmanager_secret" "oidc" {
  name = "secure-browser/oidc-client-secret"
}

module "secure_browser" {
  source = "cloudcertainty/secure-browser/aws"
  # ...
  identity_provider      = "OIDC"
  oidc_issuer            = "https://login.microsoftonline.com/<tenant-id>/v2.0"
  oidc_client_id         = "<application-client-id>"
  oidc_client_secret_arn = data.aws_secretsmanager_secret.oidc.arn
}
```

Register `https://<cognito_domain output>/oauth2/idpresponse` as the redirect URI in your identity provider. CloudFormation reads the secret at deploy time, so the identity running Terraform needs `secretsmanager:GetSecretValue` on it.

### Evaluating without an identity provider

`identity_provider = "CognitoOnly"` creates users in a Cognito user pool. The bootstrap admin receives an invitation email. See [examples/cognito-only](examples/cognito-only).

## Examples

- [IAM Identity Center](examples/iam-identity-center)
- [OIDC](examples/oidc)
- [Cognito only](examples/cognito-only)

## Inputs and outputs

Generated from the module's variables and outputs with [terraform-docs](https://terraform-docs.io)
(`terraform-docs .`); CI fails if this section is out of date.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bootstrap_admin_email"></a> [bootstrap\_admin\_email](#input\_bootstrap\_admin\_email) | Email of the first administrator. This user is always an admin and can grant admin rights to others in the admin console. | `string` | n/a | yes |
| <a name="input_task_subnet_ids"></a> [task\_subnet\_ids](#input\_task\_subnet\_ids) | Subnets for the browser tasks and the one-off artifact installer task (two or more, in different Availability Zones, recommended). They need outbound internet access: private subnets through a NAT gateway (recommended), or public subnets with task\_subnets\_are\_public = true. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC the browser sessions run in. Sessions can reach private applications in this VPC. | `string` | n/a | yes |
| <a name="input_allowed_cidrs"></a> [allowed\_cidrs](#input\_allowed\_cidrs) | Initial IP allowlist for the portal and API (empty allows all). Used until an admin saves settings in the admin console. | `list(string)` | `[]` | no |
| <a name="input_artifact_version_override"></a> [artifact\_version\_override](#input\_artifact\_version\_override) | Override the application code version installed from the image (passed as the template's ArtifactVersionOverride). Leave null: the release is built into the product\_version template. Set only when Cloud Certainty support asks you to, normally together with image\_uri. | `string` | `null` | no |
| <a name="input_browser_task_size"></a> [browser\_task\_size](#input\_browser\_task\_size) | CPU and memory of each browser session: 1vCPU-2GB, 2vCPU-4GB or 4vCPU-8GB. | `string` | `"2vCPU-4GB"` | no |
| <a name="input_cloudformation_role_arn"></a> [cloudformation\_role\_arn](#input\_cloudformation\_role\_arn) | Optional IAM role CloudFormation assumes to create the stack (service role). Without it, CloudFormation uses the credentials Terraform runs with. | `string` | `null` | no |
| <a name="input_cpu_architecture"></a> [cpu\_architecture](#input\_cpu\_architecture) | CPU architecture of the browser tasks. This release supports X86\_64; ARM64 (Graviton) returns in a later release. | `string` | `"X86_64"` | no |
| <a name="input_identity_provider"></a> [identity\_provider](#input\_identity\_provider) | How users sign in: IAMIdentityCenter, SAML, OIDC or CognitoOnly. | `string` | `"IAMIdentityCenter"` | no |
| <a name="input_image_uri"></a> [image\_uri](#input\_image\_uri) | Override the browser container image (passed as the template's ImageUriOverride). Leave null to use the image pinned by digest in the product\_version template. Set only when Cloud Certainty support asks you to; only digest-pinned images from the AWS Marketplace registry are accepted. | `string` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Optional customer managed KMS key for DynamoDB, CloudWatch Logs, the update SNS topic and the stack's private artifacts bucket. The key policy must allow CloudWatch Logs and SNS to use it, and the identity running Terraform (or cloudformation\_role\_arn) needs kms:Decrypt on it. | `string` | `""` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch Logs retention for session, API and audit logs. | `number` | `90` | no |
| <a name="input_max_concurrent_sessions"></a> [max\_concurrent\_sessions](#input\_max\_concurrent\_sessions) | Default limit on concurrent sessions across all users. Admins can change it later in the admin console. | `number` | `10` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for every resource the stack creates (lowercase letters, digits and hyphens; 2-20 characters, starting with a letter). | `string` | `"ztb"` | no |
| <a name="input_oidc_client_id"></a> [oidc\_client\_id](#input\_oidc\_client\_id) | OIDC client ID (identity\_provider = OIDC only). | `string` | `""` | no |
| <a name="input_oidc_client_secret_arn"></a> [oidc\_client\_secret\_arn](#input\_oidc\_client\_secret\_arn) | ARN of a Secrets Manager secret whose SecretString is the OIDC client secret (identity\_provider = OIDC only). CloudFormation resolves it at deploy time, so the secret is never stored in Terraform state. | `string` | `""` | no |
| <a name="input_oidc_email_verified_claim"></a> [oidc\_email\_verified\_claim](#input\_oidc\_email\_verified\_claim) | OIDC claim that says whether the IdP verified the user's email (identity\_provider = OIDC only). Users whose email is not verified are refused. Keep email\_verified for Okta, Google, Auth0 and most IdPs; use xms\_edov for Microsoft Entra ID. | `string` | `"email_verified"` | no |
| <a name="input_oidc_issuer"></a> [oidc\_issuer](#input\_oidc\_issuer) | OIDC issuer URL (identity\_provider = OIDC only). | `string` | `""` | no |
| <a name="input_product_version"></a> [product\_version](#input\_product\_version) | Release of Cloud Certainty Secure Browser to deploy. Selects the release's CloudFormation template, which pins the matching application artifacts and container image. Each module release defaults to the product release it was tested with, so upgrading usually means raising the module version. | `string` | `"0.1.6"` | no |
| <a name="input_saml_metadata_url"></a> [saml\_metadata\_url](#input\_saml\_metadata\_url) | SAML metadata URL of your IAM Identity Center application or SAML IdP. Leave empty for the first apply, create the SAML application from the saml\_acs\_url and saml\_audience\_uri outputs, then set this and apply again. | `string` | `""` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | Name of the CloudFormation stack. Defaults to "<name\_prefix>-secure-browser". | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the stack and propagated to its resources. The Owner, CostCenter and Environment keys are also passed to the template's explicit tag parameters (TagOwner, TagCostCenter, TagEnvironment). | `map(string)` | `{}` | no |
| <a name="input_task_subnets_are_public"></a> [task\_subnets\_are\_public](#input\_task\_subnets\_are\_public) | Set to true only if task\_subnet\_ids are public subnets. Tasks then get a public IP for outbound traffic; their security group still allows no inbound traffic. | `bool` | `false` | no |
| <a name="input_template_url"></a> [template\_url](#input\_template\_url) | Override the S3 URL of the CloudFormation template. By default it is https://cloudcertainty-secure-browser-us-east-1.s3.us-east-1.amazonaws.com/<product\_version>/main.yaml, whatever Region you deploy to. | `string` | `null` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | How long Terraform waits for the stack to create, update or delete. | `string` | `"60m"` | no |
| <a name="input_update_checks"></a> [update\_checks](#input\_update\_checks) | Check once a day for a new release (downloads the vendor's public release manifest; nothing about you or your account is sent). New releases are shown in the admin console and announced on the update SNS topic (update\_topic\_arn). | `bool` | `true` | no |
| <a name="input_update_notification_email"></a> [update\_notification\_email](#input\_update\_notification\_email) | Optional email address subscribed to the update SNS topic. AWS sends a confirmation email that must be accepted first. Empty for none. | `string` | `""` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_url"></a> [api\_url](#output\_api\_url) | Base URL of the HTTP API. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | ECS cluster that runs the browser sessions. |
| <a name="output_cognito_domain"></a> [cognito\_domain](#output\_cognito\_domain) | Cognito managed login domain. For OIDC, register https://<this domain>/oauth2/idpresponse as the redirect URI. |
| <a name="output_portal_url"></a> [portal\_url](#output\_portal\_url) | URL of the user portal and admin console. |
| <a name="output_product_version"></a> [product\_version](#output\_product\_version) | Cloud Certainty Secure Browser release the stack runs (stack output ProductVersion). |
| <a name="output_saml_acs_url"></a> [saml\_acs\_url](#output\_saml\_acs\_url) | Assertion Consumer Service (ACS) URL to enter in your IAM Identity Center or SAML application. |
| <a name="output_saml_audience_uri"></a> [saml\_audience\_uri](#output\_saml\_audience\_uri) | SAML audience (entity ID) to enter in your IAM Identity Center or SAML application. |
| <a name="output_stack_id"></a> [stack\_id](#output\_stack\_id) | ID of the CloudFormation stack. |
| <a name="output_stack_outputs"></a> [stack\_outputs](#output\_stack\_outputs) | All outputs of the CloudFormation stack. |
| <a name="output_table_name"></a> [table\_name](#output\_table\_name) | DynamoDB table holding settings, sessions and the audit log (kept when the stack is deleted). |
| <a name="output_task_security_group_id"></a> [task\_security\_group\_id](#output\_task\_security\_group\_id) | Security group of the browser tasks (no inbound rules). Allow it as a source on private applications the sessions should reach. |
| <a name="output_update_topic_arn"></a> [update\_topic\_arn](#output\_update\_topic\_arn) | SNS topic that announces new releases. Subscribe email, AWS Chatbot (Slack, Microsoft Teams) or other endpoints to it. |
| <a name="output_user_pool_client_id"></a> [user\_pool\_client\_id](#output\_user\_pool\_client\_id) | Cognito app client ID used by the portal. |
| <a name="output_user_pool_id"></a> [user\_pool\_id](#output\_user\_pool\_id) | Cognito user pool ID. |
<!-- END_TF_DOCS -->

## Staying up to date

Each module version `X.Y.Z` deploys Cloud Certainty Secure Browser release `X.Y.Z` by default. A release is one CloudFormation template that pins the container image by digest, and that image carries the release's Lambda code and web portal, so nothing changes until you upgrade. You can hear about new releases in several ways:

- **Admin console banner.** With `update_checks = true` (the default), the stack checks the vendor's public release manifest once a day. Administrators see a banner when a newer release exists, marked **Security** for security releases. The check sends nothing about you: it is an HTTPS GET of a static file, with only the installed version in the `User-Agent`. Set `update_checks = false` to turn it off.
- **Email.** Set `update_notification_email = "secops@example.com"`. AWS SNS sends a confirmation email first; nothing is delivered until it is confirmed. Each release is announced once, with upgrade steps.
- **Slack or Microsoft Teams.** Subscribe AWS Chatbot (Amazon Q Developer in chat applications) to the `update_topic_arn` output: in the AWS Chatbot console, configure your workspace or team, create a channel configuration and add the topic under **Notifications**. Any other SNS subscriber works too, for example:
  ```hcl
  resource "aws_sns_topic_subscription" "updates_to_queue" {
    topic_arn = module.secure_browser.update_topic_arn
    protocol  = "sqs"
    endpoint  = aws_sqs_queue.platform_notices.arn
  }
  ```
- **GitHub Releases.** Watch this repository (**Watch → Custom → Releases**). Each module release links the product release notes.
- **Dependabot.** Let Dependabot open a pull request for every new module version. Add `.github/dependabot.yml` to the repository that holds your Terraform:
  ```yaml
  version: 2
  updates:
    - package-ecosystem: terraform
      directory: "/" # the directory with the module block; add one entry per directory
      schedule:
        interval: weekly
      labels: ["dependencies", "secure-browser"]
  ```
- **Renovate.** Renovate's `terraform` manager detects registry modules out of the box; with an exact `version = "X.Y.Z"` it opens a pull request per release (group or schedule it with a `packageRules` entry matching `cloudcertainty/secure-browser/aws`).

For the bots to propose every release, pin an exact version (`version = "0.2.0"`) or a range they can raise (`version = "~> 0.2.0"`).

## Upgrading

1. Raise the module version (or merge the Dependabot/Renovate pull request). That also raises `product_version`, which selects the new release's template. Don't set `product_version` yourself unless you want to stay on, or move to, a specific release.
2. `terraform init -upgrade` and `terraform plan`: the plan changes the stack's `template_url`. Upgrading from a module version before update notifications also removes the old `ArtifactVersion` and `ImageUri` parameters from the stack; that is expected.
3. `terraform apply`. CloudFormation updates the stack in place: it first re-runs the installer task from the new image (about a minute), then updates the Lambda functions, the portal and the task definition. If the installer fails, the update rolls back before anything else changes. Running sessions keep running on their current version until they end; new sessions use the new release.

Read the product release notes first: a MAJOR release lists any action it needs.

### Rolling back

Set the module version (or `product_version`) back to the previous release and apply. Every release reads the data of the release before and after it, so going back **one** release is safe. If an apply fails, CloudFormation rolls the stack back to where it was on its own.

### Support policy

The latest release and the one before it are supported. Security fixes ship only in a new latest release, so upgrade promptly when a release is marked **Security**.

## Removing

`terraform destroy` deletes the stack. The private artifacts bucket is emptied and deleted with it. The DynamoDB table holding settings and the audit log is **retained** by design. Delete it manually if you no longer need it (its name is in the `table_name` output).

## Security notes

- Nothing sensitive is passed through Terraform. The OIDC client secret is referenced by ARN, and no other input is secret.
- Browser tasks have no public IP (unless you use public subnets) and no inbound security-group rules.
- No product code is publicly downloadable: it ships only inside the Marketplace image, and the stack's copy lives in a private bucket (public access blocked, encrypted, TLS only) in your account.
- See the product's security documentation for the full list of controls.

## License

The code in this repository is licensed under [Apache 2.0](LICENSE). Cloud Certainty Secure Browser itself is licensed under the Standard Contract for AWS Marketplace when you subscribe.
