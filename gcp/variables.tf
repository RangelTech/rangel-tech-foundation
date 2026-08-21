variable "project_id" {
  type    = string
  default = "rangel-tech"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "billing_account_id" {
  type        = string
  description = "Billing account in bare form, for example 000000-000000-000000."
}

variable "billing_alert_email" {
  type        = string
  description = "Recipient for GCP budget notifications."
}

variable "github_org" {
  type    = string
  default = "rangel-tech"
}
