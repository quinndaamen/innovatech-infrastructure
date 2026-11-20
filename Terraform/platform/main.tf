module "network" {
  source     = "./modules/network"
  region     = var.region
  depends_on = [google_project_service.apis]

  nodes_cidr    = "10.10.0.0/24"
  pods_cidr     = "10.20.0.0/16"
  services_cidr = "10.30.0.0/24"

  nodes_name    = "innovatech-gke-subnet"
  pods_name     = "innovatech-pods-subnet"
  services_name = "innovatech-services-subnet"


}

module "gke" {
  source     = "./modules/gke"
  project_id = var.project_id
  zone       = var.zone

  network    = module.network.innovatech_vpc_id
  subnetwork = module.network.gke_subnet_id

  pods_name     = module.network.pods_range_name
  services_name = module.network.services_range_name

  node_tags = [module.network.node_tag]

  myip       = var.myip
  depends_on = [module.network]
}

module "database" {
  source  = "./modules/database"
  network = module.network.innovatech_vpc_id
  address = "10.40.0.0"
  region  = var.region

}