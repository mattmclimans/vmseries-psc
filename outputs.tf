output "VMSERIES_MGMT" {
  description = "Management URL for vmseries01."
  value       = "https://${module.vmseries["vmseries01"].public_ips[1]}"
}

output "VMSERIES_UNTRUST" {
  description = "Untrust public IP assigned to vmseries01."
  value       = module.vmseries["vmseries01"].public_ips[0]
}