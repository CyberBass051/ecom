import json
import os
import uuid
from decimal import Decimal
import boto3

dynamodb = boto3.resource("dynamodb")
products_table = dynamodb.Table(os.environ["PRODUCTS_TABLE_NAME"])
sqs = boto3.client("sqs")
QUEUE_URL = os.environ["ORDERS_QUEUE_URL"]

HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


def _error(status, message):
    return {
        "statusCode": status,
        "headers": HEADERS,
        "body": json.dumps({"error": message}),
    }


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _error(400, "Invalid JSON body")

    items = body.get("items")
    if not items or not isinstance(items, list):
        return _error(400, "Request must include a non-empty 'items' list")

    # Recompute the total server-side. Never trust a client-supplied price —
    # the client may only send product_id and quantity.
    line_items = []
    total = Decimal("0")

    for entry in items:
        product_id = entry.get("product_id")
        quantity = entry.get("quantity")
        if not product_id or not isinstance(quantity, int) or quantity < 1:
            return _error(400, f"Invalid item: {entry}")

        resp = products_table.get_item(Key={"product_id": product_id})
        product = resp.get("Item")
        if not product:
            return _error(400, f"Unknown product_id: {product_id}")

        unit_price = Decimal(str(product["price"]))
        line_total = unit_price * quantity
        total += line_total

        line_items.append({
            "product_id": product_id,
            "quantity": quantity,
            "unit_price": str(unit_price),
            "line_total": str(line_total),
        })

    # order_id is generated here, server-side, never client-supplied. It's
    # what makes the consumer's DynamoDB write idempotent against SQS
    # redelivery of THIS message. It does not protect against the client
    # submitting two separate POST /orders requests for the same intent
    # (double-click) — that needs a client-supplied idempotency key,
    # deferred to Phase 2.
    order_id = str(uuid.uuid4())

    order = {
        "order_id": order_id,
        "items": line_items,
        "total": str(total),
        "status": "PENDING",
    }

    sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(order))

    return {
        "statusCode": 202,
        "headers": HEADERS,
        "body": json.dumps({"order_id": order_id, "total": str(total), "status": "PENDING"}),
    }

