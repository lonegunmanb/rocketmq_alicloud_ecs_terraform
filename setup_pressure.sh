yum install -y java-1.8.0-openjdk-devel.x86_64 unzip wget
wget -O rocketmq.zip http://mirror.bit.edu.cn/apache/rocketmq/4.4.0/rocketmq-all-4.4.0-bin-release.zip
unzip rocketmq.zip
echo export JAVA_HOME=/usr/lib/jvm/java >> ~/.bashrc
echo export NAMESRV_ADDR=${namesvr}:9876 >> ~/.bashrc