#!/bin/bash
read -p "请输入要查着的镜像名称：" imag
docker-tag mirrorgooglecontainers/$imag
sleep 20
read -p "请输入要下载的镜像名称：" ver
docker pull mirrorgooglecontainers/$imag:$ver
