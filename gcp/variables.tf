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

variable "budget_amount_brl" {
  description = "Teto mensal em BRL — a conta de billing é BRL (achado real, gcloud billing accounts describe), a API não aceita USD. ~R$580 é a conversão aproximada do teto de US$100 decidido em infra-01 seção 8g; câmbio muda, revisar este número periodicamente."
  type        = string
  default     = "580"
}

variable "github_org" {
  # Achado real: o slug da org não tem hífen (era 'rangel-tech' na spec,
  # 404 ao checar; a org de verdade é 'RangelTech', criada 21/08/2026).
  type    = string
  default = "RangelTech"
}
