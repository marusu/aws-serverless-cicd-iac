import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    http_method = (
        event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("httpMethod")
        or ""
    )

    if http_method.upper() == "POST":
        body = json.loads(event.get("body") or "{}")
        item_id = body.get("id")
        message = body.get("message")

        if not item_id or not message:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "id and message are required"})
            }

        table.put_item(
            Item={
                "id": item_id,
                "message": message
            }
        )

        return {
            "statusCode": 200,
            "body": json.dumps({
                "result": "saved",
                "id": item_id,
                "message": message
            })
        }

    query_params = event.get("queryStringParameters") or {}
    item_id = query_params.get("id")

    if not item_id:
        return {
            "statusCode": 200,
            "body": "Hello from Terraform Lambda!"
        }

    response = table.get_item(Key={"id": item_id})
    item = response.get("Item")

    if not item:
        return {
            "statusCode": 404,
            "body": json.dumps({"error": "item not found", "id": item_id})
        }

    return {
        "statusCode": 200,
        "body": json.dumps(item)
    }