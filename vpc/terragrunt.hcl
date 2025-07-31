##Copyright © Amazon.com and Affiliates: This deliverable is considered Developed Content as defined in the AWS Service Terms and the SOW between the parties dated [date].

terraform {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=v5.18.1"
}

locals {
  payload = jsondecode(get_env("TF_VAR_payload", "{}"))
  vpc_config = try(local.payload.Parameters[0].VPC, {})

  # Backend configuration
  aws_region = try(local.payload.RegionId, "us-east-1")
  state_bucket_name = "${local.payload.ApplicationName}-${local.payload.EnvironmentId}-tfstate"
  state_key = "vpc/terraform.tfstate"
  lock_table_name = "${local.payload.ApplicationName}-${local.payload.EnvironmentId}-tfstate-lock"
}

# Remote State Configuration
remote_state {
  backend = "s3"
  
  config = {
    bucket         = local.state_bucket_name
    key            = local.state_key
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = local.lock_table_name
  }
}

# Generate backend configuration
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {}
}
EOF
}

# Generate AWS Provider Configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  
  default_tags {
    tags = {
      Environment  = "${local.payload.EnvironmentId}"
      Application = "${local.payload.ApplicationName}"
      Division    = "${local.payload.DivisionName}"
      AccountId   = "${local.payload.AccountId}"
      AccountAlias = "${local.payload.AccountAlias}"
    }
  }
}
EOF
}

inputs = {
  name = "${local.payload.ApplicationName}-${local.payload.EnvironmentId}-${local.payload.Suffix}"
  cidr = local.vpc_config.vpc_cidr

  tags = {
    Environment = local.payload.EnvironmentId
    Application = local.payload.ApplicationName
    Division    = local.payload.DivisionName
    AccountId   = local.payload.AccountId
    AccountAlias = local.payload.AccountAlias
  }
}