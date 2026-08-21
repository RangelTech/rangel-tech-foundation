# Achado real (21/08/2026, ao ligar o CI/CD do kernel-llm pela primeira
# vez): a org `RangelTech` está no plano Free do GitHub — nesse plano,
# variáveis/secrets de ORGANIZAÇÃO simplesmente não propagam pra
# repositórios PRIVADOS (funciona só pra repo público, ou em planos
# Team/Enterprise). A API aceita configurar `visibility: selected` e
# devolve os repos certos na listagem, mas o contexto `vars` do workflow
# vem vazio em runtime — não é bug de configuração, é limitação de plano.
# Corrigido usando variável POR REPOSITÓRIO (mesmos 3 valores, replicados),
# em vez de variável de organização — continua sem chave estática de SA
# nenhuma (só os identificadores do WIF, que não são segredo), zero custo
# adicional (não precisa upgrade de plano pra isso).
resource "github_actions_variable" "gcp_project" {
  for_each      = data.github_repository.managed
  repository    = each.value.name
  variable_name = "GCP_PROJECT_ID"
  value         = "rangel-tech"
}

resource "github_actions_variable" "wif_provider" {
  for_each      = data.github_repository.managed
  repository    = each.value.name
  variable_name = "GCP_WORKLOAD_IDENTITY_PROVIDER"
  value         = var.github_wif_provider
}

resource "github_actions_variable" "deployer_sa" {
  for_each      = data.github_repository.managed
  repository    = each.value.name
  variable_name = "GCP_DEPLOYER_SERVICE_ACCOUNT"
  value         = var.github_deployer_service_account
}

data "github_repository" "managed" {
  for_each  = var.repository_names
  full_name = "${var.github_org}/${each.value}"
}
