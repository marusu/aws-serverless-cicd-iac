# TODO(DayX): Re-introduce remote backend (S3 + DynamoDB) and manage state bucket via Terraform (or import).
# NOTE: Temporarily removed day3_demo bucket to unblock Day4 (BucketAlreadyOwnedByYou due to missing remote state).

resource "aws_iam_role" "lambda_role" {
  name = "terraform-demo-lambda-role"

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

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "hello" {
  function_name = "terraform-demo-hello"

  filename = "${path.module}/../lambda/hello.zip"
  handler  = "hello.lambda_handler"
  runtime  = "python3.11"

  role = aws_iam_role.lambda_role.arn

  source_code_hash = filebase64sha256("${path.module}/../lambda/hello.zip")
}
