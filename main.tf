#############################################
# 1. Provider-Konfiguration
#############################################

# Der Provider sagt Terraform:
# - welchen Cloud-Anbieter wir verwenden
# - in welcher Region gearbeitet wird
provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# Wichtig:
# Alle Ressourcen in dieser Datei werden
# automatisch in dieser Region erstellt.
#############################################
# 2. Datenbank: DynamoDB
#############################################

# Diese Ressource erstellt eine DynamoDB-Tabelle.
# Sie speichert die Daten unserer Auto-Verwaltung.
resource "aws_dynamodb_table" "cars_db" {

  # Name der Tabelle in AWS
  name = "cicd-test"

  # PAY_PER_REQUEST = On-Demand
  # - keine Kapazitätsplanung
  # - Kosten nur bei Nutzung
  billing_mode = "PAY_PER_REQUEST"

  # Primärschlüssel (Partition Key)
  hash_key = "Kennzeichen"

  # Definition des Attributs
  attribute {
    name = "Kennzeichen"
    type = "S" # S = String
  }
}

# Merksatz:
# Terraform erstellt die Tabelle,
# IAM entscheidet später, wer darauf zugreifen darf.
#############################################
# 3. Frontend: S3 Bucket (Static Website)
#############################################

# Der S3-Bucket speichert die gebaute React-App
# (HTML, CSS, JavaScript).
resource "aws_s3_bucket" "frontend_bucket" {

  # Bucket-Namen müssen weltweit eindeutig sein!
  bucket = "cicd-frontend-${data.aws_caller_identity.current.account_id}"

  force_destroy = true
}

# Diese Ressource aktiviert das Static Website Hosting.
resource "aws_s3_bucket_website_configuration" "frontend_config" {

  # Wir beziehen uns auf den zuvor erstellten Bucket
  bucket = aws_s3_bucket.frontend_bucket.id

  # Startseite der Webanwendung
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
  etag         = filemd5("index.html")
}
# Merksatz:
# S3 kann einfache Webseiten hosten,
# ganz ohne Server.
#############################################
# 4. S3 Bucket Policy (öffentliches Lesen)
#############################################

# Diese Policy macht den Bucket öffentlich lesbar.
# Achtung: Das ist ABSICHTLICH unsicher!
# Für Lernprojekte ok, für Produktivsysteme nicht.
## In AWS Academy ist Public Bucket Policy meist blockiert (BlockPublicPolicy).
## Deshalb hier keine öffentliche Bucket Policy.

# Hinweis für die Praxis:
# In echten Projekten:
# - S3 privat
# - Zugriff über CloudFront
#############################################
# 5. Vorhandene LabRole verwenden (AWS Academy)
#############################################

# In AWS Academy/Learner Lab ist das Erstellen von IAM-Rollen
# oft gesperrt. Deshalb verwenden wir die bestehende LabRole.
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}
#############################################
# 8. Backend: AWS Lambda Funktion
#############################################

resource "aws_lambda_function" "backend" {
  # ZIP-Datei mit dem Node.js-Code
  filename      = "backend_code.zip"
  # Name der Funktion in AWS
  function_name = "cicd-api"
  # Verknüpfung mit der IAM-Rolle
  role          = data.aws_iam_role.lab_role.arn
  # Einstiegspunkt im Code
  handler       = "index.handler"
  # Aktuelle Node.js Runtime
  runtime       = "nodejs18.x"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.cars_db.name
    }
  }
}

# Merksatz:
# Lambda führt Code aus,
# IAM regelt die Rechte,
# DynamoDB speichert die Daten.

output "bucket_name" {
  value = aws_s3_bucket.frontend_bucket.bucket
}

output "frontend_website_url" {
  value = aws_s3_bucket_website_configuration.frontend_config.website_endpoint
}

output "lambda_function_name" {
  value = aws_lambda_function.backend.function_name
}