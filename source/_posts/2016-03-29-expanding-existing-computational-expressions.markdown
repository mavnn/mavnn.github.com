---
layout: post
title: "Expanding Existing Computational Expressions"
date: 2016-03-29 19:15:20 +0100
comments: true
categories: [fsharp]
---
This is a "just because you can" post, although frankly bizarrely I have a genuine use case for this.

Let the mind melting commence!

Computational expressions in F# provide nice sugared syntax for monadic data structures such as ``seq`` and ``async``; but the specific expressions are not built in language features. You can [build your own](blog.mavnn.co.uk/corrected-error-handling-computational-expres).

Which is fun and all, but you know what's even more fun? Well, it turns out that there's no requirements for computational expressions to be actual monads. Even more fun than that is that the bind operation (used when you invoke ``let!`` syntax) is a member on a class - and it is valid both for it to be an extension method, and for it to be overloaded. You can even add custom operators to computational expressions using the extension method trick.

Which means you can do some very interesting things indeed to existing computational expressions. Let's try it out!

<!-- more -->

``` fsharp
type MyThing<'a> = MyThing of 'a

let testFunc str =
  MyThing (Seq.length str)

type AsyncBuilder with
  member x.Bind(value : MyThing<'a>, f : 'a -> Async<'b>) =
    let (MyThing inner) = value
    f inner

  [<CustomOperation("log", MaintainsVariableSpaceUsingBind = true)>]
  member x.Log(boundValues : Async<'a>, [<ProjectionParameter>] messageFunc) =
    async {
      let! b = boundValues
      printfn "Log message: %s" <| messageFunc b
      printfn "Currently let bound things: %A" b
      return b
    }

let workflow =
  async {
    log "a string"
    let! c = testFunc "Count the letters"
    let! result = async { return (c * 10) }
    do! Async.Sleep 100
    log "more string"
    let! a = MyThing "A prefix here: "
    log "a different string"
    return sprintf "%s %d" a result
  }

printfn "%A" <| Async.RunSynchronously workflow

// Program outputs:
// Log message: a string
// Currently let bound things: <null>
// Log message: more string
// Currently let bound things: (17, 170)
// Log message: a different string
// Currently let bound things: (17, 170, "A prefix here: ")
// "A prefix here:  170"

```

This is a full code example that compiles, runs and builds. Oh yes, and it's an example of a bind based custom operator in case you've been looking for one.

As you can see we can now ``let!`` both ``MyThing`` and ``Async`` results and both will be handled correctly - and we can also add logging statements using the custom operator which will get placed correctly into the async workflow. For even more fun and profit, the log custom operator has access to all currently bound values (which it logs in our example).

In case the custom operator is making you scratch your head, the way this one works is that a tuple of the currently bound values in the CE is passed into the operator as the first argument wrapped using the ``Return`` method of the CE (in this case, that means we get an Async<'a> where 'a is a tuple). The ``ProjectionParameter`` is a function from the currently bound values to the expression that follows the custom operator. In my case, that's always a static string, but of course it could be an expression which used some of the already bound values. Once you've done whatever you're doing within the custom operator, it's important that you pass back the bound values you received - again, wrapped in a type that the CE knows how to bind as it will use bind to include this code into the overall expression result. As a word of warning, the explanation above is only true for custom operators where ``MaintainsVariableSpaceUsingBind`` is set to true. If it is set to false, the CE must support yield and the expansion mechanism is quite different.

I see all kinds of useful ways of bending the F# language here, and making libraries easier to use from within the built in CEs. Have fun, and remember to use these powers for good!
