variable "github_org" {
  # Achado real (21/08): o slug da org não tem hífen — 'rangel-tech' é 404,
  # a org de verdade é 'RangelTech'.
  type    = string
  default = "RangelTech"
}

variable "github_wif_provider" {
  type = string
}

variable "github_deployer_service_account" {
  type = string
}
variable "repository_names" {
  type = set(string)
  default = [
    "rangel-tech-foundation", "agent-platform", "kernel-llm", "chatwoot-rt",
    "vps_rt_infra", "litellm-router",
  ]
}
