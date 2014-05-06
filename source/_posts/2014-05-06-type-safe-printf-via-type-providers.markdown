---
layout: post
title: "Type safe printf via Type Providers"
date: 2014-05-06 15:33:15 +0100
comments: true
categories: [fsharp, typeprovider]
---

[Brian McKenna](http://twitter.com/puffnfresh) posted an interesting [video](http://www.youtube.com/watch?v=fVBck2Zngjo) and [gist](https://gist.github.com/puffnfresh/11202637) on implementing a type safe printf in Idris with dependent types.

This led me down a nice little rabbit hole wondering if something similar could be achieved with an F# type provider.

With a [bit of help from Tomas](http://stackoverflow.com/questions/23375469/how-can-i-build-an-arbitary-curried-function-in-an-f-type-provider) the final solution turned out to be surprisingly nice, although not quite so clean as the Idris original.

<!-- more -->

Taking the format string and parsing it looks very similar to the Idris version, what with the common ML history of the two languages:

```fsharp
type Format =
    | FString of Format
    | FInt of Format
    | Other of char * Format
    | End

let parseFormatString str =
    let rec parseFormat chars =
        match chars with
        | '%'::'d'::t -> FInt (parseFormat t)
        | '%'::'s'::t -> FString (parseFormat t)
        | c::t -> Other (c, parseFormat t)
        | [] -> End
    parseFormat (Seq.toList str)
```

This might not be the most efficient or flexible parsing method, but that's not really the point of the current exercise and it's very clear what it's doing.

Next, we want to create a [quotation](http://msdn.microsoft.com/en-us/library/dd233212.aspx) that represents a curried function based on our format type. This is where I needed Tomas' help - it turns out there isn't any easy way to do this with the `<@@ ... @@>` syntax I've usually used to build quotations for type providers.

Tomas reminded me that the `Microsoft.FSharp.Quotations` namespace gives direct access to the underlying classes that represent the expression tree of the quotation. This allows us to build an expression tree recusively; check out [Tomas' explanation](http://stackoverflow.com/a/23375794/68457)  of the technique for more details of how it works.

```fsharp
open System.Reflection
open Microsoft.FSharp.Quotations

(* ... *)

let rec invoker printers format =
    match format with
    | End ->
        let arr = Expr.NewArray(typeof<string>, List.rev printers)
        let conc = typeof<string>.GetMethod("Concat", [|typeof<string[]>|])
        Expr.Call(conc, [arr])
    | Other (c, t) ->
        invoker (<@@ string<char> c @@> :: printers) t
    | FInt t ->
        let v = Var("v", typeof<int>)
        let printer = <@@ string<int> (%%(Expr.Var v)) @@>
        Expr.Lambda(v, invoker (printer::printers) t)
    | FString t ->
        let v = Var("v", typeof<string>)
        let printer = <@@ %%(Expr.Var v):string @@>
        Expr.Lambda(v, invoker (printer::printers) t)
```

That's the hard stuff out of the way! Now we just have some type provider boiler plate. We're going to provide a type provider named `TPrint` which takes a single parameter (our format string). Once the parameter is supplied, we provide a single static property which is an FSharpFunc type which matches the signature required by the format string.

```fsharp
open System.Reflection
open ProviderImplementation.ProvidedTypes
open Microsoft.FSharp.Core.CompilerServices

(* ... *)

let toMethod format =
    let invokeCode =
        invoker [] format
    let invokeType = invokeCode.Type
    ProvidedProperty("show", invokeType, IsStatic = true, GetterCode = fun _ -> invokeCode)


[<TypeProvider>]
type TPrintProvider (config : TypeProviderConfig) as this =
    inherit TypeProviderForNamespaces ()

    let ns = "TypeSet.Provided"
    let asm = Assembly.GetExecutingAssembly()

    let tPrintProvider = ProvidedTypeDefinition(asm, ns, "TPrint", Some(typeof<obj>))

    let parameters = [ProvidedStaticParameter("FormatString", typeof<string>)]

    do tPrintProvider.DefineStaticParameters(parameters, fun typeName args ->
        let formatString = args.[0] :?> string

        let provider = ProvidedTypeDefinition(asm, ns, typeName, Some(typeof<obj>))
        provider.HideObjectMethods <- true

        formatString |> parseFormatString |> toMethod |> provider.AddMember

        provider
        )
    
    do
        this.AddNamespace(ns, [tPrintProvider])

[<assembly:TypeProviderAssembly>]
do ()
```

So, put it all together and you get a type provider which allows you to do this:

```fsharp
TPrint<"A %s string! %s %d">.show "hello" "world" 32
// val it : string = "A hello string! world 32"

TPrint<"Number one: %d! Number two: %d! A string: %s!">.show 1 2 "My string!"
// val it : string = "Number one: 1! Number two: 2! A string: My string!!"
```

So; nothing there that the built in `printf` doesn't already do for you. But, this does start opening up some options for providing much more idiomatic F# style APIs then I've really seen so far from Type Providers, which tend to provide very OO style interfaces. Should be some interesting ideas in there to explore!

Full code can be found [at Github](https://github.com/mavnn/TypeSet).
