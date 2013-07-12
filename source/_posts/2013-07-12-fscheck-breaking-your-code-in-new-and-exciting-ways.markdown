---
layout: post
title: "FsCheck - Breaking your code in new and exciting ways"
date: 2013-07-12 11:55
comments: true
categories:
- fsharp
- programming
---
[FsCheck](https://github.com/fsharp/FsCheck) is a property based testing library for .net. Based on [QuickCheck](http://book.realworldhaskell.org/read/testing-and-quality-assurance.html) and [scalacheck](https://github.com/rickynils/scalacheck) it can be easily called from any .net language.

But what is property based testing? It's a technique that allows us to define 'properties' for our code, and then let the library try and find input values that break these properties. Let's take an example and see what happens.

### The Brief

I've been tasked with writing the backend of a public facing endpoint. Customers can pass user defined input into the endpoint, and we'll add it to their 'booking'. Once they have called the service once with any particular input, we should ignore any further calls with the same value.

Previous architectural decisions mean that we are storing the bookings as XML documents.

(Why yes, I do know this is slightly contrived. Thank you for asking. Hopefully though, you should begin to see similarities to real scenarios you've coded against.)

### What can we get out of this?

Well, as well as any normal exploratory unit tests we may decide to write (which I'll ignore for this article to keep things succinct) we can determine a few properties that should always hold true in the brief above:

* Repeatedly calling the code with the same input xml document and the same input text should always give us the same result. I.E., the code should be idempotent.
* Our code should never remove nodes from the XML. The result document will always be the same or longer than the original.
* The input is supplied by the customer. It's about as trust worthy as a hungry stoat on speed.

### Let's get started

Let's start off with the core 'business logic' function of this code. We'll ignore for this post how the input gets to the function, and how the document is persisted. It's signature (F# style) will be:

    val AddEnhancement :
      xDoc:System.Xml.Linq.XDocument -> input:string -> System.Xml.Linq.XDocument

After referencing `System.Xml` and `System.Xml.Linq`, our first, very naive, attempt at the implementation looks like this:

{% gist 5983701 Part1.fs %}

We know this isn't right - it's blatantly not idempotent. So let's try and get our failing test.

Although FsCheck does expose a set of NUnit plugin attributes, for this blog post I'm just going to run the tests via a console app. So; add a new F# console app to your solution, add references to `System.Xml`, `System.Xml.Linq` and your library project then grab FsCheck (it's on NuGet) and we'll see what we can do.

First, we'll need to add a property that we want to test. A property is simply a function that takes a data type FsCheck knows how to generate, and returns a bool. FsCheck knows how to generate strings, so our idempotence property looks something like this:

{% gist 5983701 Part2.fs %}

Looking good. How do we run it? Just add this to the end of the file:

{% gist 5983701 Part3.fs %}

And hey presto:

!["" broke my code :(](/images/FsCheck1.png)

Failing test. Interestingly (and if you check the documents, not coincidently), FsCheck has found the 'simplest' possible failure case: `""`. Of course, it was helped on this occasion by the fact it was also the first input it tried.

So; let's add some checking to `AddEnhancement` to make sure we don't re-add the same input more than once.

{% gist 5983701 Part4.fs %}

And re-run the test and... oops.

{% gist 5983701 Part5.txt %}

And this is where the full power of FsCheck starts becoming apparent. I know my input is untrusted, so I've told it to generate *any* string. And it believed me, and has created an input string that breaks `System.Xml.XmlEncodedRawTextWriter.WriteElementTextBlock`. This is not a unit test I would have thought to write myself, as I'd managed to miss that the fact that [not all utf-8 characters are valid in utf-8 encoded xml](http://blog.mark-mclaren.info/2007/02/invalid-xml-characters-when-valid-utf8_5873.html). In fact, it took me more than a few minutes to work out why it was throwing.

At this point FsCheck has revealed to us that our initial brief is actually incomplete; we've told the customer that we're willing to accept utf-8 strings as input, but our storage mechanism doesn't support all utf-8 strings. To even get FsCheck to run, we'll have to decide on an error handling strategy - and importantly, it will have to be a strategy that still fulfils the initial properties specified (unless we decide that what we've discovered so fundamentally breaks our initial assumptions that they need to be re-visited).

This is a toy project so I'm going to bail slightly on this one: I'm going to assume that invalid values just add an error node with a 'cleaned' version of the input which could then be reviewed by a human at a later date. This has the advantage that it still fulfils all of our properties above.

Fortunately for us, in .NET 4.0 and above there is a function in the `System.Xml` namespace called `XmlConvert.IsXmlChar` which does roughly what you would expect from the name. Let's add an invalid character filter, and an active pattern to tell us if any characters have been removed:

{% gist 5983701 Part6.fs %}

Now we can amend `AddEnhancement` to add enhancement nodes for valid XML text or an error node for sanitized invalid XML text:

{% gist 5983701 Part7.fs %}

And when we run FsCheck again:

![Hurrah!](/images/FsCheck2.png)

Excellent stuff.

As a bonus extra, I've included below a somewhat expanded version of the test code. Remember I said that FsCheck already knows how to generate strings? Unfortunately it doesn't know how to generate XML out of the box, but I was pleasantly surprised how quick and easy it was to write a naive XML generator. It generates [XML like this](https://gist.github.com/mavnn/5976004#file-example-xml). Also, check out the `CheckAll` function used at the end which allows you to build and run 'property classes' to group families of properties together.

And, of course, per the specification, it checks that the 3rd property above holds true (that adding enhancements never reduces the size of the document).

{% gist 5983701 Part8.fs %}

Thanks for reading this far. If you want to play yourself, a full copy of the example code is [on GitHub](https://github.com/mavnn/DevEd.FsCheck) with an MIT license.