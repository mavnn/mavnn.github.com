---
layout: post
title: "To Infinity and Beyond"
date: 2013-10-31 07:41
comments: true
categories: [fsharp, programming]
---
So, a couple of weeks ago I went to the Brighton Functional Programmers meet up. It was a fun night, and at one point I ended up live coding in front of a room of functional programmers trying to give examples of lazy and strict evaluation.

The canonical go to tool for the job, is of course the infinite sequence and being stared at by a bunch of people and having syntax highlighting but no compiler, the first thing my brain pulled out of the air was this:

{% gist 7246744 Part1.fs %}

Which prompted one of the people attending (hi [Miles!](https://twitter.com/milessabin)) to comment "let's see that in Haskell without the bizarre looping generator". Roughly - I'm slightly paraphrasing here given the couple of weeks in between. He has a bit of a point, this isn't the most functional looking sequence generator in the world, and it looks like quite a lot of code to just generate a lot of ones.

As always in these situations, I had of course thought of several other alternatives before I even reached my chair, so I thought I'd have a quick survey of them and their advantages and disadvantages.

My first thought was that I'd missed the obvious and succinct option of just generating a range. In F# (as in Haskell) the 1 .. 10 notation generates a list of the integers from 1 to 10. Unfortunately:

{% gist 7246744 Part2.fs %}

Unlike Haskell, you can't have an unbounded range, nor can you set the "step" to zero to just keep on generating the same number. So you're limited to generating very big, but definitely not infinite sequences:

{% gist 7246744 Part3.fs %}

But hey! We're in functional world. So if we can't use sneaky built in syntax constructs, the next obvious choice is a recursive function:

{% gist 7246744 Part4.fs %}

This is definitely infinite, and definitely functional in style. Bit verbose, of course, but it least it won't stack overflow as F# implements tail call recursion. It's verbose, but it does also have its advantages. It's trivial to pass things round in the recursive function (previous values from the sequence, etc) making this a very flexible way of generating sequences.

And, of course, let's not ignore the standard library. The `Seq` module gives us a couple of methods designed specifically for generating (potentially) infinite sequences.

`Seq.initInfinite` just takes a function that returns a sequence value based on the index of that value:

{% gist 7246744 Part5.fs %}

As long as a simple mapping from index to value exists, this is both clear and concise. In theory, of course, it also suffers from the same issue as my range generators above: if your index exceeds the valid size of an Int32 you're out of luck.

`Seq.unfold` may seem less intuitive, but in my mind is the more flexible and powerful solution. I tend to come across examples where it's easier to generate a sequence based on either some state or the previous term than by index, and that's exactly what unfold allows you to do:

{% gist 7246744 Part6.fs %}

It will also happily generate sequences forever if your generating function allows.

So, how does it actually work? Let's look at a (slightly) more complex example that actually makes use of some state:

{% gist 7246744 Part7.fs %}

What's going on here then? Well, `unfold` takes two arguments. The first is a function that takes a 'State and returns an Option<'T * 'State>. In our simple example above, both 'State and 'T are of type `int` but there's no requirement for them to be of the same type. If at any point the function returns `None`, the sequence ends. In our example, we always return `Some`, so our sequence is infinite (at least until it runs out of integers) and we're return a tuple of two values - the first of which will be used as the next term in the sequence, and the second which will become the new state.

The second argument to `unfold` is the starting state. In our case, this means the number that will be the first term in the sequence, and then we'll add one to it each time.

Let's round this out with an example that uses different types for the state and the terms of the sequence, which will hopefully now make some sense:

{% gist 7246744 Part8.fs %}

I'm sure that you've always needed a convenient way of cycling through every minute of the day repeatedly, with a nice readable string representation.
