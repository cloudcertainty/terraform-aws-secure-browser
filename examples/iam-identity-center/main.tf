# Sign-in through AWS IAM Identity Center (two applies).
#
# 1. terraform apply with saml_metadata_url = "" (the default).
# 2. In IAM Identity Center, create a custom SAML 2.0 application using the
#    saml_acs_url and saml_audience_uri outputs, assign users or groups, and
#    copy its "IAM Identity Center SAML metadata file" URL.
# 3. Set saml_metadata_url to that URL and terraform apply again.

provider "aws" {
  region = var.region
}

module "secure_browser" {
  source = "../.."

  name_prefix           = "acme"
  vpc_id                = var.vpc_id
  task_subnet_ids       = var.private_subnet_ids
  identity_provider     = "IAMIdentityCenter"
  saml_metadata_url     = var.saml_metadata_url
  bootstrap_admin_email = var.admin_email

  tags = {
    Owner       = "it-security"
    CostCenter  = "1234"
    Environment = "prod"
  }
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "admin_email" {
  type = string
}

variable "saml_metadata_url" {
  type    = string
  default = ""
}

output "portal_url" {
  value = module.secure_browser.portal_url
}

output "saml_acs_url" {
  value = module.secure_browser.saml_acs_url
}

output "saml_audience_uri" {
  value = module.secure_browser.saml_audience_uri
}
