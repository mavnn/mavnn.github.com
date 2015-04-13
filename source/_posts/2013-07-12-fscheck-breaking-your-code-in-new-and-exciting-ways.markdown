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
* The input is supplied by the customer. It's about as trustworthy as a hungry stoat on speed.

### Let's get started

Let's start off with the core 'business logic' function of this code. We'll ignore for this post how the input gets to the function, and how the document is persisted. It's signature (F# style) will be:

    val AddEnhancement :
      xDoc:System.Xml.Linq.XDocument -> input:string -> System.Xml.Linq.XDocument

After referencing `System.Xml` and `System.Xml.Linq`, our first, very naive, attempt at the implementation looks like this:

``` fsharp
module DevEd.FsCheck
open System.Xml
open System.Xml.Linq
 
let AddEnhancement (xDoc : XDocument) (input : string) =
    xDoc.Root.Add(XElement(XName.Get "Enhancement", input))
    xDoc
```

We know this isn't right - it's blatantly not idempotent. So let's try and get our failing test.

Although FsCheck does expose a set of NUnit plugin attributes, for this blog post I'm just going to run the tests via a console app. So; add a new F# console app to your solution, add references to `System.Xml`, `System.Xml.Linq` and your library project then grab FsCheck (it's on NuGet) and we'll see what we can do.

First, we'll need to add a property that we want to test. A property is simply a function that takes a data type FsCheck knows how to generate, and returns a bool. FsCheck knows how to generate strings, so our idempotence property looks something like this:

``` fsharp
open FsCheck
open DevEd.FsCheck
open System.Xml.Linq
 
let baseDoc = "<root />"
 
let ``Add enhancement must be idempotent`` input =
    let xml1 = XDocument.Parse baseDoc
    let xml2 = XDocument.Parse baseDoc
    (AddEnhancement xml1 input).ToString() =
        (AddEnhancement (AddEnhancement xml2 input) input).ToString()
```

Looking good. How do we run it? Just add this to the end of the file:

``` fsharp
Check.Quick ``Add enhancement must be idempotent``
 
System.Console.ReadLine() |> ignore
```

And hey presto:

!["" broke my code :(](/images/FsCheck1.png)

Failing test. Interestingly (and if you check the documents, not coincidently), FsCheck has found the 'simplest' possible failure case: `""`. Of course, it was helped on this occasion by the fact it was also the first input it tried.

So; let's add some checking to `AddEnhancement` to make sure we don't re-add the same input more than once.

``` fsharp
let AddEnhancement (xDoc : XDocument) (input : string) =
    if 
        xDoc.Root.Elements(XName.Get "Enhancement")
        |> Seq.exists (fun e -> e.Value = input)
        |> not then
            xDoc.Root.Add(XElement(XName.Get "Enhancement", input))
    xDoc
```

And re-run the test and... oops.

```
System.ArgumentException was unhandled by user code
  HResult=-2147024809
  Message=' ', hexadecimal value 0x18, is an invalid character.
  Source=System.Xml
  StackTrace:
       at System.Xml.XmlEncodedRawTextWriter.InvalidXmlChar(Int32 ch, Char* pDst, Boolean entitize)
       at System.Xml.XmlEncodedRawTextWriter.WriteElementTextBlock(Char* pSrc, Char* pSrcEnd)
       at System.Xml.XmlEncodedRawTextWriter.WriteString(String text)
       at System.Xml.XmlEncodedRawTextWriterIndent.WriteString(String text)
       at System.Xml.XmlWellFormedWriter.WriteString(String text)
       at System.Xml.Linq.ElementWriter.WriteElement(XElement e)
       at System.Xml.Linq.XElement.WriteTo(XmlWriter writer)
       at System.Xml.Linq.XContainer.WriteContentTo(XmlWriter writer)
       at System.Xml.Linq.XNode.GetXmlString(SaveOptions o)
       at System.Xml.Linq.XNode.ToString()
       at Program.Add enhancement must be idompotent(String input) in C:\Users\michael.newton\documents\visual studio 2012\Projects\DevEd.FsCheck\TestRunner\Program.fs:line 10
       at Program.clo@13.Invoke(String input) in C:\Users\michael.newton\documents\visual studio 2012\Projects\DevEd.FsCheck\TestRunner\Program.fs:line 13
       at FsCheck.Testable.evaluate[a,b](FSharpFunc`2 body, a a)
  InnerException: 
```

And this is where the full power of FsCheck starts becoming apparent. I know my input is untrusted, so I've told it to generate *any* string. And it believed me, and has created an input string that breaks `System.Xml.XmlEncodedRawTextWriter.WriteElementTextBlock`. This is not a unit test I would have thought to write myself, as I'd managed to miss that the fact that [not all utf-8 characters are valid in utf-8 encoded xml](http://blog.mark-mclaren.info/2007/02/invalid-xml-characters-when-valid-utf8_5873.html). In fact, it took me more than a few minutes to work out why it was throwing.

At this point FsCheck has revealed to us that our initial brief is actually incomplete; we've told the customer that we're willing to accept utf-8 strings as input, but our storage mechanism doesn't support all utf-8 strings. To even get FsCheck to run, we'll have to decide on an error handling strategy - and importantly, it will have to be a strategy that still fulfils the initial properties specified (unless we decide that what we've discovered so fundamentally breaks our initial assumptions that they need to be re-visited).

This is a toy project so I'm going to bail slightly on this one: I'm going to assume that invalid values just add an error node with a 'cleaned' version of the input which could then be reviewed by a human at a later date. This has the advantage that it still fulfils all of our properties above.

Fortunately for us, in .NET 4.0 and above there is a function in the `System.Xml` namespace called `XmlConvert.IsXmlChar` which does roughly what you would expect from the name. Let's add an invalid character filter, and an active pattern to tell us if any characters have been removed:

``` fsharp
let filterInvalidChars (input : string) =
    input
    |> Seq.filter (fun c -> XmlConvert.IsXmlChar c)
    |> Seq.map string
    |> String.concat ""    
 
let (|ValidXml|InvalidXml|) str =
    let filtered = filterInvalidChars str
    if String.length filtered = String.length str then
        ValidXml str
    else
        InvalidXml filtered
```

Now we can amend `AddEnhancement` to add enhancement nodes for valid XML text or an error node for sanitized invalid XML text:

``` fsharp
let AddEnhancement (xDoc : XDocument) (input : string) =
    match input with
    | ValidXml text ->
        if xDoc.Root.Elements(XName.Get "Enhancement") |> Seq.exists(fun enhance -> enhance.Value = text) then
            xDoc.Root.Add(XElement(XName.Get "Enhancement", text))
    | InvalidXml text ->
        if xDoc.Root.Elements(XName.Get "Error") |> Seq.exists(fun error -> error.Value = text) then
            xDoc.Root.Add(XElement(XName.Get "Error", text))
    xDoc
```

And when we run FsCheck again:

![Hurrah!](/images/FsCheck2.png)

Excellent stuff.

As a bonus extra, I've included below a somewhat expanded version of the test code. Remember I said that FsCheck already knows how to generate strings? Unfortunately it doesn't know how to generate XML out of the box, but I was pleasantly surprised how quick and easy it was to write a naive XML generator. It generates [XML like this](https://gist.github.com/mavnn/5976004#file-example-xml). Also, check out the `CheckAll` function used at the end which allows you to build and run 'property classes' to group families of properties together.

And, of course, per the specification, it checks that the 3rd property above holds true (that adding enhancements never reduces the size of the document).

``` fsharp
module FsCheck.Examples.Tests
 
open FsCheck
open DevEd.FsCheck
open System.Xml.Linq
 
let baseDocText = """<?xml version="1.0" encoding="UTF-8"?>
<root />
"""
 
type XmlTree = 
    | NodeName of string
    | Container of string * List<XmlTree>
 
let nodeNames = 
    ["myNode";
     "myOtherNode";
     "someDifferentNode"]
 
let tree = 
    let rec tree' s = 
        match s with
        | 0 -> Gen.map NodeName (Gen.elements nodeNames)
        | n when n > 0 -> 
            let subtrees = 
                Gen.sized <| fun s -> 
                    Gen.resize (s
                                |> float
                                |> sqrt
                                |> int) (Gen.listOf(tree'(n / 2)))
            Gen.oneof 
                [Gen.map NodeName (Gen.elements nodeNames);
                 
                 Gen.map2 (fun name contents -> Container(name, contents)) 
                     (Gen.elements nodeNames) subtrees]
        | _ -> invalidArg "s" "Size most be positive."
    Gen.sized tree'
 
let treeToXDoc xmlTree = 
    let rec inner currentNode children = 
        let childMatch child = 
            match child with
            | NodeName name -> XElement(XName.Get name)
            | Container(name, contents) -> 
                let element = XElement(XName.Get name)
                inner element contents
        currentNode.Add(List.map childMatch children |> List.toArray)
        currentNode
    match xmlTree with
    | NodeName name -> XDocument(XElement(XName.Get name))
    | Container(name, contents) -> 
        let doc = XDocument(XElement(XName.Get name))
        inner doc.Root contents |> ignore
        doc
 
type XmlGenerator() = 
    static member XmlTree() = 
        { new Arbitrary<XmlTree>() with
              member x.Generator = tree
              member x.Shrinker t = 
                  match t with
                  | NodeName _ -> Seq.empty
                  | Container(name, contents) -> 
                      match contents with
                      | [] -> seq { yield NodeName name }
                      | c -> 
                          seq { 
                              for n in c -> n } }
 
type XmlUpdaterProperties() = 
    static member ``AddEnhancement is idempotent``(data : string) = 
        ((AddEnhancement <| AddEnhancement (XDocument.Parse baseDocText) data) data)
            .ToString() = (AddEnhancement (XDocument.Parse baseDocText) data)
            .ToString()
    static member ``AddEnhancement is idempotent on different xml structures``(xmlDoc : XmlTree, 
                                                                           data : string) = 
        (AddEnhancement (treeToXDoc xmlDoc) data).ToString() = (AddEnhancement (AddEnhancement (treeToXDoc xmlDoc) data) data)
            .ToString()
    static member ``AddEnhancement never reduces the number of nodes`` (xmlDoc : XmlTree, data : string) =
        Seq.length ((treeToXDoc xmlDoc).DescendantNodes()) = Seq.length ((AddEnhancement (treeToXDoc xmlDoc) data).DescendantNodes())
 
Arb.register<XmlGenerator>() |> ignore
Check.QuickAll<XmlUpdaterProperties>()
System.Console.ReadLine() |> ignore
```

Thanks for reading this far. If you want to play yourself, a full copy of the example code is [on GitHub](https://github.com/mavnn/DevEd.FsCheck) with an MIT license.
