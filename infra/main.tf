resource "aws_s3_bucket" "tfstate_bucket" {
  bucket = "marusu-aws-serverless-cicd-iac-day3-demo"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "portfolio-dev-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "api_handler" {
  function_name = "portfolio-dev-api-handler"
  filename      = "${path.module}/../lambda/hello.zip"
  handler       = "hello.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec_role.arn

  source_code_hash = filebase64sha256("${path.module}/../lambda/hello.zip")
  publish          = true

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.app_data_table.name
    }
  }
}

resource "aws_lambda_alias" "prod" {
  name             = "prod"
  function_name    = aws_lambda_function.api_handler.function_name
  function_version = aws_lambda_function.api_handler.version
}

resource "aws_apigatewayv2_api" "application_api" {
  name          = "portfolio-dev-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "api_lambda_proxy" {
  api_id           = aws_apigatewayv2_api.application_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_alias.prod.invoke_arn
}

resource "aws_apigatewayv2_route" "get_message_route" {
  api_id    = aws_apigatewayv2_api.application_api.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda_proxy.id}"
}

resource "aws_apigatewayv2_route" "post_message_route" {
  api_id    = aws_apigatewayv2_api.application_api.id
  route_key = "POST /hello"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda_proxy.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.application_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_alias.prod.function_name
  qualifier     = aws_lambda_alias.prod.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.application_api.execution_arn}/*/*"
}

resource "aws_dynamodb_table" "app_data_table" {
  name         = "portfolio-dev-app-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role_policy" "app_data_rw_policy" {
  name = "portfolio-dev-lambda-app-data-rw"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.app_data_table.arn
      }
    ]
  })
}

resource "aws_sns_topic" "alert_topic" {
  name = "portfolio-dev-alerts"
}

resource "aws_sns_topic_subscription" "alert_email_subscription" {
  topic_arn = aws_sns_topic.alert_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "portfolio-dev-api-handler-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm when Lambda function has errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.api_handler.function_name
  }

  alarm_actions = [aws_sns_topic.alert_topic.arn]
  ok_actions    = [aws_sns_topic.alert_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "portfolio-dev-api-handler-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 3000
  alarm_description   = "Alarm when Lambda duration is too high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.api_handler.function_name
  }

  alarm_actions = [aws_sns_topic.alert_topic.arn]
  ok_actions    = [aws_sns_topic.alert_topic.arn]
}

moved {
  from = aws_s3_bucket.day3_demo
  to   = aws_s3_bucket.tfstate_bucket
}

moved {
  from = aws_iam_role.lambda_role
  to   = aws_iam_role.lambda_exec_role
}

moved {
  from = aws_iam_role_policy_attachment.lambda_basic
  to   = aws_iam_role_policy_attachment.lambda_basic_execution
}

moved {
  from = aws_lambda_function.hello
  to   = aws_lambda_function.api_handler
}

moved {
  from = aws_apigatewayv2_api.http_api
  to   = aws_apigatewayv2_api.application_api
}

moved {
  from = aws_apigatewayv2_integration.lambda_integration
  to   = aws_apigatewayv2_integration.api_lambda_proxy
}

moved {
  from = aws_apigatewayv2_route.hello_route
  to   = aws_apigatewayv2_route.get_message_route
}

moved {
  from = aws_apigatewayv2_route.hello_post_route
  to   = aws_apigatewayv2_route.post_message_route
}

moved {
  from = aws_lambda_permission.api_gateway
  to   = aws_lambda_permission.allow_apigw_invoke
}

moved {
  from = aws_dynamodb_table.app_data
  to   = aws_dynamodb_table.app_data_table
}

moved {
  from = aws_iam_role_policy.lambda_dynamodb_policy
  to   = aws_iam_role_policy.app_data_rw_policy
}

moved {
  from = aws_sns_topic.alerts
  to   = aws_sns_topic.alert_topic
}

moved {
  from = aws_sns_topic_subscription.email_alert
  to   = aws_sns_topic_subscription.alert_email_subscription
}