variable "github_org" {
  type    = string
  default = "rangel-tech"
}

variable "github_wif_provider" {
  type = string
}

variable "github_deployer_service_account" {
  type = string
}
variable "repository_names" {
  type    = set(string)
  default = ["rangel-tech-foundation", "agent-platform", "kernel-llm", "chatwoot-rt", "vps_rt_infra"]
}
