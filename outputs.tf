output "portal_url" {
  description = "URL of the user portal and admin console."
  value       = try(aws_cloudformation_stack.this.outputs["PortalUrl"], null)
}

output "api_url" {
  description = "Base URL of the HTTP API."
  value       = try(aws_cloudformation_stack.this.outputs["ApiUrl"], null)
}

output "saml_acs_url" {
  description = "Assertion Consumer Service (ACS) URL to enter in your IAM Identity Center or SAML application."
  value       = try(aws_cloudformation_stack.this.outputs["SamlAcsUrl"], null)
}

output "saml_audience_uri" {
  description = "SAML audience (entity ID) to enter in your IAM Identity Center or SAML application."
  value       = try(aws_cloudformation_stack.this.outputs["SamlAudienceUri"], null)
}

output "cognito_domain" {
  description = "Cognito managed login domain. For OIDC, register https://<this domain>/oauth2/idpresponse as the redirect URI."
  value       = try(aws_cloudformation_stack.this.outputs["CognitoDomain"], null)
}

output "user_pool_id" {
  description = "Cognito user pool ID."
  value       = try(aws_cloudformation_stack.this.outputs["UserPoolId"], null)
}

output "user_pool_client_id" {
  description = "Cognito app client ID used by the portal."
  value       = try(aws_cloudformation_stack.this.outputs["UserPoolClientId"], null)
}

output "cluster_name" {
  description = "ECS cluster that runs the browser sessions."
  value       = try(aws_cloudformation_stack.this.outputs["ClusterName"], null)
}

output "table_name" {
  description = "DynamoDB table holding settings, sessions and the audit log (kept when the stack is deleted)."
  value       = try(aws_cloudformation_stack.this.outputs["TableName"], null)
}

output "task_security_group_id" {
  description = "Security group of the browser tasks (no inbound rules). Allow it as a source on private applications the sessions should reach."
  value       = try(aws_cloudformation_stack.this.outputs["TaskSecurityGroupId"], null)
}

output "product_version" {
  description = "Cloud Certainty Secure Browser release the stack runs (stack output ProductVersion)."
  value       = try(aws_cloudformation_stack.this.outputs["ProductVersion"], null)
}

output "update_topic_arn" {
  description = "SNS topic that announces new releases. Subscribe email, AWS Chatbot (Slack, Microsoft Teams) or other endpoints to it."
  value       = try(aws_cloudformation_stack.this.outputs["UpdateTopicArn"], null)
}

output "stack_id" {
  description = "ID of the CloudFormation stack."
  value       = aws_cloudformation_stack.this.id
}

output "stack_outputs" {
  description = "All outputs of the CloudFormation stack."
  value       = aws_cloudformation_stack.this.outputs
}
