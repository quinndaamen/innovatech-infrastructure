# Static IP of the load balancer. It lives outside the gke module,
# so it survives when the cluster is destroyed.
resource "google_compute_global_address" "innovatech_address" {
  name         = "innovatech-address"
  address_type = "EXTERNAL"
}

resource "google_dns_managed_zone" "innovatech_zone" {
  name        = "innovatech-zone"
  dns_name    = "innovatech.qvnn.me."
  description = "Innovatech project zone, delegated from qvnn.me"

  lifecycle {
    prevent_destroy = true
  }

}

resource "google_dns_record_set" "portal" {
  name         = "portal.${google_dns_managed_zone.innovatech_zone.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.innovatech_zone.name
  rrdatas      = [google_compute_global_address.innovatech_address.address]
}

resource "google_dns_record_set" "keycloak" {
  name         = "keycloak.${google_dns_managed_zone.innovatech_zone.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.innovatech_zone.name
  rrdatas      = [google_compute_global_address.innovatech_address.address]
}

# One wildcard record for every desktop: jan.desktops..., anna.desktops...
resource "google_dns_record_set" "desktops" {
  name         = "*.desktops.${google_dns_managed_zone.innovatech_zone.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.innovatech_zone.name
  rrdatas      = [google_compute_global_address.innovatech_address.address]
}

