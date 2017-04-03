---
layout: post
title: "Type Provider Pro-Tip: Using Dictionary"
date: 2016-03-05 15:38:45 +0000
comments: true
categories: [fsharp, programming, typeprovider, tpProTip]
---
During the [Type Provider Live](https//blog.mavnn.co.uk/type-providers-live-the-movie/) recording, [Ryan](https://twitter.com/panesofglass) asked me about basing erased provided types on dictionary types, and then exposing nicely typed properties to access data stored within the dictionary.

This will sound familiar to users of a number of dynamically typed languages as in many cases objects in these languages are just dictionaries under the hood.

This is such a common thing to be doing in a type provider that I thought it was worth writing up a working example that can then be modified to your individual situation. I've presented the entire listing below with comments, but there is one particular trick I'll explain in a bit more detail. Let's have a look at let bindings in quotations!

<!-- more -->

So, normally when you write a ``let`` binding in F#, and end up writing something like this:

``` fsharp
let myFunction () =
  let x = 10

  x + 10
```

Here, the body of function ``myFunction`` is an expression that evaluates to 20. But it turns out that this is actually syntax sugar for:

``` fsharp
let myFunction () =
  let x = 10 in x + 10
```

A quotation in F# always represents a single expression, so it shouldn't come as a surprise at this point that the ``Expr.Let`` class has a constructor this three arguments. The variable being bound, the value to bind to it, and the body in which it is used. So if you want to express the body of the function above you end up with something like this:

``` fsharp
open FSharp.Quotations

let version1 =
  <@@ let x = 10 in x + 10 @@> // cheat!
  
let version2 =
  let xVar = Var("x", typeof<int>)
  let x = Expr.Var xVar
  Expr.Let(xVar, <@@ 10 @@>, <@@ %%x + 10 @@>)
```

The trick you need to know is that ``Expr.Var`` produces an Expr that represents a place where a variable will be used. But it creates an untyped Expr, and this can (and does) cause issues with type inference. We can work around this by making use of typed expressions, represented by the generic ``Expr<'a>`` class. The type provider API takes the untyped version, but you can convert back to the untyped version either by calling the ``Raw`` property on the typed expression or just by using it to help construct an expression which contains the typed expression but which is untyped itself using the ``Expr`` classes.

In the code below, notice the use of ``<@ ... @>`` and ``%`` rather than ``<@@ ... @@>`` and ``%%`` to work with typed expressions rather than untyped.

``` fsharp
open FSharp.Quotations

type GD = System.Collections.Generic.Dictionary<string,string>

let dictExpr =
  let gdVar = Var("gd", typeof<GD>)
  let gdExpr =
    Expr.Var gdVar |> Expr.Cast<GD>
    // Expr.Cast forces this to be a typed expression
  let addValue =
    Expr.Let(gdVar, <@ GD() @>, <@ %gdExpr.["one"] <- "the number one" @>)
    // the line above fails without typed expressions
```

With that out of the way, we're good to go. The type provider below is a simple wrapper around a string, string dictionary. It looks like this in use:

``` fsharp
type MyType = DictProvider.ParaProvider<"name1, name2">

let thing = MyType("1","2")

thing.name1 // "1"
thing.name2 // "2"

thing.name1 <- "not one. Muhahahaha!"
thing.name2 <- "that's why you shouldn't make things mutable"

thing.name1 // "not one. Muhahahaha!"
```

You'll get different properties depending which strings you supply as parameters.

Here's the source:

``` fsharp
module DictProvider

open System.Reflection
open FSharp.Core.CompilerServices
open FSharp.Quotations
open ProviderImplementation.ProvidedTypes

type GD = System.Collections.Generic.Dictionary<string, string>

[<TypeProvider>]
type DictionaryProvider() as this =
  inherit TypeProviderForNamespaces()

  let ns = "DictProvider"
  let asm = Assembly.GetExecutingAssembly()

  let createType typeName (parameters : obj []) =
    // We'll get our property names by just splitting
    // our single parameter on commas
    let propNames =
      (parameters.[0] :?> string).Split ','
      |> Array.map (fun s -> s.Trim())

    // Each of our properties has setter code to set the value in the dict with the
    // name of the property, and getter code with gets the same value
    let aProp name =
      ProvidedProperty(
        name,
        typeof<string>,
        IsStatic = false,
        GetterCode = (fun args -> <@@ (%%args.[0]:GD).[name] @@>),
        SetterCode = (fun args -> <@@ (%%args.[0]:GD).[name] <- (%%args.[1]:string) @@>))

    // Here we set the type to be erased to as "GD" (our type alias for a dictionary)
    // If we want to hide the normal dictionary methods, we could use:
    // 'myType.HideObjectMethods <- true'
    // But here we'll just let people use the type as a dictionary as well.
    let myType =
      ProvidedTypeDefinition(asm, ns, typeName, Some typeof<GD>)

    // Make sure we add all the properties to the object.
    propNames
    |> Array.map (fun propName -> aProp propName)
    |> List.ofArray
    |> myType.AddMembers

    // We'll want a constructor that takes as many parameters as we have
    // properties, as we'll want to set the value in the dictionary of our
    // properties during construction. If we don't, trying to use the properties
    // will result in a key not found exception.
    let cstorParams =
      propNames
      |> Array.map (fun propName -> ProvidedParameter(propName, typeof<string>))
      |> List.ofArray

    // Here's the constructor code where we set each property in turn.
    // Notice how the fold keeps on building up a larger let expression,
    // adding a set value line at the top of the expression each time through.
    // Our initial state (a line with only the dictionary variable on) is always
    // left last, so this is what will be returned from the constructor.
    let cstorCode =
      fun (args : Expr list) ->
        let dictionaryVar = Var("dictionary", typeof<GD>)
        let dictionary : Expr<GD> = dictionaryVar |> Expr.Var |> Expr.Cast
        let setValues =
          args
          |> Seq.zip propNames
          |> Seq.fold (fun state (name, arg) ->
            <@ (%dictionary).[name] <- (%%arg:string)
               %state @>) <@ %dictionary @>
        Expr.Let(dictionaryVar, <@ GD() @>, setValues)

    // Build the constructor out of our helpers
    let cstor =
      ProvidedConstructor(cstorParams, InvokeCode = cstorCode)

    // And make sure you add it to the class!
    myType.AddMember cstor

    myType

  let provider =
    ProvidedTypeDefinition(asm, ns, "ParaProvider", Some typeof<obj>)
  let parameters =
    [ProvidedStaticParameter("PropNames", typeof<string>)]

  do
    provider.DefineStaticParameters(parameters, createType)
    this.AddNamespace(ns, [provider])

[<assembly:TypeProviderAssembly>]
do()
```
