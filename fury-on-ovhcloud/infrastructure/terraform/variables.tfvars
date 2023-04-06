# Region

region = "GRA7"

# Network - Private Network

network = {
  name = "furyNetwork"
}

# Network - Subnet

subnet = {
  name       = "furySubnet"
  cidr       = "10.0.0.0/24"
  dhcp_start = "10.0.0.100"
  dhcp_end   = "10.0.0.254"
}

# Network - Router

router = {
  name = "furyRouter"
}

# Managed Kubernetes Cluster

kube = {
  name            = "furykubernetesCluster"
  pv_network_name = "furyNetwork"
  version         = "1.25"
  gateway_ip      = "10.0.0.1"
}

pool = {
  name          = "furypool"
  flavor        = "b2-7"
  desired_nodes = "3"
  max_nodes     = "6"
  min_nodes     = "3"
}

