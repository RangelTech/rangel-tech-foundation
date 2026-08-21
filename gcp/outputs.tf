output "artifact_registry_repository" { value = google_artifact_registry_repository.containers.name }
output "github_wif_provider" { value = google_iam_workload_identity_pool_provider.github_actions.name }
output "github_deployer_service_account" { value = google_service_account.github_deployer.email }
output "grafana_monitoring_reader_service_account" { value = google_service_account.monitoring_reader.email }
output "billing_blackout_function" { value = google_cloudfunctions2_function.billing_blackout.name }
