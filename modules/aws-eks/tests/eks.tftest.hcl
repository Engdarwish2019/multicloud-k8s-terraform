# Offline unit tests: the aws, tls and time providers are mocked, so `terraform test` needs no
# AWS account or credentials. They check the network layout, the version and the add-ons, and
# that the public API endpoint can never be opened to the whole internet.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:role/ci"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::111122223333:role/ci"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "tls" {}
mock_provider "time" {}

variables {
  name              = "test"
  azs               = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  api_allowed_cidrs = ["203.0.113.10/32"]
}

run "cluster_and_network" {
  command = plan

  assert {
    condition     = module.vpc.private_subnets_cidr_blocks == tolist(["10.10.0.0/20", "10.10.16.0/20", "10.10.32.0/20"])
    error_message = "One private /20 per availability zone, carved from the VPC CIDR."
  }

  assert {
    condition     = output.cluster_name == "test"
    error_message = "The cluster takes the given name."
  }

  assert {
    condition     = var.kubernetes_version == "1.36"
    error_message = "Default to a Kubernetes version in EKS standard support."
  }
}

run "rejects_api_open_to_the_internet" {
  command = plan

  variables {
    api_allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.api_allowed_cidrs]
}

run "rejects_an_empty_api_allowlist" {
  command = plan

  variables {
    api_allowed_cidrs = []
  }

  expect_failures = [var.api_allowed_cidrs]
}
