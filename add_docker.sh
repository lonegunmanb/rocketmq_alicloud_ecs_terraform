echo "add yum repo"
yum install -y wget
rm -f /etc/yum.repos.d/CentOS-Base.repo
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum makecache
yum upgrade -y
echo "install docker-ce"
yum install -y docker-ce docker-ce-cli
systemctl enable docker
systemctl start docker