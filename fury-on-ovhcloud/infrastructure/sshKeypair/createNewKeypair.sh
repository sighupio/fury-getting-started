#!/bin/bash
  
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${DIR}

source ../utils/ovhrc
source ../properties

# Create a new SSH keypair
ssh-keygen -t rsa -b 4096 -f $TF_VAR_keypairName
export TF_VAR_keypairPubKey="$(cat ${TF_VAR_keypairName}.pub)"

terraform init
terraform plan
terraform apply --auto-approve
