./uninstall-aws-alb.sh
terraform state rm kubernetes_config_map.aws_auth
terraform destroy -auto-approve
rm -rf .terraform
rm -rf .terraform.lock.hcl
rm -rf terraform.tfstate
rm -rf terraform.tfstate.*.backup
rm -rf terraform.tfstate.backup