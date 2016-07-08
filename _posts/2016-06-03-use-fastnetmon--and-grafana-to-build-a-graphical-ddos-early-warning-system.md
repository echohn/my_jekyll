---
layout: post
title: "使用 FastNetMon + Grafana 打造可视化的 DDoS 安全告警系统"
subtitle: ''
date: 2016-06-03
header-img: "img/in-post/ddos.jpg"
author: "Echo"
tags: 安全 运维 
keywords: DDoS 安全 运维 防御 预警 FastNetMon Grafana Influxdb iperf pf_ring netmap pcap 可视化
---

昨天被安全部拉去开会，我被安利了好多安全工具。

我很喜欢其中一个叫做 [**FastNetMon**](https://github.com/pavel-odintsov/fastnetmon) 的 DoS/DDoS 分析防御工具。

它性能很高，支持多种抓包引擎。支持 ExaBGP 和外部脚本触发报警。FastNetMon 可以部署在旁路上，侦听从核心交换上镜像过来的流量（见下图）。当它发现受到攻击的时候，可以通过脚本通知管理员，在 BGP 上 Blocked 掉被攻击的 IP，或是通过脚本触发任何你能想到的其他操作。

![](/img/in-post/network_map.png)


FastNetMon 也可以结合 BGP 协议，打造自动化的抗 DDoS 安全防御系统。当发现受到攻击的时候，通过在 BGP 上宣告 blocked 受到攻击的 IP 地址。从而将攻击转移到其他地点，保证本地的其他服务不受到 DDoS 攻击的影响。


当然，在国内的环境，现实的问题在于，当你遭受攻击的时候，[你其实什么都做不了](http://zhihu.com/question/19581905/answer/37397087)。


扯远了，今天我就介绍一下，如何把 FastNetMon 与 [Grafana](http://grafana.org) 结合起来，打造一个可视化的 DDoS 安全预警系统。

## 1. 安装 FastNetMon

由于只是搭建一个实验环境，我把所有相关的组件都安装在一台 CentOS 6 的虚拟机上。

FastNetMon 官方提供了便捷的安装脚本，这也是目前官方唯一推荐的安装方式。然而这个脚本有一些坑（后面会提到）。而 RPM 包的安装方式官方看来是[已经暂时放弃了](https://github.com/pavel-odintsov/fastnetmon/blob/master/docs/INSTALL_RPM_PACKAGES.md)。


{% highlight bash %}
wget https://raw.githubusercontent.com/FastVPSEestiOu/fastnetmon/master/src/fastnetmon_install.pl -Ofastnetmon_install.pl 
perl fastnetmon_install.pl
{% endhighlight %}

首先需要说明的是，使用这个脚本安装的时候，FastNetMon 官方会从运行的机器上收集一些系统的相关信息用于改进产品。如果你不希望被打扰，可以在脚本后面加上`--do-not-track-me`参数阻止数据上传。

FastNetMon 需要安装很多依赖组件，这个脚本的执行时间取决于你的网速。你可以趁这时候喝口水，起来活动一下身体，或跟你的妹子聊聊微信。你也可以通过跟踪安装日志 /tmp/fastnetmon_install.log 来查看安装的时候究竟做了什么。

在我十几分钟的等待结束之后，fastnetmon 终于安装完成了。

在这里，我不得不吐槽一下这个安装脚本。

1. 虽然在安装之后，屏幕上会输出 We created service fastnetmon for you. You could run it with command: `/etc/init.d/fastnetmon start` 但是粗心的官方忘记了给 /etc/init.d/fastnetmon 脚本加执行权，我在发现执行找不到脚本的时候发现了这个问题，自己加上了。
2. 即使加上了，/etc/init.d/fastnetmon 这个脚本依赖于 daemonize ，然 daemonize 这个依赖包并没有安装，我自己通过 yum 装上了。
3. 即使这个包装上了，启动的时候也显示成功启动，然后我发现进程并没有运行。查看日志，发现一条 [ERROR] FastNetMon is already running with pid: 3068 的错误。然而，我是第一次启动好不好！

![](/img/in-post/shuai.jpg)

所以我尝试自己改动了启动脚本，因为 fastnetmon 本身就支持 daemonize 模式，而且直接通过进程运行时生成的 pid 文件与通过启动的 pid 文件路径是一样的，所以可以直接修改 /etc/init.d/fastnetmon 脚本，将 `start()`函数替换成如下所示：


{% highlight bash %}
start() {
        echo -n $"Starting $PROGNAME: "
        $FASTNETMON --daemonize
        RETVAL=$?
        # add pretty error messages
        if [ $RETVAL = 0 ]; then
            echo_success
        else
            echo_failure
        fi
        echo ""
        return $RETVAL
}
{% endhighlight %}

现在通过脚本启动关闭就是正常的了。

之前说过，FastNetMon 支持多种抓包引擎。有像 pf_ring、netmap、pcap 这种 mirror capture, 也支持 netflow 和 sflow。FastNetMon 的作者 Pavel Odintsov 做过这些抓包引擎的性能对比：

![](/img/in-post/mirror-performance.jpg)

同样，我也找到[这篇测试报告](http://prod.sandia.gov/techlib/access-control.cgi/2015/159378r.pdf),其中有 pf_ring zc 和 netmap 的性能对比。

由于 netmap 需要单独安装。在这里我将介绍使用 pf_ring 作为抓包引擎进行实验。你也可以选择 pcap，如果作为实验环境，它的兼容性是最好的。

## 2. 使用 pf_ring 作为 FastNetMon 的抓包引擎

*这部分是讲我是怎么填坑的。如果你只是做测试，可以选择 pcap 引擎，忽略这一部分。*

FastNetMon 在安装的时候，已经安装了 pf_ring 。

首先编辑文件 /etc/fastnetmon.conf，将 mirror 的值改为 on ，这将使用 pf_ring 作为抓包引擎。

```
# PF_RING traffic capture, enough fast but wire speed version need paid license
mirror = on

```

同时，可以顺便把报警阈值调小一点，方便后面测试攻击。


{% highlight ini %}
# Limits for Dos/DDoS attacks
threshold_pps = 200
threshold_mbps = 10
threshold_flows = 350
{% endhighlight %}

现在就可以通过 `/etc/init.d/fastnetmon start` 来启动 FastNetMon 了，这时候我惊喜的发现，FastNetMon 根本起！不！来！

通过日志可以看到：

{% highlight bash %}
2016-06-03 22:31:08,966 [INFO] pfring_open error: No such device (pf_ring not loaded or perhaps you use quick mode and have already a socket bound to: eth1)
2016-06-03 22:31:08,966 [ERROR] PF_RING initilization failed, exit from programm
{% endhighlight %}

这里又是 FastNetMon 那个安装脚本的一大坑。 它并没有安装成功 pf_ring 的 Kernel module，也没有将安装错误抛出来。

如果通过命令`lsmod |grep pf_ring`查找机器上已安装的 pf_ring ，会发现根本找不到。/proc/net 里也没有建立 pf_ring 的目录。

所以我仔细排查了 fastnetmon 的安装日志 /tmp/fastnetmon_install.log，我发现日志里有这样的内容。

{% highlight bash %}
We are calling command: make -j 2 -C /tmp/fastnetmon.build.dir.rwNsXhsTQt/PF_RING-6.0.3/kernel

make: Entering directory `/tmp/fastnetmon.build.dir.rwNsXhsTQt/PF_RING-6.0.3/kernel'
********** WARNING WARNING WARNING **********
*
* Compiling PF_RING as root might lead you to compile errors
* Please compile PF_RING as unpriviliged user
*
*********************************************
make -C /lib/modules/2.6.32-573.22.1.el6.x86_64/build SUBDIRS=/tmp/fastnetmon.build.dir.rwNsXhsTQt/PF_RING-6.0.3/kernel EXTRA_CFLAGS='-I/tmp/fastnetmon.build.dir.rwNsXhsTQt/PF_RING-6.0.3/kernel -DSVN_REV="\"已导出 \""' modules
make: Entering an unknown directory
make: Leaving an unknown directory
make: Leaving directory `/tmp/fastnetmon.build.dir.rwNsXhsTQt/PF_RING-6.0.3/kernel'
Command finished with code 512

We are calling command: make -j 2 -C /tmp/fastnetmon.build.dir.rwNsXhsTQt/PF_RING-6.0.3/kernel install

make: Entering directory `/tmp/fastnetmon.build.dir.rwNsXhsTQt/PF_RING-6.0.3/kernel'
mkdir -p /lib/modules/2.6.32-573.22.1.el6.x86_64/kernel/net/pf_ring
cp *.ko /lib/modules/2.6.32-573.22.1.el6.x86_64/kernel/net/pf_ring
make: Leaving directory `/tmp/fastnetmon.build.dir.rwNsXhsTQt/PF_RING-6.0.3/kernel'
Command finished with code 512

We are calling command: rmmod pf_ring 2>/dev/null

Command finished with code 256

We are calling command: modprobe pf_ring

Command finished with code 256

{% endhighlight %}

可以看到，首先 pf_ring 在编译的时候有提示，不要用 root 进行编译，可能会导致失败，而且 make、make install 和 modprobe 命令的返回值也不是 0 ，说明编译和之后的安装都没有成功。


![](/img/in-post/shuai.jpg)


所以我只能自己编译一下 pf_ring 的 Kernel module。

首先按照人家建议的，我们建一个普通用户 echo，然后找到日志中的编译临时目录，并赋给 echo 用户这个目录的读写权限。

切换到 echo 用户 然后执行下面命令进行编译。


```
# su - echo
$ cd /tmp/fastnetmon.build.dir.lAVvYX7Htd/
$ ls
fastnetmon  PF_RING-6.0.3  PF_RING-6.0.3.tar.gz
$ rm -rf PF_RING-6.0.3
$ tar zxf  PF_RING-6.0.3.tar.gz
$ cd PF_RING-6.0.3/kernel/
$ make
```

好了，退出到这个用户，回到 root，执行安装：


{% highlight bash %}
make -C /tmp/fastnetmon.build.dir.lAVvYX7Htd/PF_RING-6.0.3/kernel install
modprobe pf_ring
{% endhighlight %}

现在执行 lsmod 就能看到这个 module 了。


{% highlight bash %}
# lsmod |grep pf_ring
pf_ring               691861  2
{% endhighlight %}

现在重新启动 fastnetmon，就能够成功启动了。

## 3. 模拟 DDoS 攻击测试 FastNetMon

接下来我们测试 fastnetmon 是否能正确识别 DDoS 攻击。

首先我们配置一下 FastNetMon 的通知脚本（[下载脚本示例](https://github.com/pavel-odintsov/fastnetmon/raw/master/src/notify_about_attack.sh))。

将这个脚本复制为 /usr/local/bin/notify_about_attack.sh ，这是 fastnetmon.conf 文件中 notify_script_path 选项默认指定的通知脚本位置，并得给脚本赋执行权。

编辑这个脚本，找到 ban 的条件语句，由于只是进行测试，我仅仅输出一条消息到 /tmp/ban.log 日志中。


```
if [ "$4" = "ban" ]; then
    echo "FastNetMon Guard: IP $1 blocked because $2 attack with power $3 pps" >> /tmp/ban.log
    exit 0
fi
```

这样通知脚本就配置好了。

我使用一款叫做 iperf 的工具来模拟 DDoS 攻击，这个工具一般用于测试网络带宽，当然也可以通过大量发包模拟一次 DDoS 攻击。

在 CentOS 上可以通过 yum 直接安装 iperf：`yum install iperf`。

然后通过`iperf -su`命令启动 iperf 的服务器端。

这里 -u 参数指明侦听 udp 端口。

我将我的 mbp 作为攻击的发器端，同样安装 iperf ： `brew install iperf`。

在客户端上向服务器发起探测：`iperf  -u -c 10.1.2.137 -b 100M -P 5`。

这时，在服务器上执行 FastNetMon 的客户端命令 `/opt/fastnetmon/fastnetmon_clinet`进行查看,可以看到出现如下信息。


{% highlight bash %}
FastNetMon v1.0 FastVPS Eesti OU (c) VPS and dedicated: http://FastVPS.host
IPs ordered by: packets
Incoming traffic         42594 pps    491 mbps      0 flows
10.1.2.137               35552 pps    410 mbps      0 flows  *banned*

Outgoing traffic             1 pps	0 mbps      0 flows
10.1.2.137                   1 pps	0 mbps      0 flows  *banned*

Internal traffic             0 pps	0 mbps

Other traffic                0 pps	0 mbps

Screen updated in:              0 sec 191 microseconds
Traffic calculated in:          0 sec 7 microseconds
Total amount of not processed packets: 0
Packets received:	404792
Packets dropped:        0
Packets dropped:        0.0 %

Ban list:
10.1.2.137/35552 pps incoming at 04_06_16_00:40:13

{% endhighlight %}

因为之前我设置了攻击阈值为 200 pps，10 mb，目前的这个负载量已经远远超过我设定的阈值，被认为遭到了攻击。可以看到，目前 10.1.2.137 这个 IP 已经被拉进 Ban list 之中了。

现在我们查看 FastNetMon 是否触发了通知，查看 /tmp/ban.log 这个日志，可以看到通知的消息。

	
```
FastNetMon Guard: IP 10.1.2.137 blocked because incoming attack with power 293 pps
```

FastNetMon 确实触发了通知的操作。

## 4. FastNetMon 集成 InfluxDB

InfluxDB 是一款开源的分布式时钟、事件和指标数据库。使用 Go 语言编写，它易于分布式和水平伸缩扩展。 InfluxDB 本身提供了非常简单易用的 HTTP API，因此它经常用于监控程序的后端数据存储，Grafana 对它就有非常好的支持。

它有三大特性：

1. Time Series（时间序列）：你可以使用与时间有关的相关函数，如最大，最小，求和等。
2. Metrics（度量）：你可以实时对大量数据进行计算。
3. Eevents（事件）：它支持任意的事件数据。


先来安装 InfluxDB。


{% highlight bash %}
wget https://dl.influxdata.com/influxdb/releases/influxdb-0.13.0.x86_64.rpm
yum localinstall influxdb
{% endhighlight %}

编辑 InfluxDB 的配置文件 /etc/influxdb/influxdb.conf 中的 graphite 选项，按照如下配置：


{% highlight ini %}
[[graphite]]
  enabled = true
  bind-address = ":2003"
  protocol = "tcp"
  consistency-level = "one"


  batch-size = 5000
  batch-timeout = "1s" 
  separator = "."

  templates = [
    "fastnetmon.hosts.* app.measurement.cidr.direction.function.resource",
    "fastnetmon.networks.* app.measurement.cidr.direction.resource",
    "fastnetmon.total.* app.measurement.direction.resource"
  ]
{% endhighlight %}

现在就可以启动 InfluxDB 了。


{% highlight bash %}
# /etc/init.d/influxdb start
Starting the process influxdb [ OK ]
influxdb process was started [ OK ]
{% endhighlight %}

同样，需要在 FastNetMon 的配置文件 /etc/fastnetmon.conf 里做一些配置:


```
graphite = on
graphite_host = 127.0.0.1
graphite_port = 2003
graphite_prefix = fastnetmon
```

然后重启 FastNetMon:


```
/etc/init.d/fastnetmon restart
```

等待几秒，接下来登录 Influxdb shell，查看数据库里是否有数据了。


```
# influx
Visit https://enterprise.influxdata.com to register for updates, InfluxDB server management, and monitoring.
Connected to http://localhost:8086 version 0.13.0
InfluxDB shell version: 0.13.0
> show databases
name: databases
---------------
name
graphite
_internal

> use graphite
Using database graphite
> show measurements
name: measurements
------------------
name
fastnetmon.10_1_2_137.incoming.flows
fastnetmon.10_1_2_137.incoming.mbps
fastnetmon.10_1_2_137.incoming.pps
fastnetmon.10_1_2_137.outgoing.flows
fastnetmon.10_1_2_137.outgoing.mbps
fastnetmon.10_1_2_137.outgoing.pps
fastnetmon.172_26_1_1.incoming.flows
fastnetmon.172_26_1_1.incoming.mbps
fastnetmon.172_26_1_1.incoming.pps
fastnetmon.172_26_1_1.outgoing.flows
fastnetmon.172_26_1_1.outgoing.mbps
fastnetmon.172_26_1_1.outgoing.pps
fastnetmon.incoming.mbps
fastnetmon.incoming.pps
fastnetmon.incomingflows
fastnetmon.outgoing.mbps
fastnetmon.outgoing.pps
fastnetmon.outgoingflows

> select * from "fastnetmon.incoming.pps" order by time desc limit 10
name: fastnetmon.incoming.pps
-----------------------------
time			value
1465079546000000000	0
1465079545000000000	0
1465079544000000000	3
1465079543000000000	0
1465079542000000000	2
1465079541000000000	0
1465079540000000000	0
1465079539000000000	0
1465079538000000000	0
1465079537000000000	0
```

可以看到，在 graphite 这个数据库里，FastNetMon 已经自动创建了一些表，而且在表里已经有写入的数据了。

在 InfluxDB 里，有些概念是与传统数据库不同的。在它的每张表（在 InfluxDB 中称为 measurement）里，并没有固定的字段，所以你不需要在前期先设计表的结构。

表中的每条记录（在 InfluxDB 中称为 points），由时间戳（time）、数据（field）、标签（tags）组成。 每条 points 都要至少包含一个 field。

如果一条记录插入进来，即使在表中没有这个 tags 或 field 的时候，它也会自动添加这个字段。

InfluxDB 官方介绍说，在 InfluxDB 的数据库中，可能会有百万计的表。它提供了一个非常强大的特性，支持通过 Go 语言风格的正则表达式对 measurement 进行查询。这对后面我们生成 Grafana 的图表非常有用。例如：


```
> select * from /fastnetmon.*\.incoming\.pps/ order by time desc limit 3
name: fastnetmon.incoming.pps
-----------------------------
time			value
1465083127000000000	3
1465083126000000000	0
1465083125000000000	0

name: fastnetmon.172_26_1_1.incoming.pps
----------------------------------------
time			value
1465083127000000000	0
1465083126000000000	0
1465083125000000000	0

name: fastnetmon.10_1_2_137.incoming.pps
----------------------------------------
time			value
1465083127000000000	3
1465083126000000000	0
1465083125000000000	0

```

这样可以获取到 FastNetMon 中所有进站流量的 pps,而无需确切知道镜像来的流量中一共有多少个目的 IP 地址。

InfluxDB 不仅提供了 shell ，同时也提供了 WEB 管理接口（端口 8083）和 HTTP API 接口（端口 8086）。接下来，我将配置 Grafana 与它的 HTTP API 端口进行交互。

## 5. 安装配置 Grafana

Grafana 目前已经[更新到 3.0 ](http://grafana.org/blog/2016/05/11/grafana-3-0-stable-released.html)版本了，新增了许多特性。哈哈，好激动，我终于可以把 Kibana 难看的图表给扔掉了。


使用下面的命令下载安装 Grafana:

```
yum install https://grafanarel.s3.amazonaws.com/builds/grafana-3.0.4-1464167696.x86_64.rpm
```

话不多说，直接启动吧。


```
/etc/init.d/grafana-server start
```

浏览器打开 Grafana（端口默认 3000），默认用户是 admin, 密码 admin。

首先点击左上角 Logo，添加数据源,添加 InfluxDB 的配置信息。

![](/img/in-post/grafana-datasource.jpg)

填好之后，点击下方的`Save and Test`按钮，如果显示 Success ，说明已经可以连到 InfluxDB 了。


然后转到 Dashboard ，新建一个 Dashboard。

![](/img/in-post/grafana-dash.jpg)

在 Dashboard 里新建一个 Panel。

![](/img/in-post/grafana-single-new.jpg)

点击 Metrics 标签中的 SQL 语句。在 FROM 一行中，点击 select measurement ，选择 fastnetmon.incoming.pps,可以看到上方 Panel 中的数值已经变化了。

![](/img/in-post/grafana-single-metrics.jpg)

现在数据已经设置好了，你可以选择在 General 标签设置标题，Options 标签设置样式，修改成你喜欢的样子。

然后我们以同样的方式新建一排 Singlestat 的 Panel ，分别对应 incoming 和 outgoing 的 pps 和 mpbs。

![](/img/in-post/grafana-single-row.jpg)

接下来新建一行，新建两张分别对应 pps 和 mbps 的图表。

![](/img/in-post/grafana-graph-new.jpg)

在这次数据的设置里，同样在 select meatruement 的地方，可以使用上一节我讲到的正则表达式，查询所有关于 pps 表的正则表达式 `/fastnetmon.*\.pps/`。

![](/img/in-post/grafana-graph-metrics.jpg)

然后同样另建一张查询所有 mpbs 表的图。

至此，我们的 Dashboard 就算新建完成了。

这时候，我再通过 iperf 模拟发起一次攻击，看一下 Grafana 的效果。还是很漂亮的嘛。

![](/img/in-post/grafana-attack.jpg)

今天这篇帖子就讲完了，不知道你是不是已经学会使用 FastNetMon 集成 Grafana 搭建这个 DDoS 安全预警平台了，如果你有任何想法，欢迎你与我交流。


## 参考资料

https://github.com/pavel-odintsov/fastnetmon/blob/master/docs/INSTALL.md

https://github.com/pavel-odintsov/fastnetmon/blob/master/docs/INFLUXDB_INTEGRATION.md

https://docs.influxdata.com/influxdb/v0.13/introduction/getting_started/




