---
layout: post
title: "如何自动备份 Safari 书签"
subtitle: '嘿，我好像又发现了 Safari 的 BUG'
date: 2016-07-22
header-img: "img/home-bg-o.jpg"
author: "Echo"
tags: Safari Mac script
keywords: Safari Mac bookmarks backup automate
---

今天上午美男子找我，「我 Safari 的书签突然全没啦，怎么办？」

「你上次说买 [Time Capsule](http://www.apple.com/cn/shop/product/ME177CH/A/airport-time-capsule-2tb?fnode=5f) 后来买了吗？」

「还没啊。」

「那你试试登 iCloud 看看，我记得好像有恢复书签的功能。」

过了一会，美男子告诉我，确实在 iCloud 里找到了恢复书签的选项，包括通讯录，日历和 iCloud Drive 的文件，iCloud 都有恢复的功能。

这件事就这样结束了，然后我就在想，Safari 的书签是存在  ~/Library/Safari/Bookmarks.plist 里的，而 Safari 导出的书签实际上是一个 HTML 文件，其实写一个脚本就可以把书签自动备份了呀。

(我写这个就是写着玩，我平时用 Time Capsule 做备份也用不着这个。。。)

我尝试研究了一下，发现确实完全可行，但是发现了 Safari 的一个问题，Safari 在导入书签的时候，无法正确地识别`</dt>`标签。而且只能解析与`<dt>`标签处在同一行的书签。

这么说可能不易理解，我举例解释一下。

正常 HTML 生成的`<dt>`标签应该是闭合的。如果在输出后的 HTML 文件不换行，是下面的样式。

```html
<DT><a href="http://www.zhihu.com/">知乎</a></DT>
```

这种情况下，Safari 会错误的把`</dt>`前面的`</a>`也解析成书签名，书签名会变成`知乎</a>`

如果输出允许 indent，例如下面的样式：

```html
<DT>
  <a href="http://www.zhihu.com/">知乎</a>
</DT>
```

。。。Safari 根本就认不出来这个书签啦。

我试验出的结果是，Safari 在导入书签的时候，只能识别出非闭合的`<dt>`标签，并且需要把书签放置在`<dt>`标签的同一行中，例如下面这样才能够正常的解析。

```html
<DT><a href="http://www.zhihu.com/">知乎</a>
```

由于上面的问题，而且 xsltproc 将 xml 转换成 html 的时候，没法转换非闭合的标签，最后我在写脚本的时候，只能在导出 HTML 时，加了一个 sed 删除所有的`</dt>`标签，这真让强迫症痛苦。。。

最后附上脚本。

自动备份脚本的使用方法：

将 「[备份脚本](https://gist.github.com/echohn/eb8f31165aa288a3d0de115ac11ee543) 」与「 [转换模板](https://gist.github.com/echohn/4c5edcd8697b29cec9bafb36889e6953) 」下载到同一目录，然后在 crontab 里添加执行 `SCRIPT_PATH/backup_safari_bookmarks.sh OUTPUT_PATH`即可,其中 OUTPUT_PATH 是书签备份将存放的目录，脚本执行之后，会在这个目录下生成一个文件名为当天日期的 HTML 书签文件。

导入备份书签的方法：

选择 Safari -> 文件 -> 导入自 -> 书签 HTML 文件...，然后选择最新的备份文件恢复即可。 








