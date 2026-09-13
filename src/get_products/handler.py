import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


def lambda_handler(event, context):
    try:
        response = table.scan()
        items = response.get("Items", [])
        return {
            "statusCode": 200,
            "headers": HEADERS,
            "body": json.dumps(items),
        }
    except Exception as exc:
        return {
            "statusCode": 500,
            "headers": HEADERS,
            "body": json.dumps({"error": str(exc)}),
        }

