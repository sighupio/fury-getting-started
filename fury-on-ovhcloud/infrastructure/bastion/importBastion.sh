#!/bin/bash
  
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${DIR}

source ../utils/ovhrc
source ../properties

terraform init

# Import Bastion Instance
echo "TODO"
