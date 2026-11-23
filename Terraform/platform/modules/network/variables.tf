variable "region" {
  type    = string
  default = "europe-west4"
}

variable "zone" {
  type    = string
  default = "europe-west4-a"
}

variable "nodes_cidr" {
    type = string
    description = "cidr range of the node subnet"
}



variable "pods_cidr" {
    type = string
    description = "cidr range of the pods subnet"
}

variable "services_cidr" {
    type = string
    description = "cidr range of the services subnet"
}

variable "nodes_name" {
  type = string
  description = "name of the nodes subnet"
}


variable "pods_name" {
  type = string
  description = "name of the pods subnet"
}


variable "services_name" {
  type = string
  description = "name of the services subnet"
}

variable "node_tag" {
  type    = string
  default = "innovatech-gke-node"
}

variable "lb_backend_ports" {
  type    = list(string)
  default = ["80", "8080", "4180"]
}