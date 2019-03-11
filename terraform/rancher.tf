# instance the provider
provider "libvirt" {
  uri = "qemu:///system"
}

# We fetch the latest rancher release image from their mirrors
resource "libvirt_volume" "rancher-qcow2" {
  name   = "rancher${count.index}.qcow2"
  pool   = "default"
  source = "https://releases.rancher.com/os/v1.5.1/rancheros-openstack.img"
  format = "qcow2"
  count  = 4
}

# Create a network for our VMs
resource "libvirt_network" "vm_network" {
  name      = "vm_network"
  addresses = ["10.20.30.0/24"]
}

# Use CloudInit to add our ssh-key to the instance
resource "libvirt_cloudinit" "rancherinit" {
  name               = "rancher${count.index}init.iso"
  hostname           = "rancher${count.index}"
  ssh_authorized_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDb3ue9DHBt22Dbc538q+83xi4y0z53K1yoS/mTuXakMRUlI7KbcJTM0mVPuPagPt+hceK0gip5BZFoWkn8lM1M+sn4BFuVNLN0QXoFDvCXCz5vzviRs9CnS1kp/kDrHMIpzDBR8T2p+a1D1aFuOQblmzRBHepRH9FRJbDQCYZpNcila//Y3kFB5bonjVFjdm0ZlTTCFZSSB0eITuSrs3HRqSMSYBsvyys5Wm/BAlzi3Nghv4RIEz8cSFLWUtovTkM/8TSRUV5oUg3UnRvQcmnHe8iq9qSOxHf3AIsV/5fVYHg4Uxz+TZKrf6B9FWUB1HruiT+ubYpA5GTef0LcqNPb ezhenwe@elx22scj32-c0"
  count              = 4

  user_data = <<USER_DATA
rancher:
  docker:
    engine: docker-18.06.1-ce
  network:
    dns:
      nameservers:
      - 8.8.8.8
      - 8.8.4.4
    interfaces:
      eth0:
        address: 10.20.30.1${count.index}/24
        gateway: 10.20.30.1

USER_DATA
}

# Create the machine
resource "libvirt_domain" "rancher" {
  name   = "rancher${count.index}-terraform"
  memory = "4096"
  vcpu   = 2
  count  = 4

  cloudinit = "${element(libvirt_cloudinit.rancherinit.*.id, count.index)}"

  network_interface {
    network_name = "vm_network"
  }

  # IMPORTANT
  # Rancher can hang is a isa-serial is not present at boot time.
  # If you find your CPU 100% and never is available this is why
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = "${element(libvirt_volume.rancher-qcow2.*.id, count.index)}"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = "true"
  }
}

# Print the Boxes IP
# Note: you can use `virsh domifaddr <vm_name> <interface>` to get the ip later
#output "ip0" {
#  value = "${libvirt_domain.rancher.0.network_interface.0.addresses.0}"
#}


#output "ip1" {
#  value = "${libvirt_domain.rancher.1.network_interface.0.addresses.0}"
#}


#output "ip2" {
#  value = "${libvirt_domain.rancher.2.network_interface.0.addresses.0}"
#}


#output "ip3" {
#  value = "${libvirt_domain.rancher.3.network_interface.0.addresses.0}"
#}

