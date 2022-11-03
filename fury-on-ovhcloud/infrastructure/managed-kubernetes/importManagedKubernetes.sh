#!/bin/bash
  
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${DIR}

source ../utils/ovhrc
source ../properties

terraform init

# Import Private Network
nid=$(${DIR}/../utils/ovhAPI.sh GET /cloud/project/$TF_VAR_serviceName/network/private | jq --arg TF_VAR_pvNetworkName $TF_VAR_pvNetworkName -r '.[] | select(.name==$TF_VAR_pvNetworkName) | .id')
terraform import ovh_cloud_project_network_private.myPrivateNetwork "${TF_VAR_serviceName}/${nid}"

# Get kubeid from k8sName var
for tid in $(../utils/ovhAPI.sh GET /cloud/project/$TF_VAR_serviceName/kube |jq -r '.[]')
do 
	tjson="$(../utils/ovhAPI.sh GET /cloud/project/$TF_VAR_serviceName/kube/$tid)"
	tname="$(echo $tjson | jq -r '.name')"
	if [ "${TF_VAR_k8sName}" == "${tname}" ]
	then
		export kubeid="$(echo $tjson | jq -r '.id')"
	fi
done

# Import Managed Kubernetes
terraform import ovh_cloud_project_kube.myManagedKubernetes ${TF_VAR_serviceName}/${kubeid}

# Import Nodes Pool
poolid="$(../utils/ovhAPI.sh GET /cloud/project/$TF_VAR_serviceName/kube/${kubeid}/nodepool | jq -r '.[] | .id')"
terraform import ovh_cloud_project_kube_nodepool.myManagedKubernetesPool ${TF_VAR_serviceName}/${kubeid}/${poolid}
