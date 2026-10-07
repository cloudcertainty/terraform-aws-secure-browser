# Offline tests (no AWS credentials): terraform test
# Requires Terraform >= 1.7 for mock providers.

# The stack is deployed in eu-west-2 here. The template URL must still point at
# the vendor's us-east-1 bucket: there are no per-Region release buckets.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "eu-west-2"
    }
  }
  mock_data "aws_subnet" {
    defaults = {
      vpc_id = "vpc-0123456789abcdef0"
    }
  }
}

variables {
  vpc_id                = "vpc-0123456789abcdef0"
  task_subnet_ids       = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]
  bootstrap_admin_email = "admin@example.com"
}

run "defaults" {
  command = plan

  assert {
    condition     = aws_cloudformation_stack.this.name == "ztb-secure-browser"
    error_message = "unexpected stack name"
  }
  assert {
    condition     = aws_cloudformation_stack.this.template_url == "https://cloudcertainty-secure-browser-us-east-1.s3.us-east-1.amazonaws.com/0.1.6/main.yaml"
    error_message = "template URL must be the us-east-1 release bucket whatever the deploy Region: ${aws_cloudformation_stack.this.template_url}"
  }
  assert {
    condition     = !strcontains(aws_cloudformation_stack.this.template_url, "eu-west-2")
    error_message = "template URL must not depend on the deploy Region"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["TaskSubnetIds"] == "subnet-0123456789abcdef0,subnet-0fedcba9876543210"
    error_message = "subnets not joined"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["TaskSubnetsArePublic"] == "false"
    error_message = "public flag not passed as string"
  }
  assert {
    condition     = !contains(keys(aws_cloudformation_stack.this.parameters), "ImageUriOverride")
    error_message = "null overrides must be omitted so template defaults apply"
  }
  assert {
    condition     = !contains(keys(aws_cloudformation_stack.this.parameters), "ArtifactVersion") && !contains(keys(aws_cloudformation_stack.this.parameters), "ImageUri")
    error_message = "the release is built into the template: ArtifactVersion and ImageUri must not be passed"
  }
  assert {
    condition     = !contains(keys(aws_cloudformation_stack.this.parameters), "ArtifactVersionOverride")
    error_message = "ArtifactVersionOverride is support-only and must not be passed"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["UpdateChecks"] == "Enabled"
    error_message = "update checks should be enabled by default"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["UpdateNotificationEmail"] == ""
    error_message = "no notification email by default"
  }
  assert {
    condition     = contains(aws_cloudformation_stack.this.capabilities, "CAPABILITY_NAMED_IAM")
    error_message = "CAPABILITY_NAMED_IAM is required"
  }
}

run "product_version_selects_template_only" {
  command = plan

  variables {
    product_version = "0.2.0"
  }

  assert {
    condition     = aws_cloudformation_stack.this.template_url == "https://cloudcertainty-secure-browser-us-east-1.s3.us-east-1.amazonaws.com/0.2.0/main.yaml"
    error_message = "unexpected template URL: ${aws_cloudformation_stack.this.template_url}"
  }
  assert {
    condition     = !contains(values(aws_cloudformation_stack.this.parameters), "0.2.0")
    error_message = "product_version must not be passed as a stack parameter"
  }
}

run "default_template_url_and_no_vendor_parameters" {
  command = plan

  assert {
    condition     = aws_cloudformation_stack.this.template_url == "https://cloudcertainty-secure-browser-us-east-1.s3.us-east-1.amazonaws.com/0.1.6/main.yaml"
    error_message = "unexpected template URL: ${aws_cloudformation_stack.this.template_url}"
  }
  assert {
    condition     = !contains(keys(aws_cloudformation_stack.this.parameters), "MarketplaceProductCode") && !contains(keys(aws_cloudformation_stack.this.parameters), "ArtifactBucketPrefix")
    error_message = "the vendor bucket and product code are fixed in the template and must not be passed"
  }
}

run "explicit_template_url_wins" {
  command = plan

  variables {
    template_url = "https://example-bucket.s3.eu-west-2.amazonaws.com/custom/main.yaml"
  }

  assert {
    condition     = aws_cloudformation_stack.this.template_url == "https://example-bucket.s3.eu-west-2.amazonaws.com/custom/main.yaml"
    error_message = "template_url override not used"
  }
}

run "update_settings_mapped" {
  command = plan

  variables {
    update_checks             = false
    update_notification_email = "secops@example.com"
    image_uri                 = "709825985650.dkr.ecr.us-east-1.amazonaws.com/cloud-certainty/secure-browser@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  }

  assert {
    condition     = aws_cloudformation_stack.this.parameters["UpdateChecks"] == "Disabled"
    error_message = "update_checks = false must map to Disabled"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["UpdateNotificationEmail"] == "secops@example.com"
    error_message = "update_notification_email not passed"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["ImageUriOverride"] == "709825985650.dkr.ecr.us-east-1.amazonaws.com/cloud-certainty/secure-browser@sha256:0000000000000000000000000000000000000000000000000000000000000000"
    error_message = "image_uri must map to ImageUriOverride"
  }
}

run "invalid_notification_email_rejected" {
  command = plan

  variables {
    update_notification_email = "not-an-email"
  }

  expect_failures = [var.update_notification_email]
}

run "invalid_image_uri_rejected" {
  command = plan

  variables {
    image_uri = "docker.io/library/chromium:latest"
  }

  expect_failures = [var.image_uri]
}

run "tags_feed_template_parameters" {
  command = plan

  variables {
    tags = { Owner = "sec", CostCenter = "42", Team = "x" }
  }

  assert {
    condition     = aws_cloudformation_stack.this.parameters["TagOwner"] == "sec" && aws_cloudformation_stack.this.parameters["TagCostCenter"] == "42"
    error_message = "tag parameters not mapped"
  }
  assert {
    condition     = !contains(keys(aws_cloudformation_stack.this.parameters), "TagEnvironment")
    error_message = "missing tag keys should fall back to template defaults"
  }
}

run "oidc_requires_all_settings" {
  command = plan

  variables {
    identity_provider = "OIDC"
    oidc_issuer       = "https://idp.example.com"
  }

  expect_failures = [aws_cloudformation_stack.this]
}

run "saml_url_rejected_for_cognito_only" {
  command = plan

  variables {
    identity_provider = "CognitoOnly"
    saml_metadata_url = "https://example.com/metadata.xml"
  }

  expect_failures = [aws_cloudformation_stack.this]
}

run "subnet_outside_vpc_rejected" {
  command = plan

  variables {
    vpc_id = "vpc-0aaaaaaaaaaaaaaaa"
  }

  expect_failures = [aws_cloudformation_stack.this]
}

run "invalid_prefix_rejected" {
  command = plan

  variables {
    name_prefix = "Bad_Prefix"
  }

  expect_failures = [var.name_prefix]
}

run "unsupported_region_rejected" {
  command = plan

  override_data {
    target = data.aws_region.current
    values = {
      region = "af-south-1"
    }
  }

  expect_failures = [aws_cloudformation_stack.this]
}

run "oidc_claim_and_artifact_version_mapped" {
  command = plan

  variables {
    identity_provider         = "OIDC"
    oidc_issuer               = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
    oidc_client_id            = "client"
    oidc_client_secret_arn    = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:oidc-AbCdEf"
    oidc_email_verified_claim = "xms_edov"
    artifact_version_override = "0.1.6"
  }

  assert {
    condition     = aws_cloudformation_stack.this.parameters["OidcEmailVerifiedClaim"] == "xms_edov"
    error_message = "oidc_email_verified_claim must be passed as OidcEmailVerifiedClaim"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["ArtifactVersionOverride"] == "0.1.6"
    error_message = "artifact_version_override must be passed as ArtifactVersionOverride"
  }
}

run "artifact_version_left_to_template_by_default" {
  command = plan

  assert {
    condition     = !contains(keys(aws_cloudformation_stack.this.parameters), "ArtifactVersionOverride") && !contains(keys(aws_cloudformation_stack.this.parameters), "ImageUriOverride")
    error_message = "the support-only overrides must not be passed unless set"
  }
}

run "tag_only_marketplace_image_rejected" {
  command = plan

  variables {
    image_uri = "709825985650.dkr.ecr.us-east-1.amazonaws.com/cloud-certainty/secure-browser:0.1.6"
  }

  expect_failures = [var.image_uri]
}

run "empty_owner_tag_rejected" {
  command = plan

  variables {
    tags = { Owner = "" }
  }

  expect_failures = [var.tags]
}
