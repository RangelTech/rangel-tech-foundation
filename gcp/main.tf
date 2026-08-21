data "google_project" "current" {}

locals {
  required_services = toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "eventarc.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ])
}

resource "google_project_service" "required" {
  for_each           = local.required_services
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "containers" {
  location      = var.region
  repository_id = "containers"
  description   = "Shared OCI images for Rangel Tech Cloud Run services."
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket" "application_artifacts" {
  name                        = "${var.project_id}-application-artifacts"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning { enabled = true }
}

resource "google_storage_bucket" "frontend" {
  name                        = "${var.project_id}-frontend"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
}

resource "google_storage_bucket" "backups" {
  name                        = "${var.project_id}-backups"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = false

  lifecycle_rule {
    action { type = "Delete" }
    condition { num_newer_versions = 1 }
  }
}

resource "google_storage_bucket" "function_source" {
  name                        = "${var.project_id}-function-source"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
}

resource "google_service_account" "monitoring_reader" {
  account_id   = "grafana-monitoring-reader"
  display_name = "Grafana Cloud Monitoring reader"
}

resource "google_project_iam_member" "monitoring_reader" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.monitoring_reader.email}"
}

resource "google_service_account" "github_deployer" {
  account_id   = "github-deployer"
  display_name = "GitHub Actions deployer via Workload Identity Federation"
}

resource "google_project_iam_member" "github_deployer" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/cloudbuild.builds.editor",
    "roles/run.admin",
    "roles/storage.admin",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "OIDC federation for Rangel Tech repositories."
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_org}'"

  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}

resource "google_service_account_iam_member" "github_deployer" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository_owner/${var.github_org}"
}

# Achado real (21/08, migração do kernel-llm pro projeto certo): `gcloud run
# deploy` sem `--service-account` roda a revisão como a SA padrão de compute
# do projeto — o `github-deployer` precisa de `iam.serviceAccountUser` nela
# pra ter permissão de "atuar como", senão o deploy do CI falha com
# permissão negada mesmo tendo `roles/run.admin` no projeto.
resource "google_service_account_iam_member" "github_deployer_actas_default_compute" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${data.google_project.current.number}-compute@developer.gserviceaccount.com"
  role                = "roles/iam.serviceAccountUser"
  member              = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_service_account" "billing_blackout" {
  account_id   = "billing-blackout"
  display_name = "Disables project billing at the configured budget ceiling"
}

resource "google_project_iam_member" "billing_blackout" {
  project = var.project_id
  role    = "roles/billing.projectManager"
  member  = "serviceAccount:${google_service_account.billing_blackout.email}"
}

resource "google_project_iam_member" "billing_blackout_logs" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.billing_blackout.email}"
}

resource "google_pubsub_topic" "budget_alerts" {
  name = "budget-alerts"
}

resource "google_monitoring_notification_channel" "billing_email" {
  display_name = "Rangel Tech billing alerts"
  type         = "email"
  labels       = { email_address = var.billing_alert_email }
}

resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account_id
  display_name    = "Rangel Tech monthly ~USD 100 ceiling (${var.budget_amount_brl} BRL)"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  # Achado real na aplicação: a Billing Budgets API exige o valor na mesma
  # moeda da conta de billing (`gcloud billing accounts describe` confirma
  # currencyCode: BRL pra esta conta) — mandar USD dá 400 genérico, sem
  # detalhe no erro. O teto de US$100/mês (infra-01 seção 8g) vira BRL aqui;
  # `var.budget_amount_brl` é a conversão aproximada — câmbio muda, revisar
  # esse número de vez em quando, não é um valor fixo pra sempre.
  amount {
    specified_amount {
      currency_code = "BRL"
      units         = var.budget_amount_brl
    }
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.9
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    # Mesmo achado do notification channel logo abaixo: a API de Billing
    # Budgets exige número do projeto no tópico Pub/Sub também, não o ID
    # (google_pubsub_topic.id vem como "projects/<ID>/topics/<nome>").
    pubsub_topic = replace(
      google_pubsub_topic.budget_alerts.id,
      "projects/${var.project_id}/",
      "projects/${data.google_project.current.number}/"
    )
    # A API de Billing Budgets exige número do projeto aqui, não o ID —
    # achado real (a criação falhava com 400 genérico, sem detalhe; só
    # apareceu comparando com budget_filter.projects, que já usa número).
    # google_monitoring_notification_channel.billing_email.name vem no
    # formato "projects/<ID>/notificationChannels/<num>" (usa ID por padrão
    # na API do Monitoring) — troca só o segmento do projeto pelo número.
    monitoring_notification_channels = [
      replace(
        google_monitoring_notification_channel.billing_email.name,
        "projects/${var.project_id}/",
        "projects/${data.google_project.current.number}/"
      )
    ]
    disable_default_iam_recipients = true
  }
}

data "archive_file" "billing_blackout" {
  type        = "zip"
  source_dir  = "${path.module}/functions/billing_blackout"
  output_path = "${path.module}/.billing_blackout.zip"
}

resource "google_storage_bucket_object" "billing_blackout" {
  name   = "billing-blackout-${data.archive_file.billing_blackout.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.billing_blackout.output_path
}

resource "google_cloudfunctions2_function" "billing_blackout" {
  name        = "billing-blackout"
  location    = var.region
  description = "Disables billing when the actual monthly budget reaches USD 100."

  build_config {
    runtime     = "python312"
    entry_point = "billing_blackout"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.billing_blackout.name
      }
    }
  }

  service_config {
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = google_service_account.billing_blackout.email
    environment_variables = { PROJECT_ID = var.project_id }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.budget_alerts.id
    retry_policy   = "RETRY_POLICY_DO_NOT_RETRY"
  }

  depends_on = [
    google_project_service.required,
    google_project_iam_member.billing_blackout,
    google_project_iam_member.billing_blackout_logs,
  ]
}
