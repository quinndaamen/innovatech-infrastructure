terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.11.0"
    }
  }
  backend "gcs" {
    bucket = "innovatech-solutions-514610-tfstate"
    prefix = "innovatech/platform"

  }

}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}