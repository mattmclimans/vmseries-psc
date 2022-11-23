# ----------------------------------------------------------------------------------------------------------------
# Setup providers, pull availability zones, and create name prefix.

terraform {
  required_version = ">= 0.15.3, < 2.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "main" {
}

data "google_compute_zones" "main" {
  project = data.google_client_config.main.project
  region  = var.region
}

resource "random_string" "main" {
  length    = 5
  min_lower = 5
  special   = false
}

locals {
  prefix = var.prefix != null && var.prefix != "" ? "${var.prefix}-" : ""

  vmseries_vms = {
    vmseries01 = {
      zone = data.google_compute_zones.main.names[0]
    }
  }
}


# ----------------------------------------------------------------------------------------------------------------
# Create mgmt, untrust, and trust networks

module "vpc_mgmt" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 4.0"
  project_id   = var.project_id
  network_name = "${local.prefix}mgmt-vpc"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name   = "${local.prefix}${var.region}-mgmt"
      subnet_ip     = var.cidr_mgmt
      subnet_region = var.region
    }
  ]

  firewall_rules = [
    {
      name        = "${local.prefix}vmseries-mgmt"
      direction   = "INGRESS"
      priority    = "100"
      description = "Allow ingress access to VM-Series management interface"
      ranges      = var.allowed_sources
      allow = [
        {
          protocol = "tcp"
          ports    = ["22", "443"]
        }
      ]
    }
  ]
}

module "vpc_untrust" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 4.0"
  project_id   = var.project_id
  network_name = "${local.prefix}untrust-vpc"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name   = "${local.prefix}${var.region}-untrust"
      subnet_ip     = var.cidr_untrust
      subnet_region = var.region
    }
  ]

  firewall_rules = [
    {
      name      = "${local.prefix}allow-all-untrust"
      direction = "INGRESS"
      priority  = "100"
      ranges    = ["0.0.0.0/0"]
      allow = [
        {
          protocol = "all"
          ports    = []
        }
      ]
    }
  ]
}

module "vpc_trust" {
  source                                 = "terraform-google-modules/network/google"
  version                                = "~> 4.0"
  project_id                             = var.project_id
  network_name                           = "${local.prefix}trust-vpc"
  routing_mode                           = "GLOBAL"
  delete_default_internet_gateway_routes = true

  subnets = [
    {
      subnet_name   = "${local.prefix}${var.region}-trust"
      subnet_ip     = var.cidr_trust
      subnet_region = var.region
    }
  ]

  firewall_rules = [
    {
      name      = "${local.prefix}allow-all-trust"
      direction = "INGRESS"
      priority  = "100"
      ranges    = ["0.0.0.0/0"]
      allow = [
        {
          protocol = "all"
          ports    = []
        }
      ]
    }
  ]
}


# ----------------------------------------------------------------------------------------------------------------
# Create VM-Series

# Create IAM service account for accessing bootstrap bucket
module "iam_service_account" {
  source = "PaloAltoNetworks/vmseries-modules/google//modules/iam_service_account"

  service_account_id = "${local.prefix}vmseries-sa"
}

# Create storage bucket to bootstrap VM-Series.
module "bootstrap" {
  source = "PaloAltoNetworks/vmseries-modules/google//modules/bootstrap"

  service_account = module.iam_service_account.email
  files = {
    "bootstrap_files/init-cfg.txt.sample"  = "config/init-cfg.txt"
    "bootstrap_files/bootstrap.xml.sample" = "config/bootstrap.xml"
  }
}

# Create 2 VM-Series firewalls
module "vmseries" {
  for_each = local.vmseries_vms
  source   = "PaloAltoNetworks/vmseries-modules/google//modules/vmseries"

  name                  = "${local.prefix}${each.key}"
  zone                  = each.value.zone
  ssh_keys              = null #fileexists(var.public_key_path) ? "admin:${file(var.public_key_path)}" : ""
  vmseries_image        = var.fw_image_name
  create_instance_group = true

  metadata = {
    mgmt-interface-swap                  = "enable"
    vmseries-bootstrap-gce-storagebucket = module.bootstrap.bucket_name
    serial-port-enable                   = true
  }

  network_interfaces = [
    {
      subnetwork       = module.vpc_untrust.subnets_self_links[0]
      create_public_ip = true
    },
    {
      subnetwork       = module.vpc_mgmt.subnets_self_links[0]
      create_public_ip = true
    },
    {
      subnetwork = module.vpc_trust.subnets_self_links[0]
    }
  ]

  scopes = [
  "https://www.googleapis.com/auth/compute.readonly",
  "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
  "https://www.googleapis.com/auth/devstorage.read_only",
  "https://www.googleapis.com/auth/logging.write",
  "https://www.googleapis.com/auth/monitoring.write",
  "https://www.googleapis.com/auth/cloud-platform"
]

  depends_on = [
    module.bootstrap
  ]
}


