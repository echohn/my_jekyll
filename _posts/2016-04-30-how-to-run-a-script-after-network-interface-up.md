---
layout: post
title: "How to run a script after network interface up"
date: 2016-04-30
categories:
tags: script linux
---

我懒，我喜欢让自己的工作环境变得轻松，喜欢 Automate Everything 。

今天在用 Vmware Fusion 测东西的时候，我就发现我虽然在虚机模板上做了各种优化，但是每次新创建一个链接克隆的时候，我居然还要在 Fusion 中进入虚机，登录，敲个`ip a`看一下 ip 地址，再 `⌃` + `⌘` 退出虚机，然后才能在 iTerm 中 ssh 这个虚机，这让大处女座怎么忍（其实我是射手）！

所以就想，干脆启动虚机的时候能看到 ip 地址就好啦。

虽然 /etc/issue 是纯文本，可是这怎么能难住哥，我很快就写好了一个在 /etc/issue 显示 ip 地址的小脚本。

然后正当习惯性想把脚本加到 rc.local 的时候，突然想到，这样岂不是只能开机启动了才生效？IP 地址是与网卡绑定的，得随网卡启动才好吧。

我之前虽然试过在网卡启动后自动添加路由，可是还没试过在网卡启动之后自动运行脚本呢。

直接 google，找到了[这篇文章](http://xmodulo.com/how-to-run-startup-script-automatically-after-network-interface-is-up-on-centos.html)。

嗯，ifup-post 脚本里真有下面这么一句呢（其实没有自己手动添也行）。


{% highlight bash %}

if [ -x /sbin/ifup-local ]; then
    /sbin/ifup-local ${DEVICE}

{% endhighlight %}

于是就写了 `/sbin/ifup-local` 这么个脚本。

因为这个脚本是每启动一个网卡就要执行一次，我嫌麻烦还要判断网卡，干脆就直接都写一样的了。

{% highlight bash %}
#!/bin/bash

addr=$(ip a | awk '/scope global/{print $NF" ipaddress : "$2}')
file="/etc/issue"

sed -i '/ipaddress/d' $file
sed -i '/^$/d' $file

mv $file ${file}.bak
echo $addr > $file
echo >> $file
cat ${file}.bak >> $file

{% endhighlight %}

最后新建一台虚机看一下效果，完美~！

![](/assets/post_images/3.png)







