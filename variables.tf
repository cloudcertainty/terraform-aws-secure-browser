################################################################################
# General
################################################################################

variable "name_prefix" {
  description = "Prefix for every resource the stack creates (lowercase letters, digits and hyphens; 2-20 characters, starting with a letter)."
  type        = string
  default     = "ztb"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.name_prefix))
    error_message = "name_prefix must match ^[a-z][a-z0-9-]{1,19}$."
  }
}

variable "stack_name" {
  description = "Name of the CloudFormation stack. Defaults to \"<name_prefix>-secure-browser\"."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the stack and propagated to its resources. The Owner, CostCenter and Environment keys are also passed to the template's explicit tag parameters (TagOwner, TagCostCenter, TagEnvironment)."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in ["Owner", "CostCenter", "Environment"] : !contains(keys(var.tags), k) || (length(lookup(var.tags, k, "x")) >= 1 && length(lookup(var.tags, k, "x")) <= 256)])
    error_message = "The Owner, CostCenter and Environment tag values must be 1-256 characters (the template's tag parameters)."
  }
}

################################################################################
# Network
################################################################################

variable "vpc_id" {
  description = "VPC the browser sessions run in. Sessions can reach private applications in this VPC."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "task_subnet_ids" {
  description = "Subnets for the browser tasks and the one-off artifact installer task (two or more, in different Availability Zones, recommended). They need outbound internet access: private subnets through a NAT gateway (recommended), or public subnets with task_subnets_are_public = true."
  type        = list(string)

  validation {
    condition     = length(var.task_subnet_ids) > 0 && alltrue([for s in var.task_subnet_ids : can(regex("^subnet-[0-9a-f]+$", s))])
    error_message = "task_subnet_ids must contain at least one subnet ID (subnet-...)."
  }
}

variable "task_subnets_are_public" {
  description = "Set to true only if task_subnet_ids are public subnets. Tasks then get a public IP for outbound traffic; their security group still allows no inbound traffic."
  type        = bool
  default     = false
}

################################################################################
# Identity
################################################################################

variable "identity_provider" {
  description = "How users sign in: IAMIdentityCenter, SAML, OIDC or CognitoOnly."
  type        = string
  default     = "IAMIdentityCenter"

  validation {
    condition     = contains(["IAMIdentityCenter", "SAML", "OIDC", "CognitoOnly"], var.identity_provider)
    error_message = "identity_provider must be one of IAMIdentityCenter, SAML, OIDC, CognitoOnly."
  }
}

variable "saml_metadata_url" {
  description = "SAML metadata URL of your IAM Identity Center application or SAML IdP. Leave empty for the first apply, create the SAML application from the saml_acs_url and saml_audience_uri outputs, then set this and apply again."
  type        = string
  default     = ""

  validation {
    condition     = var.saml_metadata_url == "" || can(regex("^https://\\S+$", var.saml_metadata_url))
    error_message = "saml_metadata_url must be empty or an https:// URL."
  }
}

variable "oidc_issuer" {
  description = "OIDC issuer URL (identity_provider = OIDC only)."
  type        = string
  default     = ""

  validation {
    condition     = var.oidc_issuer == "" || can(regex("^https://\\S+$", var.oidc_issuer))
    error_message = "oidc_issuer must be empty or an https:// URL."
  }
}

variable "oidc_client_id" {
  description = "OIDC client ID (identity_provider = OIDC only)."
  type        = string
  default     = ""
}

variable "oidc_client_secret_arn" {
  description = "ARN of a Secrets Manager secret whose SecretString is the OIDC client secret (identity_provider = OIDC only). CloudFormation resolves it at deploy time, so the secret is never stored in Terraform state."
  type        = string
  default     = ""

  validation {
    condition     = var.oidc_client_secret_arn == "" || can(regex("^arn:aws[a-z-]*:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:\\S+$", var.oidc_client_secret_arn))
    error_message = "oidc_client_secret_arn must be empty or a Secrets Manager secret ARN."
  }
}

variable "oidc_email_verified_claim" {
  description = "OIDC claim that says whether the IdP verified the user's email (identity_provider = OIDC only). Users whose email is not verified are refused. Keep email_verified for Okta, Google, Auth0 and most IdPs; use xms_edov for Microsoft Entra ID."
  type        = string
  default     = "email_verified"

  validation {
    condition     = can(regex("^[A-Za-z0-9_:.-]{1,128}$", var.oidc_email_verified_claim))
    error_message = "oidc_email_verified_claim must match ^[A-Za-z0-9_:.-]{1,128}$."
  }
}

variable "bootstrap_admin_email" {
  description = "Email of the first administrator. This user is always an admin and can grant admin rights to others in the admin console."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.bootstrap_admin_email))
    error_message = "bootstrap_admin_email must be an email address."
  }
}

################################################################################
# Sessions
################################################################################

variable "browser_task_size" {
  description = "CPU and memory of each browser session: 1vCPU-2GB, 2vCPU-4GB or 4vCPU-8GB."
  type        = string
  default     = "2vCPU-4GB"

  validation {
    condition     = contains(["1vCPU-2GB", "2vCPU-4GB", "4vCPU-8GB"], var.browser_task_size)
    error_message = "browser_task_size must be 1vCPU-2GB, 2vCPU-4GB or 4vCPU-8GB."
  }
}

variable "cpu_architecture" {
  description = "CPU architecture of the browser tasks. This release supports X86_64; ARM64 (Graviton) returns in a later release."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 in this release (ARM64 support returns in a later release)."
  }
}

variable "max_concurrent_sessions" {
  description = "Default limit on concurrent sessions across all users. Admins can change it later in the admin console."
  type        = number
  default     = 10

  validation {
    condition     = var.max_concurrent_sessions >= 1 && var.max_concurrent_sessions <= 1000 && floor(var.max_concurrent_sessions) == var.max_concurrent_sessions
    error_message = "max_concurrent_sessions must be a whole number between 1 and 1000."
  }
}

variable "allowed_cidrs" {
  description = "Initial IP allowlist for the portal and API (empty allows all). Used until an admin saves settings in the admin console."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "allowed_cidrs must contain CIDR blocks such as 203.0.113.0/24."
  }
}

################################################################################
# Logging and encryption
################################################################################

variable "log_retention_days" {
  description = "CloudWatch Logs retention for session, API and audit logs."
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a CloudWatch Logs retention value (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288 or 3653)."
  }
}

variable "kms_key_arn" {
  description = "Optional customer managed KMS key for DynamoDB, CloudWatch Logs, the update SNS topic and the stack's private artifacts bucket. The key policy must allow CloudWatch Logs and SNS to use it, and the identity running Terraform (or cloudformation_role_arn) needs kms:Decrypt on it."
  type        = string
  default     = ""

  validation {
    condition     = var.kms_key_arn == "" || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "kms_key_arn must be empty or a KMS key ARN."
  }
}

################################################################################
# Updates
################################################################################

variable "update_checks" {
  description = "Check once a day for a new release (downloads the vendor's public release manifest; nothing about you or your account is sent). New releases are shown in the admin console and announced on the update SNS topic (update_topic_arn)."
  type        = bool
  default     = true
}

variable "update_notification_email" {
  description = "Optional email address subscribed to the update SNS topic. AWS sends a confirmation email that must be accepted first. Empty for none."
  type        = string
  default     = ""

  validation {
    condition     = var.update_notification_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.update_notification_email))
    error_message = "update_notification_email must be empty or an email address."
  }
}

################################################################################
# Release (advanced)
################################################################################

variable "product_version" {
  description = "Release of Cloud Certainty Secure Browser to deploy. Selects the release's CloudFormation template, which pins the matching application artifacts and container image. Each module release defaults to the product release it was tested with, so upgrading usually means raising the module version."
  type        = string
  default     = "0.1.6"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,64}$", var.product_version))
    error_message = "product_version must match ^[A-Za-z0-9._-]{1,64}$."
  }
}

variable "template_url" {
  description = "Override the S3 URL of the CloudFormation template. By default it is https://cloudcertainty-secure-browser-us-east-1.s3.us-east-1.amazonaws.com/<product_version>/main.yaml, whatever Region you deploy to."
  type        = string
  default     = null
}

variable "image_uri" {
  description = "Override the browser container image (passed as the template's ImageUriOverride). Leave null to use the image pinned by digest in the product_version template. Set only when Cloud Certainty support asks you to; only digest-pinned images from the AWS Marketplace registry are accepted."
  type        = string
  default     = null

  validation {
    condition     = var.image_uri == null || can(regex("^709825985650\\.dkr\\.ecr\\.us-east-1\\.amazonaws\\.com/cloud-certainty/[a-z0-9._/-]+@sha256:[0-9a-f]{64}$", var.image_uri))
    error_message = "image_uri must be null or a digest-pinned Cloud Certainty image in the AWS Marketplace registry (709825985650.dkr.ecr.us-east-1.amazonaws.com/cloud-certainty/<repository>@sha256:<64 hex digits>)."
  }
}

variable "artifact_version_override" {
  description = "Override the application code version installed from the image (passed as the template's ArtifactVersionOverride). Leave null: the release is built into the product_version template. Set only when Cloud Certainty support asks you to, normally together with image_uri."
  type        = string
  default     = null

  validation {
    condition     = var.artifact_version_override == null || can(regex("^[A-Za-z0-9._-]{1,64}$", var.artifact_version_override))
    error_message = "artifact_version_override must be null or a release version such as 1.2.3."
  }
}

variable "cloudformation_role_arn" {
  description = "Optional IAM role CloudFormation assumes to create the stack (service role). Without it, CloudFormation uses the credentials Terraform runs with."
  type        = string
  default     = null
}

variable "timeout" {
  description = "How long Terraform waits for the stack to create, update or delete."
  type        = string
  default     = "60m"
}
