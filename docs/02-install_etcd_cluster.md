## 02-安装etcd集群.md

``` bash
roles/etcd/
├── tasks
│   └── main.yml
└── templates
    └── etcd.service.j2
```
kuberntes 系统使用 etcd 存储所有数据，是最重要的组件之一，注意 etcd集群只能有奇数个节点(1,3,5...)，本文档使用3个节点做集群。

请在另外窗口打开[roles/etcd/tasks/main.yml](../roles/etcd/tasks/main.yml) 文件，对照看以下讲解内容。

### 下载etcd/etcdctl 二进制文件、创建证书目录

### 创建etcd证书请求 [etcd-csr.json.j2](../roles/etcd/templates/etcd-csr.json.j2)

``` bash
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "192.168.61.101",
    "192.168.61.61",
    "192.168.61.62",
    "192.168.61.63"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BJ",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
```
+ hosts 字段指定授权使用该证书的 etcd 节点 IP

###  创建etcd 服务文件 [etcd.service.j2](../roles/etcd/templates/etcd.service.j2)

先创建工作目录 /var/lib/etcd/

``` bash
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
ExecStart={{ bin_dir }}/etcd \
  --name={{ NODE_NAME }} \
  --cert-file=/etc/etcd/ssl/etcd.pem \
  --key-file=/etc/etcd/ssl/etcd-key.pem \
  --peer-cert-file=/etc/etcd/ssl/etcd.pem \
  --peer-key-file=/etc/etcd/ssl/etcd-key.pem \
  --trusted-ca-file={{ ca_dir }}/ca.pem \
  --peer-trusted-ca-file={{ ca_dir }}/ca.pem \
  --initial-advertise-peer-urls=https://{{ NODE_IP }}:2380 \
  --listen-peer-urls=https://{{ NODE_IP }}:2380 \
  --listen-client-urls=https://{{ NODE_IP }}:2379,http://127.0.0.1:2379 \
  --advertise-client-urls=https://{{ NODE_IP }}:2379 \
  --initial-cluster-token=etcd-cluster-0 \
  --initial-cluster={{ ETCD_NODES }} \
  --initial-cluster-state=new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
+ 完整参数列表请使用 `etcd --help` 查询
+ 注意etcd 即需要服务器证书也需要客户端证书，这里为方便使用一个peer 证书代替两个证书，更多证书相关请阅读 [01-创建CA证书和环境配置.md](01-创建CA证书和环境配置.md)
+ 注意{{ }} 中的参数与ansible hosts文件中设置对应
+ `--initial-cluster-state` 值为 `new` 时，`--name` 的参数值必须位于 `--initial-cluster` 列表中；

### 启动etcd服务

``` bash
systemctl daemon-reload && systemctl enable etcd && systemctl start etcd
```

### 验证etcd集群状态

+ systemctl status etcd 查看服务状态
+ journalctl -u etcd 查看运行日志
+ 在任一 etcd 集群节点上执行如下命令

``` bash
# 根据hosts中配置设置shell变量 $NODE_IPS
export NODE_IPS="192.168.61.61 192.168.61.62 192.168.61.63"
  /usr/local/bin/etcdctl \
  --endpoints=https://${ip}:2379  \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/etcd/ssl/etcd.pem \
  --key-file=/etc/etcd/ssl/etcd-key.pem \
  cluster-health
```
预期结果：

``` text
member 4a08efe79786b9b1 is healthy: got healthy result from https://192.168.61.62:2379
member 4da9bebdaa7f0145 is healthy: got healthy result from https://192.168.61.63:2379
member 66c9ffd431809be2 is healthy: got healthy result from https://192.168.61.61:2379
cluster is healthy
```
三台 etcd 的输出均为 healthy 时表示集群服务正常。
