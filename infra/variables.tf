variable "project_id" {
  description = "Google Cloud project that runs GatherInsight."
  type        = string
  default     = "gatherinsight"
}

variable "project_number" {
  description = "Numeric id of the project (used in Workload Identity principal names)."
  type        = string
  default     = "1021483580038"
}

variable "region" {
  description = "Region for Cloud Run, Cloud SQL, Artifact Registry and Cloud Scheduler."
  type        = string
  default     = "asia-southeast1"
}

variable "zone" {
  description = "Zone of the TURN relay VM."
  type        = string
  default     = "asia-southeast1-b"
}

variable "github_owner_id" {
  description = "Numeric GitHub id of the account that owns the repositories allowed to deploy."
  type        = string
  default     = "64614565"
}

variable "github_repos" {
  description = "Repositories (owner/name) whose GitHub Actions may exchange tokens with Google Cloud."
  type        = map(string)
  default = {
    app      = "baldan555/gatherinsight"          # private: the application
    platform = "baldan555/gatherinsight-platform" # public: this repository
  }
}

variable "github_repo_ids" {
  description = "Numeric GitHub ids of the same repositories (ids never change, names can)."
  type        = map(string)
  default = {
    app      = "1460985591"
    platform = "1460997570"
  }
}

variable "app_domain" {
  description = "Custom domain of the web application."
  type        = string
  default     = "app.gatherinsight.baldanproject.my.id"
}

variable "landing_domain" {
  description = "Custom domain of the public landing page."
  type        = string
  default     = "gatherinsight.baldanproject.my.id"
}

variable "app_url" {
  description = "Address the app signs users in on and that Cloud Scheduler calls."
  type        = string
  default     = "https://gatherinsight-pmrvdosmoq-as.a.run.app"
}
