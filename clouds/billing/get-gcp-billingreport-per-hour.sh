#!/usr/bin/bash

clear

gcloud auth login                         # para usuário interactive
# ou (conta de serviço)
gcloud auth activate-service-account --key-file=/path/key.json

gcloud config set project YOUR_PROJECT_ID

bq --version                              # checar se bq está disponível

query=$(cat <<'QUERY'
SELECT
        TIMESTAMP_TRUNC(usage_start_time, HOUR) AS hour,
        project.id AS project_id,
        service.description AS service,
        sku.description AS sku,
        SUM(cost) AS total_cost
FROM `MEU_PROJETO.MEU_DATASET.gcp_billing_export_v1_*`
WHERE usage_start_time >= TIMESTAMP("2026-06-01 00:00:00")
    AND usage_start_time < TIMESTAMP("2026-06-08 00:00:00")
GROUP BY hour, project_id, service, sku
ORDER BY hour, project_id;
QUERY
)

