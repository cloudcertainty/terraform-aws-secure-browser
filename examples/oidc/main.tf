# Sign-in through an OIDC provider (Entra ID, Okta, Google Workspace, ...).
#
# Create the client secret in Secrets Manager outside Terraform, so it never
# lands in Terraform state, for example:
#   aws secretsmanager create-secret --name secure-browser/oidc-client-secret \
#     --secret-string '<client secret>'
# Register https://<cognito_domain output>/oauth2/idpresponse as the redirect URI
# in your identity provider.

provider "aws" {
  region = "eu-west-2"
}

data "aws_secretsmanager_secret" "oidc" {
  name = "secure-browser/oidc-client-secret"
}

module "secure_browser" {
  source = "../.."

  name_prefix            = "acme"
  vpc_id                 = "vpc-0123456789abcdef0"
  task_subnet_ids        = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]
  identity_provider      = "OIDC"
  oidc_issuer            = "https://login.microsoftonline.com/<tenant-id>/v2.0"
  oidc_client_id         = "<application-client-id>"
  oidc_client_secret_arn = data.aws_secretsmanager_secret.oidc.arn
  bootstrap_admin_email  = "admin@example.com"
}

output "portal_url" {
  value = module.secure_browser.portal_url
}

output "oidc_redirect_uri" {
  value = "https://${module.secure_browser.cognito_domain}/oauth2/idpresponse"
}
