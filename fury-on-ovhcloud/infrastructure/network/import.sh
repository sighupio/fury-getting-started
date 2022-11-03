#!/bin/bash
  
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${DIR}

source ../utils/ovhrc
source ../properties

terraform init

# Import Router
rtrId="$(openstack router show rtr-apps -f json | jq -r '.id')"
terraform import openstack_networking_router_v2.rtr-apps "${rtrId}"

exit 0

# Import Interface
intId="$(openstack port list --router ${rtrId} | grep -w '192.168.1.1' | awk '{print $2}')"
terraform import openstack_networking_router_interface_v2.rtr-apps-int-0 "${intId}"

# Import Subnet
terraform import openstack_networking_subnet_v2.subnet_apps "$(openstack subnet list | grep "subnet_apps" | awk '{print $2}')"

# Import Private Network
nid=$(${DIR}/ovhAPI.sh GET /cloud/project/$TF_VAR_serviceName/network/private | jq -r '.[] | select(.name=="pvnw_apps") | .id')
terraform import ovh_cloud_project_network_private.pvnw_apps "${TF_VAR_serviceName}/${nid}"

# Import Ext-Net Subnet
terraform import openstack_networking_network_v2.Ext-Net "$(openstack network list | grep -w "Ext-Net" | grep -v "Baremetal" | awk '{print $2}')"
