resource "ovh_cloud_project_network_private" "myPrivateNetwork" {
   service_name         			= var.serviceName
   name                 			= var.pvNetworkName
   vlan_id              			= var.pvNetworkId
   regions              			= [var.region]
}

resource "ovh_cloud_project_kube" "myManagedKubernetes" {
    service_name  				= var.serviceName
    name          				= var.k8sName
    region        				= var.region
    version					= var.k8sVersion

    private_network_id = tolist(ovh_cloud_project_network_private.myPrivateNetwork.regions_attributes[*].openstackid)[0]

    private_network_configuration {
        default_vrack_gateway			= var.rtrIp
        private_network_routing_as_default 	= true
    }

    depends_on = [
        ovh_cloud_project_network_private.myPrivateNetwork
    ]
}

resource "ovh_cloud_project_kube_nodepool" "myManagedKubernetesPool" {
  service_name  				= var.serviceName
  kube_id       				= ovh_cloud_project_kube.myManagedKubernetes.id
  name          				= var.k8sPoolName
  flavor_name   				= var.k8sPoolFlavor
  desired_nodes 				= var.k8sPoolDesiredNodes
  max_nodes     				= var.k8sPoolMaxNodes
  min_nodes     				= var.k8sPoolMinNodes
}
