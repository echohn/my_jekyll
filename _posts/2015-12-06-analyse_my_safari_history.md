---
layout: post
title: "看看自己平时上网都在干嘛？"
subtitle: "分析自己的 Safari 历史记录"
date: 2015-12-06
tags: Mac Safari
keywords: mac safari 知乎 历史 历史记录
---

昨天在知乎逛，看到一个问题[可以用 Python 编程语言做哪些神奇好玩的事情？](http://www.zhihu.com/question/21395276),其中有一个人写了一个脚本统计自己 chrome 浏览记录的 Top 10，我就在想，诶，这个好玩好玩好玩，我也想看看我平时都看嘛了，虽然心中早有猜测，也看看实际情况跟自己心中所想是不是一样。

于是查了一下，Safari 的历史记录文件是`~/Library/Safari/History.db`，file 了一下这个文件，原来它是个 SQLite 数据库哈哈哈，苹果还真是贴心……

于是写了一条 sql 来查：


{% highlight sql %}

select domain_expansion,count(domain_expansion) from "main"."history_items"  group by domain_expansion  ORDER BY count(domain_expansion) desc limit 0,20

{% endhighlight %}


结果是这样的，还真的有点出乎意料。

|domain_expansion|count(domain_expansion)|
|------|------|
|baidu|8645|
|m.baidu|2588|
|zhihu|1339|
|github|1126|
|image.baidu|824|
|bbs.feng|642|
|m.qb5|544|
|baike.baidu|476|
|detail.tmall|470|
|zhidao.baidu|458|
|s.taobao|455|
|dashubao|448|
|item.jd|414|
|pan.baidu|397|
|item.taobao|383|
|v2ex|339|
|bttiantang|336|
|tieba.baidu|321|
|waitsun|292|
|google|213|

一条条来分析：

1. 百度是我的默认搜索引擎。俗话说内事问百度，外事问 Google 。虽然我平时开着 ss，但是由于普遍通过 ss 访问还是比较慢，所以除了查技术资料走 google 外，平时百度我确实用的不少，百度能登顶在意料之中。但是 image.baidu，zhidao.baidu 居然都能进前 20 是个什么鬼？我又分别对这两个搜了一下，随便点了一些例如 qq 表情、Macbook Pro 15'(怨念啊。。。)、龙庆峡等等的图片；以及貂绒大衣为什么比羽绒服暖和，关于吉列温和型剃须啫哩香味等等的问题，我也给自己跪了。。。
2. 知乎、v2ex 是平时娱乐两大网站、能在 Top 20 我也不意外。
3. github 作为全球最大同性交友网站我就不说什么了。
4. bbs.feng 估计是 IOS 9 越狱那阵给闹的。
5. qb5 和 大书包 ╮(╯_╰)╭ 好吧，我承认我上班时候看网络小说来着……
6. tmall、taobao、jd：嗯，双十一我真的没买东西，真的……这都是平时网购积累的。
7.  pan.baidu：现在分享个东西都走它，它能上榜也算积少成多吧。
8. bttiantang：是我平时网上找电影的第一选择。
9. tieba.baidu：这都能上榜，只能说贴吧的圈子真的很大。
10. waitsun：我为我用了不少盗版软件而羞愧。


## 总结

首先感慨一下，百度的生态圈子确实大，虽然我平时没少跟人黑它，但是由于 Google 访问慢，我确实每天也很依赖它。

其次，我以后一定少看小说，有时间还是多扫扫 Pocket，刚打开手机看了一下，未读又堆到快700了。

最近开始读李笑来的《把时间当做朋友》，感觉很有收获，希望真能开启心智，发扬精神，好好治一治我的精神病。
