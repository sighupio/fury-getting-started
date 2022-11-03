#!/bin/bash
  
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${DIR}

source ../utils/ovhrc
source ../properties

export TF_VAR_keypairPubKey="$(cat ${TF_VAR_keypairName}.pub)"

terraform destroy --auto-approve
