# Quick evaluation without an external identity provider. Users are created in
# the Cognito user pool; the bootstrap admin receives an invitation email.

provider "aws" {
  region = "eu-west-2"
}

module "secure_browser" {
  source = "../.."

  name_prefix           = "eval"
  vpc_id                = "vpc-0123456789abcdef0"
  task_subnet_ids       = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]
  identity_provider     = "CognitoOnly"
  bootstrap_admin_email = "admin@example.com"
  browser_task_size     = "1vCPU-2GB"
  allowed_cidrs         = ["203.0.113.0/24"]
}

output "portal_url" {
  value = module.secure_browser.portal_url
}
