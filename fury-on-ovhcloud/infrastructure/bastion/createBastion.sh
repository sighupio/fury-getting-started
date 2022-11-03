#!/bin/bash
  
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${DIR}

source ../utils/ovhrc
source ../properties

terraform init

# Create user-data-bastion.sh from template
cat user-data-bastion.sh.tpl | sed -e "s|TF_VAR_bastionIP|$TF_VAR_bastionIP|g" -e "s|TF_VAR_subnetCIDR|$TF_VAR_subnetCIDR|g" -e "s|TF_VAR_rtrIp|$TF_VAR_rtrIp|g" > user-data-bastion.sh

terraform plan
terraform apply --auto-approve
