---
layout: post
title: "如何在 Mac 上管理你经常变化的服务器列表？"
date: 2016-05-15
header-img: "img/post-bg-unix-linux.jpg"
author: "Echo"
tags: 运维
keywords: 运维 自动化 mac 管理 salt saltstack ssh zsh 终端 脚本

---

相比传统运维「日久不变」的服务器运维，步入云时代之后，虚拟机创建和销毁频率比之前不知高了多少个量级，原本几年前想象中的可以根据日常负载自动添加机器什么的，已经完全变成了现实。现在想要找几台机器搭个小架构测试点什么东西，也不必像从前那样拉网线改 BIOS 装系统初始化一忙一上午了。

所以，如果工程师们还是按照原有的传统运维理念去进行运维，基本上就是嫌自己不够忙作死了。

虽然我非常认同云时代不登录虚拟机运维的理念（注1），但是我们单位目前还做不到如此高效的自动化，我们还是经常需要登服务器看看的。

注1：具体出处是看过的某一个技术视频，标题忘记了，主要是说在版本上线之前做好自动化，版本与虚拟机状态版本相对应，应用版本的切换就对应着上个版本的虚拟机销毁，下个版本虚拟机创建的过程，上线之后不给运维工程师登录服务器的权限，以防止误操作引起应用问题。

面对经常变化的服务器列表，身为一个懒人，怎么不会想出一个途径自动地管理这些东西？

## 1. 在 SaltMaster 上自动生成服务器 ID 列表

我们每台虚机在创建之后，都会分配到一个 Salt Minion ID，并连接到 SaltMaster 进行自身的配置变更。

利用这一点，SaltMaster 上是最清楚机器的实际变化了。

所以这里很简单，定期在 SaltMaster 上生成一份 Minions ID 列表，并放在本地的 HTTP 服务上提供下载。

我在 SaltMaster 上也做了一份对 salt 命令的 ZSH 补全规则。这样我本地执行 salt 命令就能自动补全常用命令和 ID 啦。

补全脚本是酱婶儿的：


{% highlight bash %}
 cat ~/.zsh/completion/_salt

#compdef salt
_arguments  \
  "1:keys:($(ruby -ryaml -e 'puts YAML.load(IO.read("/var/www/html/salt_keys.yml"))["minions"]'))"   \
  "2:commands:(test.ping cmd.run cmd.all cmd.exec_code state.sls pip.install saltutil.kill_job cp.get_file cp.get_dir)"
{% endhighlight %}

## 2. 本地根据网络和计划任务定时下载 ID 列表自动更新到自己的 hosts 文件

有了服务器提供的 ID 列表，本地下载读取更新自己的 hosts 文件就可以啦。

不过，我 Mac 的 hosts 有一些我的云主机、常用公网服务器配置，要自动更新 hosts 文件可以，可不能把我自己的配置给覆盖了，因此我在 hosts 文件里添加了一行特殊的注释行，为了分隔开我自己的 hosts 和自动生成的 hosts。

我平时要抱着我的 MBP 跑来跑去，不是所有时间都能连到运维网络上的。如果能根据我在哪判断出要不要连服务器下载 ID 列表岂不是很酷？其实可以使用 Mac 的网络位置非常容易的实现这个功能。

Mac 的网络位置是一个 Apple 自带的功能，你可以在 Mac 上任意设置你处在的不同网络配置，包括 IP 地址、网卡、DNS、WIFI 网络的优先级、VPN等等。配合 Alfred 快速切换网络位置的 Workflow，非常适合我这种经常处于家、办公网、运维网、VPN、设备调试网络等各种网络之间游荡的人。

所以我在脚本里增加了对网络的判断，当我处于 office_production 和 office_vpn 的网络位置就会下载 Salt Minion ID 文件。


{% highlight ruby %}
# encoding: utf-8

require 'open-uri'
require 'yaml'

$location_title_regexp = /office_(production|vpn)/
salt_file_url = 'http://xxx.xx.xx.xx/salt_keys.yml'

def in_the_location?
  current_location = `/usr/sbin/scselect`.lines.map{|x| $1 if x.match(/^ \*\s+[\w\-]+\s+\((.*)\)/)}.compact.pop
  current_location.match $location_title_regexp
end

def download_and_parse_salt_keys_file(url)
  begin
    open(url,:open_timeout => 10) do |file|
      return YAML.load(file.read)['minions']
    end
  rescue
    puts "Cannot download the Salt Key Files."
    exit 1
  end
end

def format_to_hosts(array)
  array.map do |name|
    "#{$1}\t\t\t\t#{name}" if name.match(/[\w\-]+\-(\d+\.\d+\.\d+\.\d+)/)
  end
end

def get_myself_hosts
  hosts = IO.read('/etc/hosts').lines
  my_self_hosts = []
  hosts.each do |line|
    if line.match /##### Auto Generate id: (\d+)/
      $count = $1.to_i
      break
    else
      my_self_hosts << line
    end
  end
  my_self_hosts
end

def merge_the_lines(myself,auto_generate)
  myself + ["##### Auto Generate id: #{$count + 1}\n","\n"] + auto_generate
end

def write_to_hosts(array)
  File.open('/etc/hosts','w') do |file|
    file.puts array
  end
end

if in_the_location?
  salt_hosts = download_and_parse_salt_keys_file(salt_file_url)
  auto_generate = format_to_hosts(salt_hosts)
  myself = get_myself_hosts
  hosts_lines = merge_the_lines(myself,auto_generate)
  write_to_hosts hosts_lines
end
{% endhighlight %}

现在，只有把这个脚本扔在计划任务里，每个小时自动跑上一次就好啦。

## 3. SSH 客户端的登录简化

因为我们这服务器的安全级别不同，也有很多历史遗留原因，造成很多不同业务系统的服务器登录用户，key、密码都是不同的，要一一记住这些，对我来说也是蛮烦的一件事。不过可以通过 ~/.ssh/config 文件对 ssh 客户端进行自动匹配，从而简化还要想用户名、用哪个 key 这样的操作。

这个文件大致是这样的：

在 Host 设置中可以使用通配符，这里是我服务器的 Salt Minion ID。因为我们 Salt Minion ID 的规则是从左自右依次减小范围的，所以写成`ops-*`。

User 设置登录用户，Port 设置端口，IdentifiFile 设置你要登录使用的 ssh key。

Host * 是默认配置，在这里可以使用 ControlMaster 选项设置 ssh 共享多个连接，只要连接文件（ControlPath 中定义）存在且服务器没有主动断开，你就可以一直不用密码地快速访问啦。


```
Host ops-*
  User ops


Host app1-*
  User app1user
  Port 22
  IdentityFile ~/.ssh/id_app1_serverkey


Host app2-*
  User app2user
  Port 30022
  IdentityFile ~/.ssh/id_app2_serverkey

Host *
  User root
  Port 22
  CheckHostIP yes
  Compression yes
  ForwardAgent yes
  IdentityFile ~/.ssh/id_rsa
  ControlMaster auto
  ControlPath ~/.ssh/%h-%p-%r
  ControlPersist 4h
```

## 4. ZSH 的自动补全

在这里我使用的是 oh-my-zsh 的自动 ssh 补全，本身没有做任何修改。


好啦，上述都配置好了之后，就可以不用再每天想着登服务器的时候发现IP、用户名、端口、ssh key 不对怎么办啦，不用再辛苦的去问同事哪里做了变更，还要再自己维护这些信息了。

有这时间，喝一杯咖啡，看看知乎岂不是更好。




