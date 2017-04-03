---
layout: post
title: "Teaching F# to C# Devs"
date: 2013-09-17 11:12
comments: true
categories: [fsharp, programming, teaching]
---
So, in a fit of enthusiasm my boss bought 15 tickets to the [London Progressive F# Tutorials]("http://skillsmatter.com/event/scala/progressive-f-tutorials-2013") when he saw the early birds pricing (did I mention it's nice working here?). Several of the people who have been assigned tickets have asked to go largely because they are new to F#, so I've been asked to put together a starter session to teach them the basics. I've tried this [once before]("https//blog.mavnn.co.uk/an-introduction-to-f-screencast-and-pdf-slide") and it was a fairly successful session (F# was adopted as a official supported language in the company partly due to feedback following it). But it was still pretty rough around the edges, and as normal with these things, you always want to do them better the next time round...

So, with a target audience of curious, experienced C# devs I'm wondering about the best approach. The initial session needs to fit in an hour, although I can do individual follow ups afterwards.

My current thinking is to take a block of C# code (smtp sender?) that is fairly straight forward but 'production ready' in the sense that it includes error handling, logging, etc. Then do a straight re-write in F# live coding. And then start refactoring to more idiomatic F# as we go along.

Features I feel would be important to cover:

* Basic syntax (let, functions, if ... then, etc)
* Common idioms (|>, Seq.map)
* At least one computational expression (probably an error handling one; simpler than async in some ways)
* Several examples of using the match statements
* ...which probably means at least one DU, possibly for error handling
* Records and { ... with ... } expressions

I've got a week or two to prepare, so what I'm really hoping for at this point is suggestions and ideas from people for how to improve this as a session idea, things that threw you when you first started writing F# you think should be covered, whether you think this is a stupid idea for a session from the concept up, etc. Once the session is completed I'll be posting the slides and hopefully a screen cast of it as I did last time for use by [fsharp.org]("http://fsharp.org").

Suggestions on the piece of C# code to translate would also be appreciated - either in terms of ideas of the type of code, or actual open source code that would serve as a code starting point.
