# Rangel Tech Foundation

Terraform da fundacao compartilhada da Rangel Tech. A pasta `gcp/` e aplicada
antes dos repos de servico; `github/` passa a declarar configuracao comum da
organizacao depois do bootstrap manual da organizacao `rangel-tech`.

O bootstrap manual inevitavel e somente criar a organizacao no GitHub e criar
este repositorio nela. Nenhuma chave estatica de GCP e usada em GitHub Actions:
os repos autenticam via Workload Identity Federation.

## Ordem

1. Aplicar `gcp/` com `billing_account_id` e `billing_alert_email`.
2. Criar a organizacao `rangel-tech` na interface do GitHub e transferir este
   repositorio para ela.
3. Aplicar `github/`, informando os outputs `github_wif_provider` e
   `github_deployer_service_account` de `gcp/`.
4. Transferir os repos de servico e aplicar os Terraform deles.

O budget de US$100 publica em Pub/Sub. A funcao `billing_blackout` desassocia a
conta de billing somente quando o gasto real comunicado for maior ou igual ao
budget. O Google pode entregar dados de billing com atraso; nao e um limitador
de custo em tempo real.
