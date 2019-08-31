---
layout: post
title: "Shake: The Intro"
date: 2019-08-28 19:14:20 +0100
comments: true
categories: [haskell, shake]
---
At [NoRedInk](http://noredink.com) we've been looking into using [Shake](https://shakebuild.com/) to incrementally build large polyglot projects. In general, it's been a great tool to work with, but there were a few things that caught us out, so I wanted to capture some of that learning before it got lost.

Shake is basically a domain specific language built on top of Haskell, so knowing Haskell can definitely help you unlock it's full power. But you can get a long way for basic builds by just working with some simple building blocks. You will have to jump through some extra hoops to get it installed and write your scripts with editor support if you're not using Haskell anyway - but we are, so that wasn't much of an obstacle for us!

I'm not going to go into the really basic ideas behind Shake: the main website (linked above) has a good introductory demo, and Neil Mitchell (who wrote Shake) has given numerous (very well done) talks on the ideas behind it. What I'm going to do over a few posts is look at some of the things which caught us out, and what you can do about them. I'll try and remember to link each post here as it comes out!

1. [Linting](/shake-linting)
1. [Generated Files](/shake-generated-files/)
