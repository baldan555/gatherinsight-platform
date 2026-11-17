# TURN relay for recorded phone interviews: browsers behind strict NATs relay their audio through it.
# A tiny VM (e2-micro) that is stopped when calls are not being demoed.

resource "google_compute_address" "turn" {
  name         = "gi-turn-ip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"

  lifecycle {
    prevent_destroy = true # the app's CALL_TURN_URLS points at this address
  }
}

resource "google_compute_instance" "turn" {
  name         = "gi-turn"
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = ["gi-turn"]

  boot_disk {
    auto_delete = true
    device_name = "persistent-disk-0"
    source      = "https://www.googleapis.com/compute/v1/projects/${var.project_id}/zones/${var.zone}/disks/gi-turn"
  }

  network_interface {
    network    = "default"
    subnetwork = "default"
    network_ip = "10.148.0.2"
    stack_type = "IPV4_ONLY"

    access_config {
      nat_ip       = google_compute_address.turn.address
      network_tier = "PREMIUM"
    }
  }

  # Installs coturn and reads the shared secret from Secret Manager at boot (nothing secret in metadata).
  metadata = {
    enable-oslogin = "TRUE"
    startup-script = file("${path.module}/files/turn-startup.sh")
  }

  service_account {
    email  = google_service_account.turn.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"] # access is limited by IAM, not scopes
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    ignore_changes = [desired_status] # started and stopped by hand around demos
  }
}

# Only the TURN ports are open; SSH comes through Identity-Aware Proxy only; RDP/SSH from the internet are denied
# even though the default network allows them.
resource "google_compute_firewall" "turn_allow" {
  name          = "gi-turn-allow"
  network       = "default"
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gi-turn"]

  allow {
    protocol = "tcp"
    ports    = ["3478"]
  }
  allow {
    protocol = "udp"
    ports    = ["3478"]
  }
  allow {
    protocol = "udp"
    ports    = ["49152-49252"]
  }
}

resource "google_compute_firewall" "turn_iap" {
  name          = "gi-turn-allow-iap"
  network       = "default"
  direction     = "INGRESS"
  priority      = 800
  source_ranges = ["35.235.240.0/20"] # Identity-Aware Proxy
  target_tags   = ["gi-turn"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "turn_deny" {
  name          = "gi-turn-deny-admin"
  network       = "default"
  direction     = "INGRESS"
  priority      = 900
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gi-turn"]

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }
  deny {
    protocol = "tcp"
    ports    = ["3389"]
  }
}
