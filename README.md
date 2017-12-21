## 00-集群规划和基础参数设定.md

本项目部署kubernetes多节点高可用集群，具有负载均衡高可用功能，版本为v1.9.0。

## 组件版本
    kubernetes	v1.9.0
    etcd	v3.2.12
    docker	17.09.1-ce
    calico/node	v2.6.3
---

## 高可用集群所需节点配置如下：
+ 1台 部署节点: 通过执行 ansible-playbook 脚本自动化部署。
+ 3台 Etcd节点: 注意etcd集群必须是1,3,5,7...奇数个节点。
+ 2台 Master节点: 可根据实际集群规模可以增加节点数，需要额外规划一个Master VIP(虚地址)
+ 2台 LB节点: 负载均衡高可用节点2个，安装 haproxy+keepalived。
+ 3台 Node节点: 真正应用负载的节点，根据需要增加机器配置和节点数
---

+ 环境配置文件为 hosts 可根据实际情况修改

## 集群所用到的参数举例如下：
``` bash
#集群 MASTER IP, 需要负载均衡，一般为VIP地址
MASTER_IP="192.168.61.10"
KUBE_APISERVER="https://192.168.61.10:8443"
````
## TLS Bootstrapping 的 Token
    使用 head -c 16 /dev/urandom | od -An -t x | tr -d ' ' 生成
    BOOTSTRAP_TOKEN="88eaefe9c65157b25720b424c6262a48"

## 服务网段 (Service CIDR），部署前路由不可达，部署后集群内使用 IP:Port 可达
SERVICE_CIDR="10.254.0.0/16"

## POD 网段 (Cluster CIDR），部署前路由不可达，**部署后**路由可达
CLUSTER_CIDR="172.254.0.0/16"

## 服务端口范围 (NodePort Range)
NODE_PORT_RANGE="2000-50000"

## kubernetes 服务 IP (预分配，一般是 SERVICE_CIDR 中第一个IP)
CLUSTER_KUBERNETES_SVC_IP="10.254.0.1"

## 集群 DNS 服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_DNS_SVC_IP="10.254.0.2"

## 集群 DNS 域名，后续生成 Master节点证书时也会用到这个默认根域名
CLUSTER_DNS_DOMAIN="cluster.local."

## Etcd 集群间通信的IP和端口, **根据实际 etcd 集群成员设置**
ETCD_NODES="etcd1=https://192.168.61.61:2380,etcd2=https://192.168.61.62:2380,etcd3=https://192.168.61.63:2380"

## etcd 集群服务地址列表, **根据实际 etcd 集群成员设置**
ETCD_ENDPOINTS="https://192.168.61.61:2379,https://192.168.61.62:2379,https://192.168.61.63:2379"

## 集群basic auth 使用的用户名和密码【可选】
BASIC_AUTH_USER="admin"
BASIC_AUTH_PASS="admin123"

## ---------附加参数--------------------
###默认二进制文件目录
bin_dir="/usr/local/bin"

## 证书目录
ca_dir="/etc/kubernetes/ssl"

## 部署目录，即 ansible 工作目录，建议不要修改
base_dir="/etc/ansible"

## 私有仓库 harbor服务器 (域名或者IP) 【可选】
## 需要把 harbor服务器证书复制到roles/harbor/files/harbor-ca.crt
    HARBOR_SERVER="harbor.chinadaas.com"


## 部署步骤

### 1.准备4台虚机(推荐内存4G，硬盘80G以上)，最小化安装CentOS 7.4 server，配置基础网络、更新源、SSH登陆等。
### 2.在每台机器安装基础软件 
``` bash
# 文档中脚本默认均以root用户执行
yum update
-----------------------------
### 3.在deploy节点安装ansible
``` bash
-----------------------------
# 安装依赖工具
yum install python2.7 git python-pip
----------------------------------------
# 安装ansible (国内如果安装太慢可以直接用pip阿里云加速)
#pip install pip --upgrade
#pip install ansible
pip install pip --upgrade -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com
pip install --no-cache-dir ansible -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com
```
### 4.在deploy节点配置免密码登陆所有节点包括自身
``` bash
ssh-keygen -t rsa -b 2048 回车 回车 回车
ssh-copy-id $IPs #$IPs为所有节点地址，按照提示输入yes 和root密码
```
+ 验证ansible安装

``` bash
ansible all -m ping
```
如果配置正确可以看到类似输出：

``` text
192.168.61.61 | SUCCESS => {
    "changed": false,
    "failed": false,
    "ping": "pong"
}
192.168.61.62 | SUCCESS => {
    "changed": false,
    "failed": false,
    "ping": "pong"
192.168.61.63 | SUCCESS => {
    "changed": false,
    "failed": false,
    "ping": "pong"
}
```
### 5.在deploy节点编排k8s安装
``` bash
mv k8s185 /etc/ansible
# 下载已打包好的binaries，并且解压缩到/etc/ansible/bin目录

tar zxvf k8s.184.tar.gz
mv bin/* /etc/ansible/bin
# 配置ansible的hosts文件
cd /etc/ansible
cp example/hosts.m-masters.example hosts
然后根据上文实际规划修改此hosts文件
# 采用分步安装(确定每一步是否安装成功)或者一步安装
# 先不要安装，后文将一步一步讲解后执行安装
#ansible-playbook 01.prepare.yml
#ansible-playbook 02.etcd.yml
#ansible-playbook 03.kubectl.yml
#ansible-playbook 04.docker.yml
#ansible-playbook 05.calico.yml
#ansible-playbook 06.master.yml
#ansible-playbook 07.node.yml
#ansible-playbook 90.setup.yml # 一键安装
#ansible-playbook 99.clean.yml # 一键删除
```

### 6.验证安装
``` bash
# 如果提示kubectl: command not found，退出重新ssh登陆一下，环境变量生效即可
kubectl version
kubectl get componentstatus # 可以看到scheduler/controller-manager/etcd等组件 Healthy
kubectl cluster-info # 可以看到kubernetes master(apiserver)组件 running
kubectl get node # 可以看到单 node Ready状态
kubectl get pod --all-namespaces # 可以查看所有集群pod状态
kubectl get svc --all-namespaces # 可以查看所有集群服务状态
calicoctl node status	# 可以在master或者node节点上查看calico网络状态 
```
### 7.安装主要组件
``` bash
# 安装kubedns
kubectl create -f yaml/01-kubedns
# 安装heapster
kubectl create -f yaml/02-dashboard
# 安装dashboard
kubectl create -f yaml/03-heapster
```
---
## 自动添加新加工作节点命令
kubectl get csr|grep 'Pending' | awk 'NR>0{print $1}'| xargs kubectl certificate approve
