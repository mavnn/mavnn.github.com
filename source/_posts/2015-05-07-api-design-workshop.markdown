---
layout: post
title: "API Design Workshop"
date: 2015-05-07 15:35:51 +0100
comments: true
categories: [programming]
---
Designing an API is hard.

You want to actually apply the
[principle of least astonishment](https://en.wikipedia.org/wiki/Principle_of_least_astonishment) -
but you're the person who wrote the code. You're unlikely to be astonished. So
you're trying to think how someone who didn't know what you know would think -
which is never an easy starting point!

Similarly, you're trying to create the
[pit of success](http://blog.codinghorror.com/falling-into-the-pit-of-success/)
for users. Which means trying to make it *very hard* to do the wrong thing with
your API. Preferably, in strongly typed languages, this should include using the
type system to
[make illegal states unrepresentable](http://fsharpforfunandprofit.com/posts/designing-with-types-making-illegal-states-unrepresentable/)
so that code that compiles is very likely to work.

In general, the core libraries for .net are not bad at API design, but there are
a few places where this isn't true. As an exercise, we at
[15below](http://www.15below.com/) are going to take one of them, split into
teams and spend an hour or so seeing what alternatives we can come up with. Feel
free to follow along at home, and if you do give it a try ping me a code snippet
and I'll post it up with our internal attempts in a week or so.

<!-- more -->

## The API

Lots of things can be represented as streams of data. Files, network
connections, compressed archives, chunks of memory... the list goes on.

So .net provides us with the [``System.IO.Stream`` class](https://msdn.microsoft.com/en-us/library/system.io.stream%28v=vs.110%29.aspx?f=255&MSPPError=-2147217396).

Which is great and all... except that not all streams are equal. For example,
your function might need write access to a stream, and not all streams are
writable. You can check easily enough, but the only way of flagging to the user
you need write access is via comments or naming conventions. The same is true
for requiring the ability to read from the stream or seek to specific locations
with in it.

## The challenge

Have a look through the interface provided by ``System.IO.Stream``. Create a
skeleton of an API that could implement the same functionality, be reasonably
easy to use and tries to make illegal states unrepresentable as much as
possible. Note: this API does *not* have to be functional.

Try adding a few example methods that make use of your API (hint: your design
will probably be better if you write these first).

Maybe you want to try using interfaces and
[multiple interface constraints](http://stackoverflow.com/questions/3663739/method-parameter-with-multiple-interface-restrictions). Or
you have some clever idea for representing things with
[discriminated unions](http://fsharpforfunandprofit.com/posts/discriminated-unions/). Or
maybe you just know that there's a better core library out there with a nicer
representation you can rip off whole sale! Who knows?

Post your work up somewhere it can be seen on the internet and ping me a link,
and we'll go over the submissions and write up a commentary over the next week
or two.
