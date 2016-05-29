---
layout: post
title: Ruby 强制解构
date: 2015-10-17
tags: Ruby
keywords: Ruby Rake 解耦 数组 block 技巧 参数
---

今天在写 Rakefile 的时候，突然想起之前看过 Ruby 的一个小技巧。

我们经常使用 `|x,y|` 的形式在 block 中对传参的数组进行解构，那么在类似 reduce 的方法中，也可以使用 `()` 强制对参数进行解构。

例如：

{% highlight ruby %}
[2] pry(main)> a = [['foo1','bar1'],['foo2','bar2']]
=> [["foo1", "bar1"], ["foo2", "bar2"]]
[3] pry(main)> a.inject([]) {|a,(x,y)| a << x if y == 'bar1' ; a}
=> ["foo1"]
{% endhighlight %}

