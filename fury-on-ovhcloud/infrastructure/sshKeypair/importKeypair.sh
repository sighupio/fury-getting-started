#!/bin/bash
  
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${DIR}

source ../utils/ovhrc
source ../properties

export TF_VAR_keypairPubKey="$(cat ${TF_VAR_keypairName}.pub)"

terraform init

terraform import openstack_compute_keypair_v2.myKeypair ${TF_VAR_keypairName}
