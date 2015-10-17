---
layout: post
title: Alfred 自动补全的技巧
date: 2015-10-17
categories:
tags: Alfred Ruby
---

在写这个 [RubyGems Workflow]({% post_url 2015-10-17-rubygems-workflow %}) 这个 Workflow 的时候，我发现了 Alfred 一点很有用的地方，就是对查询的结果进行自动补全，在补全后对查询结果进行另外的操作。

当 Feedback 的 valid = no 时，就可以通过 autocomplete 属性自动补全 Feedback 。

{% highlight ruby %}
{
  :uid      => result['name'],
  :title    => result['name'],
  :subtitle => "Downloads: #{result['downloads']} ; Info: #{result['info']}",
  :arg      => result['name'],
  :autocomplete => result['name'] + ' : ',
  :valid    => 'no'
}
{% endhighlight %}

而 autocomplete 的值就是第二次查询的 query，所以需要在脚本开始接收 query 的地方对结果进行解析，映射到不同的方法上。

{% highlight ruby %}
if query.match ':'
  info query.split.first
else
  search query
end
{% endhighlight %}

在补全之后的方法中，记得将 Feedback valid 属性的值设为 `yes`。









