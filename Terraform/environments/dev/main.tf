module "network" {
  source = "../../modules/network"

  environment         = "dev"
  compute_vpc_cidr    = "10.1.0.0/16"
  database_vpc_cidr   = "10.2.0.0/16"
  monitoring_vpc_cidr = "10.3.0.0/16"
}