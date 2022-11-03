resource "openstack_compute_instance_v2" "myBastion" {
  name            		= var.bastionName
  flavor_name     		= var.bastionFlavor
  image_name      		= var.bastionImage
  key_pair        		= var.keypairName
  security_groups 		= ["default"]
  user_data       		= file("${path.module}/user-data-bastion.sh")

  network {
    name = "Ext-Net"
  }

  network {
    name 			= var.pvNetworkName
    fixed_ip_v4 		= var.bastionIP
  }
}

resource "null_resource" "ssh_config" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "cat ${path.module}/ssh_config.tpl | sed -e 's/TF_VAR_bastionIP/${openstack_compute_instance_v2.myBastion.network[0].fixed_ip_v4}/g' -e 's/TF_VAR_keypairName/${var.keypairName}/g' -e 's/TF_VAR_bastionUser/${var.bastionUser}/g' -e 's/TF_VAR_bastionName/${var.bastionName}/g' > ~/.ssh/ssh_config_${var.bastionName}"
  }
}
