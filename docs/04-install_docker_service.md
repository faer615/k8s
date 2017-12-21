## 04-安装docker服务.md

``` bash
roles/docker
├── files
│   ├── daemon.json
│   ├── docker
│   ├── docker-tag
│   └── server.crt
├── tasks
│   └── main.yml
└── templates
    └── docker.service.j2
```

### 创建docker的systemd unit文件 

``` bash
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io

[Service]
Environment="PATH={{ bin_dir }}:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStart={{ bin_dir }}/dockerd --log-level=error
ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
```
+ dockerd 运行时会调用其它 docker 命令，如 docker-proxy，所以需要将 docker 命令所在的目录加到 PATH 环境变量中；
+ docker 从 1.13 版本开始，将`iptables` 的`filter` 表的`FORWARD` 链的默认策略设置为`DROP`，从而导致 ping 其它 Node 上的 Pod IP 失败，因此必须在 `filter` 表的`FORWARD` 链增加一条默认允许规则 `iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT`
+ 运行`dockerd --help` 查看所有可以可配置参数，确保默认开启 `--iptables` 和 `--ip-masq` 选项

### 清理 iptables

因为后续`calico`网络、`kube-proxy`等将大量使用 iptables规则，安装前清空所有`iptables`策略规则；常见发行版`Ubuntu`的 `ufw` 和 `CentOS`的 `firewalld`等基于`iptables`的防火墙最好直接卸载，避免不必要的冲突。

``` bash
iptables -F && iptables -X \
        && iptables -F -t nat && iptables -X -t nat \
        && iptables -F -t raw && iptables -X -t raw \
        && iptables -F -t mangle && iptables -X -t mangle
```
+ calico 网络支持 `network-policy`，使用的`calico-kube-controllers` 会使用到`iptables` 所有的四个表 `filter` `nat` `raw` `mangle`，所以一并清理

### 启动 docker

### 安装docker查询镜像 tag的小工具

docker官方目前没有提供在命令行直接查询某个镜像的tag信息的方式，网上找来一个脚本工具，使用很方便。

``` bash
>docker-tag mirrorgooglecontainers/kubernetes-dashboard-amd64
"v0.1.0"
"v1.0.0"
"v1.0.0-beta1"
"v1.0.1"
"v1.1.0-beta1"
"v1.1.0-beta2"
"v1.1.0-beta3"
"v1.7.0"
"v1.7.1"
"v1.8.0"
``` 
+ 需要先yum安装轻量JSON处理程序 `jq`
+ 然后下载脚本即可使用
+ 脚本很简单，就一行命令如下

``` bash
#!/bin/bash
curl -s -S "https://registry.hub.docker.com/v2/repositories/$@/tags/" | jq '."results"[]["name"]' |sort
```
