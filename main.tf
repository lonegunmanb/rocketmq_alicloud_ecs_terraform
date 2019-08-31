variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "az" {
  type = list(string)
}
variable "intranet_open_ports" {
  type = list(number)
}
variable "internet_open_ports" {
  type = list(number)
}
variable data_disk_type {
  default = "cloud_essd"
}
variable "data_disk_size" {
  type = number
}
variable broker_instance_type {
  default = "ecs.c5.xlarge"
}
variable "broker_image_id" {}
variable "broker_password" {}
variable "namesvr_instance_type" {
  default = "ecs.g5.large"
}
variable "namesvr_image_id" {}
variable "namesvr_password" {}
variable "rktmq_image" {}

variable "pressure_image_id" {}
variable "pressure_password" {}

provider "alicloud" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

resource "alicloud_vpc" "vpc" {
  name       = "rktmqVpc"
  cidr_block = "172.16.0.0/12"
}

resource "alicloud_vswitch" "switch" {
  count             = 3
  vpc_id            = alicloud_vpc.vpc.id
  cidr_block        = "172.16.${count.index}.0/24"
  availability_zone = var.az[count.index]
}

resource "alicloud_security_group" "group" {
  name        = "rktmqSg"
  description = "rktmqSg"
  vpc_id      = alicloud_vpc.vpc.id
}

resource "alicloud_security_group_rule" "intranet_all_deny" {
  ip_protocol       = "tcp"
  security_group_id = alicloud_security_group.group.id
  type              = "ingress"
  nic_type          = "intranet"
  policy            = "drop"
  port_range        = "1/65535"
  priority          = 100
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "intranet_allow_tcp" {
  count             = length(var.intranet_open_ports)
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "${var.intranet_open_ports[count.index]}/${var.intranet_open_ports[count.index]}"
  priority          = 1
  security_group_id = alicloud_security_group.group.id
  cidr_ip           = alicloud_vpc.vpc.cidr_block
}

resource "alicloud_security_group_rule" "internet_allow_tcp" {
  count             = length(var.internet_open_ports)
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "${var.internet_open_ports[count.index]}/${var.internet_open_ports[count.index]}"
  priority          = 1
  security_group_id = alicloud_security_group.group.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_disk" "ecs_disk" {
  count             = 3
  # cn-beijing
  availability_zone = var.az[count.index]
  name              = "rktmq-data-disk-${count.index}"
  description       = "rktmq-data-disk-${count.index}"
  category          = var.data_disk_type
  size              = var.data_disk_size
}

resource "alicloud_instance" "broker" {
  count             = 3
  availability_zone = var.az[count.index]
  security_groups   = [
    alicloud_security_group.group.id]

  # series III
  instance_type              = var.broker_instance_type
  system_disk_category       = "cloud_efficiency"
  image_id                   = var.broker_image_id
  system_disk_size           = 20
  instance_name              = "broker-${count.index}"
  vswitch_id                 = alicloud_vswitch.switch.*.id[count.index]
  internet_max_bandwidth_out = 100
  password                   = var.broker_password
}

resource "alicloud_disk_attachment" "ecs_disk_att" {
  count       = 3
  disk_id     = alicloud_disk.ecs_disk.*.id[count.index]
  instance_id = alicloud_instance.broker.*.id[count.index]
}

resource "alicloud_instance" "namesvr" {
  availability_zone = var.az[0]
  security_groups   = [
    alicloud_security_group.group.id]

  # series III
  instance_type              = var.namesvr_instance_type
  system_disk_category       = "cloud_efficiency"
  image_id                   = var.namesvr_image_id
  system_disk_size           = 20
  instance_name              = "namesvr"
  vswitch_id                 = alicloud_vswitch.switch.*.id[0]
  internet_max_bandwidth_out = 100
  password                   = var.namesvr_password
}

resource "null_resource" "setup_namesvr" {
  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = alicloud_instance.namesvr.public_ip
      user     = "root"
      password = var.namesvr_password
    }
    inline = [
      file("./add_docker.sh"),
      "docker run -d -p 9876:9876 ${var.rktmq_image} ./mqnamesrv"
    ]
  }
}

data "template_file" "make_broker_config" {
  count = 3
  template = file("./make_broker_config.sh")
  vars = {
    index = count.index
    namesvr = alicloud_instance.namesvr.private_ip
    broker0 = alicloud_instance.broker.*.private_ip[0]
    broker1 = alicloud_instance.broker.*.private_ip[1]
    broker2 = alicloud_instance.broker.*.private_ip[2]
    broker_ip = alicloud_instance.broker.*.private_ip[count.index]
  }
}

resource "null_resource" "setup_broker" {
  count = 3
  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = alicloud_instance.broker.*.public_ip[count.index]
      user     = "root"
      password = var.broker_password
    }
    inline = [
      "mkfs.xfs /dev/vdb",
      "mkdir /data",
      "mount /dev/vdb /data",
      file("./add_docker.sh"),
      data.template_file.make_broker_config.*.rendered[count.index],
      "docker run -d -u 0 -p 30911:30911 -p 40911:40911 -p 30909:30909 -v /cfg:/cfg -v /data:/data ${var.rktmq_image} ./mqbroker -c /cfg/broker.conf"
    ]
  }
}

resource "alicloud_instance" "pressure" {
  availability_zone = var.az[0]
  security_groups   = [
    alicloud_security_group.group.id
  ]

  # series III
  instance_type              = "ecs.c5.xlarge"
  system_disk_category       = "cloud_efficiency"
  image_id                   = var.broker_image_id
  system_disk_size           = 20
  instance_name              = "pressure"
  vswitch_id                 = alicloud_vswitch.switch.*.id[0]
  internet_max_bandwidth_out = 100
  password                   = var.pressure_password
}

data "template_file" "setup_pressure" {
  template = file("./setup_pressure.sh")
  vars = {
    namesvr = alicloud_instance.namesvr.private_ip
  }
}

resource "null_resource" "setup_pressure" {
  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = alicloud_instance.pressure.public_ip
      user     = "root"
      password = var.pressure_password
    }
    inline = [
      data.template_file.setup_pressure.rendered
    ]
  }
}

output namesvr_ip {
  value = alicloud_instance.namesvr.public_ip
}

output pressure_ip {
  value = alicloud_instance.pressure.public_ip
}

output broker_ips {
  value = alicloud_instance.broker.*.public_ip
}