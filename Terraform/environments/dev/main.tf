module "network" {
  source = "../../modules/network"

  environment         = "dev"
  compute_vpc_cidr    = "10.1.0.0/16"
  database_vpc_cidr   = "10.2.0.0/16"
  monitoring_vpc_cidr = "10.3.0.0/16"
}

module "compute" {
  source = "../../modules/compute"

  environment = "dev"

  vpc_id = module.network.compute_vpc_id

  public_subnet_ids = module.network.compute_public_subnet_ids

  private_subnet_ids = module.network.compute_private_subnet_ids
}