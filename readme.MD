create terraform.tfvars and provide all variables.

az means availability_zone, we must provide three zones in same region.

broker_image_id, namesvr_image_id, pressure_image_id means alicloud ecs image id, which I recommend "centos_7_06_64_20G_alibase_20190711.vhd"

rktmq_image means rocketmq docker image id, which I recommend "uhub.service.ucloud.cn/lonegunmanb/rocketmq:4.5.1"

open_ports are security group open port rules, which I recommend at least:
```hcl
intranet_open_ports = [9876, 30911, 30909, 40911]
internet_open_ports = [22, 8080]
```
to run this script:
```shell script
terraform init
terraform apply --auto-approve
```
when finished, terraform will output three brokers' public ips, name server's public ip and pressure test runner's public ip

ssh to pressure_ip

```shell script
cd rocketmq-all-4.4.0-bin-release/bin
```

then you can run a simple test to check whether the cluster is working fine:
```shell script
sh bin/tools.sh org.apache.rocketmq.example.quickstart.Producer
```

to run pressure test:
```shell script
sh benchmark/producer.sh --w=128 --s=128
```
which 'w' means parallel count and 's' means message size

have fun!