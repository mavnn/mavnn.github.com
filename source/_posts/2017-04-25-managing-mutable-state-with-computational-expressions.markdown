---
layout: post
title: "Managing Mutable State with Computational Expressions"
date: 2017-04-25 23:55:29 +0100
comments: true
categories: ["fsharp"]
---

*Want to learn more about computational expressions, type providers and more?
I'm running a course in London on the 15th/16th June 2017 to [Level Up Your F#](https://www.eventbrite.co.uk/e/level-up-your-f-skills-tickets-33720450776) - come along and build more awesome!*

In mixed paradigm languages such as F# and Scala you frequently end up using
mutable APIs in your "nice" pure functional code. It might be because you're using
a 3rd party library, or it might be for performance reasons - but either way it's very
easy to make mistakes with mutable constructs when you're in a functional mind space, especially if you want to compose operations on instances of a mutable type.

Let's have a look at one way of handling this issue: custom operations on 
computational expressions. We'll take the Provided Types API for building
types within a type provider as an example of an API to
use, and see what we can do to wrap it.

<!-- more -->

Firstly, let's give an example of the issue. Creating even a simple type
within a type provider looks something like this:

``` fsharp
open System
open System.Reflection
open FSharp.Core.CompilerServices
open FSharp.Quotations
open ProviderImplementation.ProvidedTypes

[<TypeProvider>]
type CambridgeProvider() as this =
  inherit TypeProviderForNamespaces()

  let ns = "Mavnn.Provided"
  let asm = Assembly.GetExecutingAssembly()

  let myProp =
    ProvidedProperty(
      "StaticProperty",
      typeof<string>,
      IsStatic = true,
      GetterCode = fun _ -> <@@ "Hello world" @@>)

  let myType =
    ProvidedTypeDefinition(asm, ns, "StaticType", Some typeof<obj>)

  do
    myType.AddMember myProp
    this.AddNamespace(ns, [myType])

[<assembly:TypeProviderAssembly>]
do()
```

The main problem is right at the end on line 26: having
created your property you need to then add it the the mutable ``ProvidedTypeDefinition``. This is easy to forget on the one hand, and makes it hard too
compose partial type definitions on the other.

One way to handle this would be to create a function that takes a provided
type definition and knows how to amend it with a provided property.

``` fsharp
let addHelloWorld (ptd : ProvidedTypeDefinition) =
    let myProp =
        ProvidedProperty(
          "StaticProperty",
          typeof<string>,
          IsStatic = true,
          GetterCode = fun _ -> <@@ "Hello world" @@>)
    ptd.AddMember myProp
    ptd
```

Now if we have a lot of types that need, say, a "hello world" and "goodbye world" property added we can do something like this:

``` fsharp
let addCommon ptd =
    ptd
    |> addHelloWorld
    |> addGoodbyeWorld // definition left as an exercise
```

So now you can pass in a ``ProvidedTypeDefinition`` and get out one with
your two common properties added. But now the secret is that you want to
pass around these builder functions as much as possible, and only actually
pass in a instance of ``ProvidedTypeDefinition`` right at the end; up until
you do, you have something composable and reusable. Once you've created your
instance, you're done.

This sounds similar, but not quite like, continuation passing style programming
as used in things like ``async`` under the hood. Which raises the interesting
possibility that we might be able to <strike>ab</strike>use computational
expressions to make our code a bit nicer. Let's give it a go!

Computational expressions are built via a class with some strictly named
member methods which the F# compiler then uses to translate the computational
expression code into "standard" F#.

The type the CE is going to operate on is going to be
``ProvidedTypeDefinition -> ProvidedTypeDefinition`` (similar to the state
monad for those of you who've played with it). But it's going to be a little
odd, as we have no monad and won't be following the monad laws, so there's
really no meaningful bind operation. What would that look like?

Something like this:

``` fsharp
type PTD = ProvidedTypeDefinition -> ProvidedTypeDefinition

type ProvidedTypeBuilder () =
    member __.Zero () : PTD =
        id
    member __.Return _ : PTD =
        id
    member __.Bind(m, f : unit -> PTD) =
        fun ptd -> (f ()) (m ptd)
    member x.Combine(m1 : PTD, m2 : PTD) : PTD =
        x.Bind(m1, fun () -> m2)
```

So we have a bind... but it can only bind ``unit`` and no other type. All
it knows how to deal with is composing two ``ProvidedTypeBuilder -> ProvidedTypeBuilder`` functions. ``Zero`` and ``Return`` make a some sense as well: both
can be meaningfully defined using the ``id`` function; just take the provided
type definition and pass it on unchanged.

Now we can write code like this!

``` fsharp
let typeBuilder = ProvidedTypeBuilder ()

typeBuilder {
    ()
}
```

Okay, so I admit we're not quite there yet. Time to dive into the fun bit;
adding a custom operation to our builder.

``` fsharp
type PTD = ProvidedTypeDefinition -> ProvidedTypeDefinition

type ProvidedTypeBuilder () =
    member __.Zero () : PTD =
        id
    member __.Return _ : PTD =
        id
    member __.Bind(m, f : unit -> PTD) =
        fun ptd -> (f ()) (m ptd)
    member x.Combine(m1 : PTD, m2 : PTD) : PTD =
        x.Bind(m1, fun () -> m2)

    [<CustomOperation("addMember", MaintainsVariableSpaceUsingBind = true)>]
    member x.AddMember(ptd, member') =
        let func =
          fun (instance : ProvidedTypeDefinition) ->
              instance.AddMember member'
              instance
        x.Bind(ptd, fun () -> func)
```

Now we're starting to get somewhere, with code that begins to look like
this:

``` fsharp
let withHelloWorld =
  typeBuilder {
      addMember (ProvidedProperty(
                  "StaticProperty",
                  typeof<string>,
                  IsStatic = true,
                  GetterCode = fun _ -> <@@ "Hello world" @@>))
  }
```

``withHelloWorld`` has a type of ``ProvidedTypeDefinition -> ProvidedTypeDefinition`` as you'd expect. But there's still no easy way to compose these; let's
add that next.

``` fsharp
type ProvidedTypeBuilder () =
    // ...snip...

    [<CustomOperation("including", MaintainsVariableSpaceUsingBind = true)>]
    member x.Including(ptd, builder) =
        x.Combine(ptd, builder)
```

The ``including`` operation is just a wrapper around combine, but it allows us
to do things like this:

``` fsharp
let withHelloAndGoodbye =
    typeBuilder {
        including withHelloWorld
        addMember (ProvidedProperty(
                    "Goodbye",
                    typeof<string>,
                    IsStatic = true,
                    GetterCode = fun _ -> <@@ "Goodbye" @@>))
    }
```

And now the power of this technique begins to be shown, as we build
blocks of composable code which can be included within each other.

Obviously a lot more could be done at this point: we've barely scratched
the provided types API, but we'll leave the blog post at this point.

This blog post comes with many thanks to [Andrew Cherry](http://twitter.com/kolektiv) who took some pretty mad lunch time discussions and turned them into
the very real and unable [Freya](https://docs.freya.io/en/latest/) (along with a bunch of collaborators). Freya makes use of this kind of
technique heavily.

*Want to learn more about computational expressions, type providers and more?
I'm running a course in London on the 15th/16th June 2017 to [Level Up Your F#](https://www.eventbrite.co.uk/e/level-up-your-f-skills-tickets-33720450776) - come along and build more awesome!*
