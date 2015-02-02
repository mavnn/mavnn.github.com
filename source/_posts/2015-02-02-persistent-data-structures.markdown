---
layout: post
title: "Persistent Data Structures"
date: 2015-02-02 15:36:51 +0000
comments: true
categories: [15below,programming]
---
In last week's [Developer Education session](/keeping-up-with-the-latest-hammer/) at [15below](http://15below.com) we had a look at immutable and persistent data structures, and why you'd want to use them.

> TL;DR version: are you writing performance critical, real time code? Do you have less memory available than a low end smart phone? No?
>
> Use immutable data types everywhere you can.

The session was inspired by [Scott Wlaschin](https://twitter.com/ScottWlaschin)'s excellent [is your programming language unreasonable?](http://fsharpforfunandprofit.com/posts/is-your-language-unreasonable/) post. If you haven't read it yet, go and do so - it's much better than the rest of this post, and you can always come back here later if you remember.

One of the points that Scott raises is that code written with mutable data structures (ones that you can change after they've been created) is very hard to reason about. In the very literal sense of working out the reason why things happen.

<!-- more -->

So we kicked off with a couple of examples of the dangers of mutability. Consider the following C# code.

``` csharp
static void Main(string[] args)
{
    var mercurial = new List<string> { "Bob" };
    DoWork(mercurial);

    if (mercurial.First() == "Bob")
    {
        Console.WriteLine("Yay! We have Bob!");
    }

    DoSomeOtherWork();
    // Actually get around to doing some work.
    if (mercurial.First() == "Bob")
    {
        Console.WriteLine("Success");
    }
    else
    {
        Console.WriteLine("Oops, I updated {0}'s record by mistake.", mercurial.First());
    }
    
    Console.ReadLine();
}
```

Does it update Bob's record, or someone else's? Well - this is Scott's point. We've passed the mutable ``mercurial`` object (here a ``List``, but it could be anything mutable) into a function (``DoWork``), and now we don't know what will be done to it. Even if we check that it has the value we were expecting (line 6) there's no guarantee that it won't be changed under our nose. Which in fact, it is, because the rest of the code looks like this:

``` csharp
private static void DoSomeOtherWork()
{
    System.Threading.Thread.Sleep(500);
}

private static async void DoWork(List<string> Mercurial)
{
    new Immutable.Thing("Hello world", 1);
    await Task.Delay(100);
    Mercurial.Clear();
    Mercurial.Add("Fred");
}
```

This example is clearly contrived - but these kinds of bugs crop up in code a lot, and it doesn't even need to be asynchronous for it to happen.

We then discussed equality, and the fact that it can be very hard to decide what equality means for a mutable object. Is a customer object the same as another customer object because they both have the same Id? Because they're both the same object in memory? Because they have the same value in all of their fields? What happens if one of the fields is changed? Overriding equality in .net [is not trivial](http://visualstudiomagazine.com/articles/2011/02/01/equality-in-net.aspx).

Immutable objects cannot be changed, which means that they are nearly always defined as having value based equality. If all of the fields are equal, the object is equal - and it can't change, so you don't have to worry about it shifting under you. This is such a useful property (especially if you're loading data from another source that you want to run comparisons on) that we've even had occasions here where we've considered implementing our data types as [F# records](https://msdn.microsoft.com/en-us/library/dd233184.aspx) even when writing C# services.

For example, you can define an F# record like this:

``` fsharp
// Yes, this is the entire file
module Immutable

type Thing =
    {
        One : string
        Two : int
    }
```

And then use it from C# like this:

``` csharp
// You do need to reference the project with Thing in
static bool UseRecordTypeFromCSharp()
{
    var myThing = new Immutable.Thing("Hello", 11);
    var myThing2 = new Immutable.Thing("Hello", 11);

    return myThing == myThing2; // Always returns true
}
```

If all you need is an immutable collection, rather than an immutable
object with nice value based properties then you don't even need to
leave the comfort of your C# window. Microsoft themselves have bought
into the concept of immutable data structures sufficiently to release
an [Immutable Collections](https://msdn.microsoft.com/en-us/library/dn385366%28v=vs.110%29.aspx) library.

### But what about the memory? Think of the RAM, the poor RAM!

We also discussed the downsides of immutable data types. There are two concerns which are raised most frequently. The first is performance - in .net, using immutable data structures and then doing a lot of transforms on the data will create a lot of objects. This can have a significant effect in very performance critical areas of your code. This is a valid concern where performance is paramount, and the normal way around this is to wrap a private mutable object (or raw array, for
that matter) in a function that does all of your heavy manipulation. In that way you can take advantage of the speed of imperative coding techniques whilst keeping their scope small enough to reason about the effects.

Of course, even if **speed** isn't of paramount importance - what about **memory**? After all, these allocations must be adding up on the memory side of things as well, no?

Well, not as much as you might think, for two reasons. One is that if your code is asynchronous, you're almost certainly taking copies of your mutable data structures all over the place anyway to guarantee thread safety. Well, either that or you're taking a lot of locks, and you're back into performance issues.

The second, and much more interesting, reason is that a very bright guy called Chris Okasaki realised back in 1996 (despite the recent surge of interest in functional programming, it's not new...) that you can take advantage of the fact that an object is immutable to avoid copying all of it when a new, similar object is required.

For example, if you add a new object to the end of an immutable list, the new list you get back doesn't need to be a complete copy - it can just be the single new item with a pointer back to the original list. To the person using the list, it appears to be a three item list and they are none the wiser. Because it's immutable, the first two values never change, so it's never a concern to you whether your list is a completely new one, or a "pointer" list. Okasaki called these data
types "persistent" data types as they "persist" a previous version of themselves when "modified". You can read more about them in a [surprisingly complete wikipedia article](https://en.wikipedia.org/wiki/Persistent_data_structure).

In .net land, both the F# immutable records and collections, and the ``System.Collections.Immutable`` library from Microsoft mentioned above are persistent data types. So unless you're extremely memory constrained, you should be good to go.

And there you have it. An introduction to immutable data types: officially approved for use almost everywhere by your local Technical Architect.
