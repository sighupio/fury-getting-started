#!/bin/bash
  
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${DIR}

source ../utils/ovhrc
source ../properties

terraform init

# Import Private Network
nid=$(${DIR}/../utils/ovhAPI.sh GET /cloud/project/$TF_VAR_serviceName/network/private | jq --arg TF_VAR_pvNetworkName $TF_VAR_pvNetworkName -r '.[] | select(.name==$TF_VAR_pvNetworkName) | .id')
terraform import ovh_cloud_project_network_private.myPrivateNetwork "${TF_VAR_serviceName}/${nid}"

terraform plan
terraform apply --auto-approve
