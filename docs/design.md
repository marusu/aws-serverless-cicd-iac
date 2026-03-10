# サーバーレス基盤構築プロジェクト 設計書

## 1. 概要

本プロジェクトは、AWS上にサーバーレスアーキテクチャを構築し、TerraformによるInfrastructure as Code（IaC）およびGitHub ActionsによるCI/CDパイプラインを用いて、インフラの自動構築・自動デプロイを実現することを目的とする。

インフラ構成はすべてTerraformコードで管理しており、GitHub Pull RequestをトリガーとしたCI/CDパイプラインによって、安全なインフラ変更を実現している。

また、GitHub ActionsとAWSの認証にはOIDC（OpenID Connect）を利用し、長期的なAWSアクセスキーをGitHub Secretsに保存することなく、一時的な認証情報を利用したセキュアな認証方式を採用している。

---

## 2. システム構成

本システムは以下のサーバーレス構成で構築している。

- API Gateway
- AWS Lambda
- DynamoDB
- CloudWatch
- SNS

インフラ構築およびCI/CDには以下の技術を使用している。

| 分類 | 技術 |
|---|---|
| IaC | Terraform |
| CI/CD | GitHub Actions |
| 認証 | OIDC (OpenID Connect) |
| API | Amazon API Gateway |
| Compute | AWS Lambda |
| Database | Amazon DynamoDB |
| Monitoring | Amazon CloudWatch |
| Notification | Amazon SNS |

---

## 3. アーキテクチャ概要

本システムは以下の構成で動作する。

```text
GitHub
  │
  │ Push / Pull Request
  ▼
GitHub Actions
  │
  ▼
Terraform
  │
  ▼
AWS Infrastructure
```

アプリケーション実行フローは以下の通り。

```text
Client
  │
  ▼
API Gateway
  │
  ▼
Lambda Alias
  │
  ▼
Lambda Version
  │
  ▼
DynamoDB
```

監視構成は以下の通り。

```text
Lambda
  │
  ▼
CloudWatch Metrics
  │
  ▼
CloudWatch Alarm
  │
  ▼
SNS
  │
  ▼
Email Notification
```

---

## 4. Terraform設計

### 4.1 Infrastructure as Code

本プロジェクトではTerraformを用いてAWSインフラをコード化している。

Terraformを使用することで以下のメリットを得る。

- インフラ構成のコード管理
- 再現性のある環境構築
- Pull Requestによるレビュー可能なインフラ変更
- CI/CDによる自動デプロイ

---

### 4.2 Terraform State管理

Terraformの状態管理（State）は、リモートバックエンドとしてAmazon S3を使用している。  
また、同時実行によるStateの競合を防ぐため、Amazon DynamoDBによるState Lockを構成している。

TerraformのState管理構成は以下の通り。

|項目|サービス|役割|
|---|---|---|
|State保存|Amazon S3|TerraformのStateファイルを保存|
|State Lock|Amazon DynamoDB|Terraform実行時の排他制御|

---

## 5. CI/CD設計

CI/CDにはGitHub Actionsを利用している。

デプロイフローは以下の通り。

```text
Developer
  │
  ▼
Feature Branch
  │
  ▼
Pull Request
  │
  ▼
GitHub Actions (Plan)
  │
  ▼
Merge
  │
  ▼
GitHub Actions (Apply)
```

CI処理では以下を実行する。

```bash
terraform fmt
terraform init
terraform validate
terraform plan
```

mainブランチへのマージ時には以下を実行する。

```bash
terraform apply
```

これによりインフラ変更は必ずPull Requestを経由する形となり、コードレビューを通じて安全にインフラ変更を管理できる。

---

## 6. 認証設計（OIDC）

GitHub Actions から AWS への認証には OIDC（OpenID Connect）を使用している。

従来のアクセスキー方式とは異なり、OIDC を利用することで、長期的な AWS アクセスキーを GitHub Secrets に保存することなく、一時的な認証情報で AWS にアクセスできる。

### 利点

- 長期アクセスキーが不要
- 一時的な認証情報によるセキュアな認証
- IAMロールによる権限制御
- GitHub Actions の実行元リポジトリやブランチを条件にしたアクセス制御が可能

### OIDC Provider

```text
token.actions.githubusercontent.com
```

IAMロールの信頼ポリシーでは、GitHub Actions から発行される OIDC トークンを検証し、特定のリポジトリおよび条件に一致するワークフローのみがロールを引き受け可能な設定としている。

---

## 7. デプロイ戦略

LambdaのデプロイにはVersionおよびAliasを使用している。

構成は以下の通り。

```text
API Gateway
  │
  ▼
Lambda Alias (prod)
  │
  ▼
Lambda Version
```

API GatewayはLambdaのAliasを参照する構成としている。
これにより、Aliasの参照先Versionを切り替えることで、
アプリケーションコードのロールバックを迅速に実施することができる。

この方式により

- バージョン管理
- 安全なロールバック
- 将来的なBlue/Greenデプロイ
- Canaryリリース

への対応が可能となる。

---

## 8. データストア設計

データストアにはAmazon DynamoDBを使用している。

テーブル設計は以下の通り。

|属性|型|説明|
|---|---|---|
|id|String|パーティションキー|
|message|String|保存データ|

課金モードは以下を採用している。

```text
PAY_PER_REQUEST
```

理由

- トラフィック量の事前予測が不要
- アクセス量に応じた自動スケーリング
- PoC用途における運用負荷の軽減

---

## 9. IAM設計

LambdaからDynamoDBへのアクセスには最小権限ポリシーを採用している。

許可アクション

```text
dynamodb:GetItem
dynamodb:PutItem
```

AdministratorAccessなどの広範な権限は付与せず、
最小権限の原則（Principle of Least Privilege）に基づいたIAMポリシーを設定している。

これによりセキュリティリスクを最小化している。

---

## 10. 監視設計

システムの監視にはAmazon CloudWatchを利用している。

監視対象は以下の通り。

| メトリクス | 説明 |
|---|---|
| Errors | Lambda実行エラー |
| Duration | Lambda処理時間 |

CloudWatch Alarmが閾値を超過した場合、Amazon SNSを通じてメール通知を行う。

監視フロー

```text
Lambda
  │
  ▼
CloudWatch Metrics
  │
  ▼
CloudWatch Alarm
  │
  ▼
SNS
  │
  ▼
Email Notification
```

---

## 11. ディレクトリ構成

```text
aws-serverless-cicd-iac
├─ docs
│  └─ design.md
├─ infra
│  ├─ main.tf
│  ├─ providers.tf
│  ├─ backend.tf
│  └─ variables.tf
├─ lambda
│  ├─ hello.py
│  └─ hello.zip
└─ .github
   └─ workflows
      ├─ terraform-plan.yml
      └─ terraform-apply.yml
```

---

## 12. 動作確認

API Gatewayを通じてLambdaを実行し、DynamoDBへの保存および取得を確認している。

### 保存

```http
POST /hello
Content-Type: application/json

{
  "id": "001",
  "message": "hello dynamodb"
}
```

### 取得

```http
GET /hello?id=001
```

---

## 13. 今後の拡張

将来的には以下の機能拡張を想定している。

- Lambda Canaryデプロイ
- Terraform Module化
- API Gateway認証（Cognito / JWT）
- Observability強化（AWS X-Rayによるトレーシング、構造化ログの導入）

---

## 14. まとめ

本プロジェクトでは以下を実現した。

- TerraformによるInfrastructure as Code
- GitHub ActionsによるCI/CDパイプライン
- OIDCによるセキュアなAWS認証
- Serverlessアーキテクチャによるアプリケーション基盤
- CloudWatchによる監視基盤

これにより、インフラ構成のコード管理、再現性のある環境構築、および安全なインフラ変更の自動化を実現した。