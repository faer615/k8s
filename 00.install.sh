#!/bin/bash
while true
do
echo "  Kubernetes 1.8.5 安装部署菜单

====================================
  01 配置部署安装环境
  02 安装部署 Etcd
  03 安装部署 Kubectl
  04 安装部署 Docker
  05 安装部署 Calico
  06 安装配置 Kube-Master
  07 安装配置 Kube-Node
  20 添加新工作节点
  21 删除新工作节点
  90 一键部署Kubernetes环境
  99 一键清除Kubernetes环境
  q  退出安装
====================================
"
read -p "请输入要部署的软件名称: " var

case $var in 
01 )
	echo "制作 CA 证书"
	ansible-playbook 01.ca.yml
;;

02 )
	echo "制作证书并配置LB"
	ansible-playbook 02.pki_lb.yml
;;

03 )
	echo "安装部署 Etcd"
	ansible-playbook 03.etcd.yml
;;

04 )
	echo "安装部署 Kubectl"
	ansible-playbook 04.kubectl.yml
;;

05 )
	echo "安装部署 Docker"
	ansible-playbook 05.docker.yml
;;

06 )
	echo "安装部署 Calico"
	ansible-playbook 06.calico.yml
;;

07 )
	echo "安装配置 Kube-Master"
	ansible-playbook 07.kube-master.yml
;;

08 )
	echo "安装配置 Kube-Node"
	ansible-playbook 08.kube-node.yml
;;

20 )
	echo "添加新工作节点"
	ansible-playbook 20.addnode.yml    
;;

21 )
	echo "删除新工作节点"
	ansible-playbook 21.delnode.yml
;;

90 )
	echo "一键部署Kubernetes环境"
	ansible-playbook 90.setup.yml
;;

99 )
	echo "一键清除Kubernetes环境"
	ansible-playbook 99.clean.yml
;;

q )
	echo "退出安装"
	exit 0
;;

* )
	echo "输入错误，请重新选择"
;;
esac
done
