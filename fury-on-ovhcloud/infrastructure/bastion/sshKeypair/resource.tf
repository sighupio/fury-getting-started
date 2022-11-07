resource "openstack_compute_keypair_v2" "myKeypair" {
  name       		= var.keypairName
  public_key 		= var.keypairPubKey
}
