terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.44.0"
    }

    terracurl = {
      source  = "devops-rob/terracurl"
      version = "2.3.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
  }
}

provider "aws" {
  # get from env variables
}