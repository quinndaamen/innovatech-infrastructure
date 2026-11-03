module "network" {
  source = "../../modules/network"

  environment         = "dev"
  compute_vpc_cidr    = "10.1.0.0/16"
  database_vpc_cidr   = "10.2.0.0/16"
  monitoring_vpc_cidr = "10.3.0.0/16"
  onprem_vpc_cidr     = "10.50.0.0/16"
}
module "compute" {
  source = "../../modules/compute"

  environment = "dev"

  vpc_id = module.network.compute_vpc_id

  public_subnet_ids = module.network.compute_public_subnet_ids

  private_subnet_ids = module.network.compute_private_subnet_ids

  database_endpoint   = module.database.aurora_endpoint
  database_port       = module.database.aurora_port
  database_name       = module.database.database_name
  database_username   = module.database.database_username
  database_secret_arn = module.database.database_secret_arn
}

module "database" {
  source = "../../modules/database"

  environment        = "dev"
  vpc_id             = module.network.database_vpc_id
  private_subnet_ids = module.network.database_private_subnet_ids

  allowed_web_subnet_cidrs = [
    "10.1.11.0/24",
    "10.1.12.0/24"
  ]

  master_password = var.database_master_password
}

module "monitoring" {
  source      = "../../modules/monitoring"
  environment = "dev"

  vpc_id = module.network.monitoring_vpc_id

  private_subnet_ids = module.network.monitoring_private_subnet_ids

  elasticsearch_instance_type = "t3.medium"
  logstash_instance_type      = "t3.small"
  kibana_instance_type        = "t3.small"

  elasticsearch_volume_size = 50
  logstash_volume_size      = 20
  kibana_volume_size        = 20

  elastic_version = "9.5.5"
}

module "onprem_sim" {
  source = "../../modules/onprem-sim"

  environment        = "dev"
  vpc_id             = module.network.onprem_vpc_id
  private_subnet_ids = module.network.onprem_private_subnet_ids
  public_subnet_id   = module.network.onprem_public_subnet_id
}