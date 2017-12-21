#!/bin/bash
echo "开始部署yml镜像"
kubectl create -f /opt/k8s184/yaml/01-kubedns
kubectl create -f /opt/k8s184/yaml/02-dashboard
kubectl create -f /opt/k8s184/yaml/03-heapster
kubectl create -f /opt/k8s184/yaml/04-ingress
