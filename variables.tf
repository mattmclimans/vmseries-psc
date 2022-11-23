variable "project_id" {
  description = "GCP project ID"
  default     = null
}
variable "prefix" {
  description = "Arbitrary string used to prefix resource names."
  type        = string
  default     = null
}
variable "region" {
  description = "Google Cloud region for the created resources."
  type        = string
  default     = null
}
variable "fw_machine_type" {
  description = "The Google Cloud machine type for the VM-Series NGFW."
  type        = string
  default     = "n1-standard-4"
}

variable "fw_image_name" {
  description = "The image name from which to boot an instance, including the license type and the version, e.g. vmseries-byol-814, vmseries-bundle1-814, vmseries-flex-bundle2-1001. Default is vmseries-flex-bundle1-913."
  type        = string
  default     = "vmseries-flex-byol-1014"
}

variable "allowed_sources" {
  description = "A list of IP addresses to be added to the management network's ingress firewall rule. The IP addresses will be able to access to the VM-Series management interface."
  type        = list(string)
  default     = null
}

variable "cidr_mgmt" {
  description = "The CIDR range of the management subnetwork."
  type        = string
  default     = null
}
variable "cidr_untrust" {
  description = "The CIDR range of the untrust subnetwork."
  type        = string
  default     = null
}
variable "cidr_trust" {
  description = "The CIDR range of the trust subnetwork."
  type        = string
  default     = null
}