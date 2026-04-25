variable "project_name" {
  description = "Project name for tags"
  type        = string
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-1"
}

variable "azs" {
  description = "Availability zones required"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "vpc_cidr" {
  description = "CIDR Block for vpc"
  type             = string
  default        = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR"
  type             = list(string)
  default        = ["10.0.1.0/24", "10.0.3.0/24", "10.0.5.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR"
  type             = list(string)
  default        = ["10.0.2.0/24", "10.0.4.0/24", "10.0.6.0/24"]
}


variable "budget_name" {
  description = "The name of the budget"
  type        = string
  default     = "production_budget"
}

variable "limit_amount" {
  description = "The maximum spend limit for the month"
  type        = string
  default     = "50"
}

variable "subscriber_emails" {
  description = "List of email addresses to receive notifications in a list of strings"
  type        = list(string)
}

variable "threshold" {
  description = "The percentage of the budget to trigger a notification"
  type        = number
  default     = 80
}

variable "s3_bucket_name" {
  description = "S3 bucket for backend"
  type = string
  default = "taskapp-hunter-terraform-state"
}

variable "kops_bucket_name" {
  description = "S3 bucket for kops"
  type = string
  default = "taskapp-hunter-kops-state"
}

variable "table_name" {
  description = "DynamoDB for backend"
  type = string
  default = "taskapp-hunter-terraform-locks"
}
