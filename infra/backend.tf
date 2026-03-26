terraform {
  backend "s3" {
    bucket       = "marusu-tfstate-aws-serverless-cicd-iac-apne1"
    key          = "env/dev/infra.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
}