data "aws_region" "current" {}

data "aws_subnet" "task" {
  for_each = toset(var.task_subnet_ids)
  id       = each.value
}

locals {
  # The release templates live only in the vendor's public bucket in us-east-1.
  # CloudFormation accepts a template URL from any Region, so the same URL deploys
  # the stack in whichever Region the provider targets. The product code itself
  # ships inside the Marketplace container image and is installed into a private
  # bucket in your account by the stack.
  template_url = coalesce(
    var.template_url,
    "https://cloudcertainty-secure-browser-us-east-1.s3.us-east-1.amazonaws.com/${var.product_version}/main.yaml",
  )

  # Keys mirror the CloudFormation template's parameters. Null values are left
  # out so the template's own defaults apply. The release (Lambda/web artifacts
  # and the digest-pinned image) is built into the template that template_url
  # selects, so no version parameter is passed.
  parameters = { for k, v in {
    NamePrefix              = var.name_prefix
    TagOwner                = lookup(var.tags, "Owner", null)
    TagCostCenter           = lookup(var.tags, "CostCenter", null)
    TagEnvironment          = lookup(var.tags, "Environment", null)
    VpcId                   = var.vpc_id
    TaskSubnetIds           = join(",", var.task_subnet_ids)
    TaskSubnetsArePublic    = tostring(var.task_subnets_are_public)
    IdentityProvider        = var.identity_provider
    SamlMetadataUrl         = var.saml_metadata_url
    OidcIssuer              = var.oidc_issuer
    OidcClientId            = var.oidc_client_id
    OidcClientSecretArn     = var.oidc_client_secret_arn
    OidcEmailVerifiedClaim  = var.oidc_email_verified_claim
    BootstrapAdminEmail     = var.bootstrap_admin_email
    BrowserTaskSize         = var.browser_task_size
    CpuArchitecture         = var.cpu_architecture
    MaxConcurrentSessions   = tostring(var.max_concurrent_sessions)
    AllowedCidrs            = join(",", var.allowed_cidrs)
    LogRetentionDays        = tostring(var.log_retention_days)
    KmsKeyArn               = var.kms_key_arn
    UpdateChecks            = var.update_checks ? "Enabled" : "Disabled"
    UpdateNotificationEmail = var.update_notification_email
    ImageUriOverride        = var.image_uri
    ArtifactVersionOverride = var.artifact_version_override
  } : k => v if v != null }

  # Regions where AWS Marketplace RegisterUsage works (the template's RegionSupportsMarketplaceMetering
  # rule): every browser and installer task makes this licence check.
  metering_regions = [
    "us-east-1", "us-east-2", "us-west-1", "us-west-2", "ca-central-1", "sa-east-1",
    "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1", "eu-north-1",
    "ap-east-1", "ap-south-1", "ap-northeast-1", "ap-northeast-2", "ap-southeast-1", "ap-southeast-2",
  ]

  oidc_complete = var.oidc_issuer != "" && var.oidc_client_id != "" && var.oidc_client_secret_arn != ""
  uses_saml     = contains(["IAMIdentityCenter", "SAML"], var.identity_provider)
}

resource "aws_cloudformation_stack" "this" {
  name         = coalesce(var.stack_name, "${var.name_prefix}-secure-browser")
  template_url = local.template_url
  parameters   = local.parameters
  iam_role_arn = var.cloudformation_role_arn
  tags         = var.tags

  # The template creates IAM roles, one of them with a fixed name.
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }

  lifecycle {
    # Same checks as the template's Rules, surfaced at plan time.
    precondition {
      condition     = contains(local.metering_regions, data.aws_region.current.region)
      error_message = "This Region does not support AWS Marketplace RegisterUsage, which the browser tasks need for their licence check. Deploy in one of: ${join(", ", local.metering_regions)}."
    }
    precondition {
      condition     = alltrue([for s in data.aws_subnet.task : s.vpc_id == var.vpc_id])
      error_message = "All task_subnet_ids must belong to vpc_id."
    }
    precondition {
      condition     = var.identity_provider != "OIDC" || local.oidc_complete
      error_message = "identity_provider = OIDC requires oidc_issuer, oidc_client_id and oidc_client_secret_arn."
    }
    precondition {
      condition     = local.uses_saml || var.saml_metadata_url == ""
      error_message = "saml_metadata_url is only used with identity_provider IAMIdentityCenter or SAML."
    }
  }
}
