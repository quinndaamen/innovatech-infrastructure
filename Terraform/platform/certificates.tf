
locals {
  domain = "innovatech.qvnn.me"
}


resource "google_certificate_manager_dns_authorization" "main" {
  name        = "innovatech-dns-auth"
  description = "Ownership proof for ${local.domain}"
  domain      = local.domain

  depends_on = [google_project_service.apis]

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_certificate_manager_dns_authorization" "desktops" {
  name        = "innovatech-desktops-dns-auth"
  description = "Ownership proof for desktops.${local.domain}"
  domain      = "desktops.${local.domain}"

  depends_on = [google_project_service.apis]


  lifecycle {
    prevent_destroy = true
  }
}

# --- CNAME records that prove ownership, created in your own Cloud DNS zone -----
resource "google_dns_record_set" "dns_auth_main" {
  name         = google_certificate_manager_dns_authorization.main.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.main.dns_resource_record[0].type
  ttl          = 300
  managed_zone = google_dns_managed_zone.innovatech_zone.name
  rrdatas      = [google_certificate_manager_dns_authorization.main.dns_resource_record[0].data]

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_dns_record_set" "dns_auth_desktops" {
  name         = google_certificate_manager_dns_authorization.desktops.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.desktops.dns_resource_record[0].type
  ttl          = 300
  managed_zone = google_dns_managed_zone.innovatech_zone.name
  rrdatas      = [google_certificate_manager_dns_authorization.desktops.dns_resource_record[0].data]

  lifecycle {
    prevent_destroy = true
  }
}

# --- The certificate itself ---------------------------------------------------------
# A wildcard covers ONE label: *.innovatech.qvnn.me covers portal and keycloak,
# *.desktops.innovatech.qvnn.me covers jan.desktops.innovatech.qvnn.me.
resource "google_certificate_manager_certificate" "innovatech" {
  name        = "innovatech-cert"
  description = "Wildcard certificate for the portal, Keycloak and the desktops"

  managed {
    domains = [
      "*.${local.domain}",
      "*.desktops.${local.domain}",
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.main.id,
      google_certificate_manager_dns_authorization.desktops.id,
    ]
  }

  depends_on = [
    google_dns_record_set.dns_auth_main,
    google_dns_record_set.dns_auth_desktops,
  ]
  lifecycle {
    prevent_destroy = true
  }

}

# --- Certificate map: what the Gateway points at -----------------------------------
resource "google_certificate_manager_certificate_map" "innovatech" {
  name        = "innovatech-cert-map"
  description = "Certificate map for the Innovatech Gateway"
  depends_on  = [google_project_service.apis]

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_certificate_manager_certificate_map_entry" "innovatech" {
  name         = "innovatech-cert-map-entry"
  description  = "Default entry: the wildcard certificate"
  map          = google_certificate_manager_certificate_map.innovatech.name
  certificates = [google_certificate_manager_certificate.innovatech.id]
  matcher      = "PRIMARY"
  depends_on   = [google_project_service.apis]

  lifecycle {
    prevent_destroy = true
  }
}

output "certificate_map_name" {
  value = google_certificate_manager_certificate_map.innovatech.name
}
