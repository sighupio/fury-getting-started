#!/bin/bash
  
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${DIR}

source ../utils/ovhrc
source ../properties

# Remove Private Network from state
terraform state rm ovh_cloud_project_network_private.myPrivateNetwork

terraform destroy --auto-approve
