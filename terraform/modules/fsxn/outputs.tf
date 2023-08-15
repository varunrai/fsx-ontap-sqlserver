output "fsx_management_management_ip" {
  description = "FSxN Management IP"
  value       = aws_fsx_ontap_file_system.fsx_ontap_fs.endpoints[0].management[0].ip_addresses
}

output "fsx_svm" {
  description = "FSxN SVM Info"
  value       = aws_fsx_ontap_storage_virtual_machine.fsxsvm01
}

output "fsx_svm_iscsi_endpoints" {
  description = "FSxN SVM iSCSI endpoints"
  value       = aws_fsx_ontap_storage_virtual_machine.fsxsvm01.endpoints[0].iscsi[0].ip_addresses
}

output "fsx_volume" {
  description = "FSxN Volume"
  value       = aws_fsx_ontap_volume.fsxvol01
}
