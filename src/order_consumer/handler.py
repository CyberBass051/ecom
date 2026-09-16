import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["ORDERS_TABLE_NAME"])


def lambda_handler(event, context):
    for record in event["Records"]:
        order = json.loads(record["body"])

        try:
            table.put_item(
                Item=order,
                ConditionExpression="attribute_not_exists(order_id)",
            )
        except ClientError as exc:
            if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
                continue
            raise

    return {"batchItemFailures": []}

