---
permalink: /a-short-interlude-into-adaptive-polling-tag-f/
layout: post
title: A short interlude into adaptive polling
published: true
comments: true
categories:
- 15below
- fsharp
- killTheConfig
- Programming
---
Your windows service is watching an email inbox.

How often should it poll?

Once every 5 minutes? Every 10? Then of course you realise that it should be different for every customer… or maybe every mailbox. You need more config!

### Or not.

The real answer, of course, is something completely different: it should poll a lot when a lot of emails are arriving, and not very much when they aren’t.

It took a lot longer than it should have done to get my maths brain back on, but with the help of my wife I eventually settled on this code for deciding the intervals between polls:

``` fsharp
let interval i =
    let x = float i
    let maxWait = 60. * 10.
    let raisePower x = pown (x /10.) 4
    (maxWait * (raisePower x)) / (raisePower x + 1.)
    |> (*) 1000. |> int
```

The ‘i’ in this function is the number of times we’ve polled since the last time a new email was received (if one is received, we reset i to 0).

If you plot this out on a graph, you get something that looks like this:

<img src="http://www.wolframalpha.com/share/img?i=d41d8cd98f00b204e9800998ecf8427ehd954rh40i&amp;f=HBQTQYZYGY4TOM3CGRSGMMBWGAYDCM3DGYZGMOBWGFRDANDCMUZAaaaa" alt="" />

You can play with the shape of the graph at [Wolfram|Alpha if you're feeling really geeky](http://www.wolframalpha.com/share/clip?f=d41d8cd98f00b204e9800998ecf8427ehd954rh40i) :).

This gives us very aggressive polling for the first few minutes after discovering an email, then dropping off rapidly to close to the one every ten minutes mark that I decided was a reasonable background polling rate.

It's not truly adaptive in the machine learning sense, but it gives a very good first cut that is an awful lot better than any fixed value could be.
