terraform {
  backend "s3" {
    bucket         = "marusu-aws-serverless-cicd-iac-day3-demo"
    key            = "tfstate/infra.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "tf-lock-aws-serverless-cicd-iac"
    encrypt        = true
  }
}
