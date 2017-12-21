#!/bin/bash
kubectl delete -f /opt/k8s184/yaml/01-kubedns
kubectl delete -f /opt/k8s184/yaml/02-dashboard
kubectl delete -f /opt/k8s184/yaml/03-heapster
kubectl delete -f /opt/k8s184/yaml/04-ingress
