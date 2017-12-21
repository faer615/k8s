#!/bin/bash
image_add=registry.chinadaas.com
read -p "输入替换的地址: " read_1
read -p "输入仓库名称: " read_2

for i in `docker images |grep "$read_1"|awk '{print $3}'|grep -v IMAGE`
do
docker_tag=$(docker images |grep -v "$image_add"|grep $i|awk '{print $1":"$2}'|sed "s#$read_1/##"|sed "s#^#$image_add/$read_2/#")
docker tag $i $docker_tag
#echo $docker_tag
docker push $docker_tag
docker images|grep $image_add/$read_2
done
