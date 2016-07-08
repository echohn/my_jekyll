---
layout: post
title: "打造基于 ShadowSocks + ProxyChains 的全栈式科学上网工具"
date: 2016-05-29
header-img: "img/contact-bg.jpg"
author: "Echo"
tags: Mac 科学上网 ShadowSocks Alfred
keywords:  翻墙 工具 科学上网 ShadowSocks ProxyChains Mac GFW FuckGFW Lantern 蓝灯
---


最近不知道为什么，[蓝灯（Lantern）](https://www.getlantern.org)用着经常出问题，要么非常慢，要么报错。

说实话 Lantern 正常的时候，真是要比我放在东京的 SS (ShadowSocks) VPS 快出很多的。看片一点都不费劲。

没办法之下，我切换回了 SS。还好我之前配置的 SS 直接可以拿来用，自动更新脚本也一直运行着。在这里记录一下我之前 Mac 配置 SS 等相关翻墙工具的过程。

你可能会疑惑，我写的全栈式科学上网工具是什么？

好吧，其实，我就是一个标题党……

我们知道，ShadowSocks 主要用于浏览网页，也可以用于一些支持 Socks 代理的应用（比如 Dropbox）。但是如果想让命令行工具也走 SS 代理，虽然也可以打开 SS 的全局模式临时用一下，但是如果命令执行的时间过长，在全局模式下还是很影响上网体验的。

所以，我今天所谓的全栈式科学上网不仅包括 SS 的配置，也包括了命令行代理工具 ProxyChains 的配置部分，以及如何自动更新 GFWList 。只要照着配下来，以后基本就不用再折腾翻墙的事了。


## SS 的原理

我推荐 vc2tea 的这篇介绍原理的文章：[写给非专业人士看的 Shadowsocks 简介](http://vc2tea.com/whats-shadowsocks/)。


## ShadowSocks Server 端的搭建

嗯，SS 搭服务器是蛮简单的，前提是你要有一台国外的 VPS 来做中转。 VPS 我个人之前一直在用 [DigitalOcean](https://www.digitalocean.com)，当年觉得它每月 $5 的 VPS 实在是便宜。不过感觉近些年大家都在降价，DO 现在没有什么价格优势了。而且我测试过 DO 各机房到我家（北京联通）的网络质量，普遍不佳，最终矬子里拔大个，选了 Toronto 机房，网络质量相比其他机房稍微好一点。

最近看到 AWS 的推广，可以有 12 个月的免费体验，我又注册了 AWS ，暂停了 DO 的 VPS 。 AWS 的东京机房到我这的网络质量还蛮不错，至少比 DO 强太多了。

下面简单介绍一下在 VPS 上如何装 ShadowSocks Server 端。

安装依赖。

{% highlight bash %}
sudo apt-get install build-essential autoconf libtool libssl-dev
{% endhighlight %}

下载并编译安装。

{% highlight bash %}
git clone https://github.com/shadowsocks/shadowsocks-libev.git
cd shadowsocks-libev/
./configure --prefix=/opt/shadowsocks
make
sudo make install

{% endhighlight %}

启动 ShadowSocks Server 。

```
/opt/shadowsocks/bin/ss-server -p 10080 -k password -m aes-256-cfb --fast-open -f /tmp/shadowsocks.pid
```

这里我指定的端口是 10080，密码是 password，加密方式是 aes-256-cfb，这几项信息在 SS 客户端中都是要填的。

## ShadowSocks 客户端的配置

略。就照着上面服务器的信息配置就行了。

当你把客户端配置好，现在就可以在浏览器中体验科学上网了。

## ProxyChains 的配置

如我们之前所说的，浏览器科学上网只是一部分，身为一名工程师或非 Windows 用户，我们经常会使用到一些命令行工具，想让命令行工具科学上网肿么办？

ProxyChains 就是一个这样用途的工具，它可以让你的其它工具通过 Socks 或 HTTP 代理访问网络。


首先从 Homebrew 安装 ProxyChains。

{% highlight bash %}
brew install proxychains-ng
{% endhighlight %}

然后做一些配置，它默认会读取安装目录下的 etc/proxychains.conf 配置文件，因为我想跟我其它的 dotfiles 一同管理，所以我把它放在了 ~/.proxychains.conf ,其文件内容如下：


```
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
quiet_mode
[ProxyList]
socks5  127.0.0.1 1080
```

*需要说明一点，在这里我配置的是 strict_chain。如果你有多重代理，类似我之前一样，比如让命令先通过 Lantern 代理出去，如果失败再走 SS 代理，可以配置成 dynamic_chain 模式。不过这超出今天的文章范畴了，我还是以 strict_chain 举例，如果你对 dynamic_chain 感兴趣，可以自行研究。*


因为指定了配置文件的路径，为了方便使用，我在 ~/.zshrc 里加一行 alias。


{% highlight bash %}
alias pc="proxychains4 -f ~/.proxychains.conf"
{% endhighlight %}

在执行 `source ~/.zshrc` 重新加载环境变量之后，就可以尝试是否配置成功了。


{% highlight bash %}
pc curl https://twitter.com
{% endhighlight %}

## 自动更新 GFWList

ShadowSocks 客户端自带有从 GFWList 更新 PAC 的功能，但是由于某个你懂的原因，自动更新基本都是失败的。

不过没关系，你可以下载这个[update_gfwlist.sh 脚本]( https://raw.githubusercontent.com/echohn/shadowsocks-alfred-workflow/master/update_gfwlist.sh
)来进行更新 GFWList 。

这个脚本的来源我忘记了，我只记得是之前我研究管理 dotfiles 的时候，从别人的 repo 里拷过来的。

我把这个脚本放在 ~/.ShadowsocksX/ 目录下，这样可以它随着我的 mackup 一同备份到 Dropbox 上了。

对了，别忘了给这个脚本赋执行权。

然后在 crontab 里添加一行计划任务：

```
30 9 * * * /Users/Echo/.ShadowsocksX/update_gfwlist.sh
```

这样，每天早上 GFWList 会自动更新，你不用再去管它。

## 手动添加域名至 GFWList

可能会有这种情况：

1. 哪天上网的时候，突然发现想要访问的网站直连非常慢，希望通过 ss 进行代理访问。
2. 发现这个网站被墙了，但是还没收录在 GFWList 里。

碰上以上这两种情况，你可以自己编辑 ~/.ShadowsocksX/user-rule.txt 文件。把每个网站的域名作为一行记录添加进去，再执行一次 update_gfwlist.sh 脚本以更新到 ShadowsSocks。这样做比直接在 gfwlist.js 里加记录要好一点，因为下次 GFWList 更新的时候，不会把你自己收录的域名覆盖掉。

## ShadowSocks 的 Alfred Workflow

如果你是 小帽子 [Alfred](https://www.alfredapp.com) 的用户，你可以直接使用我写的 [ShadowSocks-Workflow(点击下载)](https://github.com/echohn/shadowsocks-alfred-workflow/raw/master/shadowsocks.alfredworkflow)。在 Alfred 中执行 ssadd ，然后粘贴你准备加入 gfwlist 的 url，url 的域名就添加进 ShadowScoks 了。

![](/img/in-post/ss.png)


至此，我的全栈式科学上网工具就配置完了。现在不论是浏览器应用还是命令行，都实现了科学上网的功能，又提供了方便快捷的更新方式，对我来说，已经足够应付日常使用了。

如果你使用了其他好的工具与方法科学上网，也非常欢迎你与我交流。





