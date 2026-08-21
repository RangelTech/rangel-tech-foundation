resource "github_actions_organization_variable" "gcp_project" {
  variable_name           = "GCP_PROJECT_ID"
  value                   = "rangel-tech"
  visibility              = "selected"
  selected_repository_ids = [for repo in data.github_repository.managed : repo.repo_id]
}

resource "github_actions_organization_variable" "wif_provider" {
  variable_name           = "GCP_WORKLOAD_IDENTITY_PROVIDER"
  value                   = var.github_wif_provider
  visibility              = "selected"
  selected_repository_ids = [for repo in data.github_repository.managed : repo.repo_id]
}

resource "github_actions_organization_variable" "deployer_sa" {
  variable_name           = "GCP_DEPLOYER_SERVICE_ACCOUNT"
  value                   = var.github_deployer_service_account
  visibility              = "selected"
  selected_repository_ids = [for repo in data.github_repository.managed : repo.repo_id]
}

data "github_repository" "managed" {
  for_each  = var.repository_names
  full_name = "${var.github_org}/${each.value}"
}
