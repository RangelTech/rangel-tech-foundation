import base64
import json
import logging
import os

from googleapiclient import discovery


def billing_blackout(event, _context):
    """Detach billing only for a real-spend notification at the budget ceiling."""
    message = event.get("data", {}).get("message", {})
    encoded = message.get("data")
    if not encoded:
        logging.warning("Ignoring Pub/Sub event without budget payload")
        return

    payload = json.loads(base64.b64decode(encoded).decode("utf-8"))
    cost = float(payload.get("costAmount", 0))
    budget = float(payload.get("budgetAmount", 0))
    if budget <= 0 or cost < budget:
        logging.info("Budget notification below blackout threshold: %s/%s", cost, budget)
        return

    project_id = os.environ["PROJECT_ID"]
    billing = discovery.build("cloudbilling", "v1", cache_discovery=False)
    billing.projects().updateBillingInfo(
        name=f"projects/{project_id}", body={"billingAccountName": ""}
    ).execute()
    logging.critical("Billing detached for project %s at real spend %s", project_id, cost)
