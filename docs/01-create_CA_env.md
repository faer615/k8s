## 01-创建CA证书和环境配置.md

### 01.prepare.yml)主要完成CA证书创建、分发、环境变量、负载均衡配置等。

### 创建 CA 证书和秘钥 
``` bash
/etc/ansible/k8s185/roles/ca
├── tasks
│   └── main.yml
└── templates
    ├── admin-csr.json.j2
    ├── ca-config.json.j2
    ├── ca-csr.json.j2
    ├── calico-csr.json.j2
    ├── etcd-csr.json.j2
    ├── kube-proxy-csr.json.j2
    └── kubernetes-csr.json.j2
```
kubernetes 系统各组件需要使用 TLS 证书对通信进行加密，使用 CloudFlare 的 PKI 工具集生成自签名的CA证书，用来签名后续创建的其它 TLS 证书。[参考阅读](https://coreos.com/os/docs/latest/generate-self-signed-certificates.html)

根据认证对象可以将证书分成三类：服务器证书，客户端证书，对等证书 `peer cert`(表示既是`server cert`又是`client cert`)，在kubernetes 集群中需要的证书种类如下：

+ `etcd` 节点需要标识自己监听服务的server cert，也需要client cert与`etcd`集群其他节点交互，当然可以分别指定2个证书，这里为简化使用一个peer 证书

+ `kube-apiserver` 需要标识apiserver服务的server cert，也需要client cert 从而操作`etcd`集群，这里为简化使用一个peer 证书

+ `kubectl` `calico` `kube-proxy` 只需要 client cert，因此证书请求中 hosts 字段可以为空

+ `kubelet` 证书比较特殊，不是手动生成，它由node节点`TLS BootStrap` 向`apiserver`请求，由master节点的`controller-manager` 自动签发，包含一个client cert 和一个server cert

#### 创建 CA 配置文件 [ca-config.json.j2](../roles/ca/templates/ca-config.json.j2)
``` bash
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
```
+ `ca-config.json`：可以定义多个 profiles，分别指定不同的过期时间、使用场景等参数；这里为了方便使用 `kubernetes` 这个profile 签发三种不同类型证书
+ `signing`：表示该证书可用于签名其它证书；生成的 ca.pem 证书中 `CA=TRUE`；
+ `server auth`：表示 client 可以用该 CA 对 server 提供的证书进行验证；
+ `client auth`：表示 server 可以用该 CA 对 client 提供的证书进行验证；

#### 创建 CA 证书签名请求 [ca-csr.json.j2](../roles/ca/templates/ca-csr.json.j2)
``` bash
{
  "CN": "kubernetes",
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

#### 生成CA 证书和私钥
``` bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```
+ 注意整个集群只能有一个CA证书和配置文件，所以下一步要分发给每一个节点，包括calico/node也需要使用，`ansible` 角色(role) `prepare` 会完成CA 证书分发，所以把ca 证书相关先复制到 `roles/prepare/files/`

### 集群环境变量、CA分发

``` bash
pki/
├── files
│   ├── admin-key.pem
│   ├── admin.pem
│   ├── ca-config.json
│   ├── ca.csr
│   ├── ca-key.pem
│   ├── calico-key.pem
│   ├── calico.pem
│   ├── ca.pem
│   ├── etcd-key.pem
│   ├── etcd.pem
│   ├── kube-proxy-key.pem
│   ├── kube-proxy.pem
│   ├── kubernetes-key.pem
│   └── kubernetes.pem
└── tasks
    └── main.yml
```

1. 首先创建一些基础文件目录
1. 修改环境变量，把{{ bin_dir }} 添加到$PATH，需要重新登陆 shell生效
1. 把证书工具 CFSSL下发到指定节点
1. 把CA 证书相关下发到指定节点的 {{ ca_dir }} 目录

### LB 负载均衡部署
``` bash
roles/lb/
├── tasks
│   └── main.yml
└── templates
    ├── haproxy.cfg.j2
    ├── keepalived-backup.conf.j2
    └── keepalived-master.conf.j2
```

Haproxy支持四层和七层负载，稳定性好。

keepalived观其名可知，保持存活，它是基于VRRP协议保证所谓的高可用或热备的，这里用来预防haproxy的单点故障。

keepalived与haproxy配合，实现master的高可用过程如下：

+ 1.keepalived利用vrrp协议生成一个虚拟地址(VIP)，正常情况下VIP存活在keepalive的主节点，当主节点故障时，VIP能够漂移到keepalived的备节点，保障VIP地址可用性。
+ 2.在keepalived的主备节点都配置相同haproxy负载配置，并且监听客户端请求在VIP的地址上，保障随时都有一个haproxy负载均衡在正常工作。并且keepalived启用对haproxy进程的存活检测，一旦主节点haproxy进程故障，VIP也能切换到备节点，从而让备节点的haproxy进行负载工作。
+ 3.在haproxy的配置中配置多个后端真实kube-apiserver的endpoints，并启用存活监测后端kube-apiserver，如果一个kube-apiserver故障，haproxy会将其剔除负载池。

#### 安装haproxy

+ 使用yum源安装

#### 配置haproxy [haproxy.cfg.j2](../roles/lb/templates/haproxy.cfg.j2)
``` bash
global
    log         127.0.0.1 local2 info
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     50000
    user        haproxy
    group       haproxy
    tune.comp.maxlevel 9
    maxcompcpuusage 50
    daemon
    stats socket /var/lib/haproxy/stats level admin
    nbproc 1

defaults
        log     global
        timeout connect 5000
        timeout client  50000
        timeout server  50000

listen stats *:8888
    mode http
    stats                   enable
    stats                   hide-version
    stats                   uri /admin
    stats                   realm Haproxy\ Statistics
    stats                   auth admin:admin
    stats                   admin if TRUE

listen kube-master
        bind *:{{ MASTER_PORT }}
        mode tcp
        option tcplog
        balance source
        server apiserver_61 {{ LB_EP1 }} check inter 10000 fall 2 rise 2 weight 1
        server apiserver_62 {{ LB_EP2 }} check inter 10000 fall 2 rise 2 weight 1
```

+ 名称 kube-master
+ bind 监听客户端请求的地址/端口，保证监听master的VIP地址和端口，{{ MASTER_PORT }}与hosts里面设置对应
+ mode 选择四层负载模式 (当然你也可以选择七层负载，请查阅指南，适当调整)
+ balance 选择负载算法 (负载算法也有很多供选择)
+ server 配置master节点真实的endpoits，必须与 [hosts文件](../example/hosts.m-masters.example)对应设置

#### 安装keepalived

+ 使用yum源安装

#### 配置keepalived主节点 [keepalived-master.conf.j2](../roles/lb/templates/keepalived-master.conf.j2)
``` bash
global_defs {
    router_id lb-master
}

vrrp_script check-haproxy {
    script "killall -0 haproxy"
    interval 5
    weight -30
}

vrrp_instance VI-kube-master {
    state MASTER
    priority 120
    dont_track_primary
    interface {{ LB_IF }}
    virtual_router_id 51
    advert_int 3
    track_script {
        check-haproxy
    }
    virtual_ipaddress {
        {{ MASTER_IP }}
    }
}
```
+ vrrp_script 定义了监测haproxy进程的脚本，利用shell 脚本`killall -0 haproxy` 进行检测进程是否存活，如果进程不存在，根据`weight -30`设置将主节点优先级降低30，这样原先备节点将变成主节点。
+ vrrp_instance 定义了vrrp组，包括优先级、使用端口、router_id、心跳频率、检测脚本、虚拟地址VIP等

#### 配置keepalived备节点 [keepalived-backup.conf.j2](../roles/lb/templates/keepalived-backup.conf.j2)
``` bash
global_defs {
    router_id lb-backup
}

vrrp_instance VI-kube-master {
    state BACKUP
    priority 110
    dont_track_primary
    interface {{ LB_IF }}
    virtual_router_id 51
    advert_int 3
    virtual_ipaddress {
        {{ MASTER_IP }}
    }
}
```
+ 备节点的配置类似主节点，除了优先级和检测脚本

### 启动 keepalived 和 haproxy 后验证

+ lb 节点验证，假定 MASTER_PORT=8443

``` bash
systemctl status haproxy 	# 检查进程状态
journalctl -u haproxy		# 检查进程日志是否有报错信息
systemctl status keepalived # 检查进程状态
journalctl -u keepalived	# 检查进程日志是否有报错信息
netstat -antlp|grep 8443	# 检查tcp端口是否监听
```
+ 在 keepalived 主节点

``` bash
ip a				# 检查 master的 VIP地址是否存在
```
### keepalived 主备切换演练

1. 尝试关闭 keepalived主节点上的 haproxy进程，然后在keepalived 备节点上查看 master的 VIP地址是否能够漂移过来，并依次检查上一步中的验证项。
1. 尝试直接关闭 keepalived 主节点系统，检查各验证项。