terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.11"
    }
  }

  # State lives in a private, versioned bucket (created once by hand, then adopted below in storage.tf).
  backend "gcs" {
    bucket = "gatherinsight-tfstate"
    prefix = "platform"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
