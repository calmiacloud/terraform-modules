output "Arn" {
  value       = aws_ses_domain_identity.identity.arn
}

output "VerificationToken" {
  value       = aws_ses_domain_identity.identity.verification_token
}