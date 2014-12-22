---
layout: post
title: "Modelling Inheritance with Inheritance"
date: 2014-12-18 12:01:41 +0000
comments: true
categories: [fsharp, typeprovider, FsAdvent]
---

> This post is part of the [F# Advent Calendar](https://sergeytihon.wordpress.com/tag/fsadvent/) 2014, which is stuffed full of other interesting posts. Go have a read!

Note: This post is epic in length. If you just want to see the final resulting script of much silliness, skip straight to [the conclusion](#conclusion)!

Note 2: If you just want to see an example of a sane generated type provider, [the code from my FPDays tutorial](https://github.com/mavnn/FPDays.TypeProvider/) is a much better bet.

Note 3: There is a lot of code below. If you're viewing this on a desktop, I suggest collapsing the sidebar to the right otherwise you'll have a lot of horizontal scroll bars. If you're on a mobile device, you might want to bookmark for later.

So... I've been playing with generated (not erased) type providers for a bit, and meaning to write something up about them. Most of the documentation out there is for erased type providers, and to be honest they have a lot of advantages in terms of performance.

But they also have two fundamental limitations:

* You can't used erased F# types in any other .net language
* You can't use reflection on erased types (even in F#)

So let's see if we can have a play with generated types, and then - given this is Christmas, and all - let's see if we can build Jesus' family tree in the .net type system. After all, if you're going to use inheritance to model something, how about modelling inheritance?

<!-- more -->


> If you need a reminder of type provider basics, check out [Type Providers from the Ground Up](http://blog.mavnn.co.uk/type-providers-from-the-ground-up/)

Let's start with a really basic example of a generative type provider. We'll just create a single type with a static property on it.

First, our input. We're going to grab [the genealogy of Jesus from Matthew](https://www.biblegateway.com/passage/?search=matthew+1%3A2-16&version=NIV) and then massage the content just enough that the first name on each line is a "parent", and any other names on a line are... other people. We'll assume they're siblings, although actually not all of them are.


    Abraham was the father of Isaac,
    Isaac the father of Jacob,
    Jacob the father of Judah and his brothers,
    Judah the father of Perez and Zerah, whose mother was Tamar,
    Perez the father of Hezron,
    Hezron the father of Ram,
    Ram the father of Amminadab,
    ... (some other people here) ...
    Akim the father of Elihud,
    Elihud the father of Eleazar,
    Eleazar the father of Matthan,
    Matthan the father of Jacob,
    Jacob the father of Joseph, the husband of Mary, 
    and Mary was the mother of Jesus who is called the Messiah.

For round one, we're just going to put this string into a type as a property.

Our type provider file looks a bit like this:

```fsharp
module AdventProvider
#if INTERACTIVE
#load "paket-files/fsprojects/FSharp.TypeProviders.StarterPack/src/ProvidedTypes.fsi"
#load "paket-files/fsprojects/FSharp.TypeProviders.StarterPack/src/ProvidedTypes.fs"
#endif

open System.Reflection
open ProviderImplementation.ProvidedTypes
open Microsoft.FSharp.Core.CompilerServices
open Microsoft.FSharp.Quotations

[<TypeProvider>]
type AdventProvider (cfg : TypeProviderConfig) as this =
    inherit TypeProviderForNamespaces ()

    let ns = "Advent.Provided"
    let asm = Assembly.GetExecutingAssembly()
    let tempAsmPath = System.IO.Path.ChangeExtension(System.IO.Path.GetTempFileName(), ".dll")
    let tempAsm = ProvidedAssembly tempAsmPath

    let t = ProvidedTypeDefinition(asm, ns, "Family", Some typeof<obj>, IsErased = false)
    let parameters = [ProvidedStaticParameter("Genealogy", typeof<string>)]

    do
        t.DefineStaticParameters(
            parameters,
            fun typeName args ->
                let genealogy = args.[0] :?> string
                let inputFile = 
                    System.IO.Path.Combine(cfg.ResolutionFolder, genealogy)
                let raw =
                    System.IO.File.ReadAllLines inputFile

                let g = ProvidedTypeDefinition(
                            asm, 
                            ns, 
                            typeName, 
                            Some typeof<obj>, 
                            IsErased = false)

                let s = ProvidedProperty("Raw", typeof<string>, IsStatic = true)
                let rawStr = String.concat "\n" raw
                s.GetterCode <- fun _ -> Expr.Value rawStr
                g.AddMember s

                tempAsm.AddTypes [g]
                
                g
            )

    do
        this.RegisterRuntimeAssemblyLocationAsProbingFolder cfg
        tempAsm.AddTypes [t]
        this.AddNamespace(ns, [t])

[<assembly:TypeProviderAssembly>]
do ()

```

What's with the ``#if INTERACTIVE`` bits? Well, that'll be the subject of another blog post soon; I'm doing must of my type provider dev in Vim these days to avoid the Visual Studio restart cycle, so I thought I might as well skip the fsproj file completely.

In the actual provider itself, there's a few new things to note if you've only previously done erased type provider development.

```fsharp
    let tempAsmPath = System.IO.Path.ChangeExtension(System.IO.Path.GetTempFileName(), ".dll")
    let tempAsm = ProvidedAssembly tempAsmPath
```

Generative type providers, unlike erased type providers, actually pass IL (.net byte code) to the compiler rather than just a quotation. To achieve that, we need to write the IL into an actual assembly that the compiler will then merge into the dll it's compiling.

Let's try that again, slower. The compiler will be building a piece of code that uses your type provider into ``Output.dll``. It will call into your type provider, which needs to write the IL of the type/codes it's generating to disk into ``Temp.dll``. The compiler will then take the IL from ``Temp.dll`` and insert it into ``Output.dll``. At this point, we have no further use for ``Temp.dll``, hence why we're using ``GetTempFileName`` to get a file in the OS temporary file
folder.

The ``ProvidedTypes`` API knows how to create these temporary dlls, so we wrap our filename in the ``ProvidedAssembly`` type.

```fsharp
    do
        this.RegisterRuntimeAssemblyLocationAsProbingFolder cfg
        tempAsm.AddTypes [t]
        this.AddNamespace(ns, [t])
```

We also need to specify which types need adding to the temporary assembly. Here we're specifying that the parameterized type (the one that takes a filename) should be added; on line 46 of the main code you'll see the type generated when a parameter is supplied being added. We also need to tell the type provider where the runtime dll is being created - fortunately, a helper method works this out for us when given the config item from the type provider constructor.

It's important to note that nested types *should not* be added to the temporary assembly. That's handled by adding the root.

So, if you compile this code down you can invoke it like this:

```fsharp
#!/usr/bin/env fsharpi
// Put all of this in a file called something like Families.fsx
// Yes, that hashbang line means if you make it executable it
// will run on linux/mac
#r @"AdventProvider.dll"

open AdventProvider
open Advent.Provided

type JesusGenerations = Family<"Genealogy.txt">

printfn "%s" JesusGenerations.Raw
```

Excellent! A real, valid .net type. You can only invoke the type provider from F#, but the types generated are usable across the .net language universe - and reflection works fine.

So... phase two. Let's see if we can parse something sane out of our plain text mess to turn into types. I'm not going to go into this in detail, but because I wanted to avoid the complication of external dependencies I just wrote a very simple regex based parser for this.

Behold! The ``Parser.fs`` file:

```fsharp
module Parser
open System.Text.RegularExpressions

type Person =
    {
        Name : string
        Heir : Person option
        Others : string list
    }

let namesRegex = Regex(@"(?<name>[A-Z][a-z]+)", RegexOptions.Compiled)

let ParseToNames line =
    namesRegex.Matches(line)
    |> Seq.cast<Match>
    |> Seq.map (fun m -> m.Groups.["name"].Value)
    |> Seq.filter (fun n -> n <> "King" && n <> "Messiah" && n <> "Babylon")
    |> Seq.toList
    |> function h::t -> h, t | [] -> failwith "No blank lines!"

let rec NamesToPerson names =
    match names with
    | [] -> None
    | (father,others)::t ->
        let heir =
            match t with
            | [] -> None
            | (heir, _)::_ -> Some heir
        Some {
            Name = father
            Heir = NamesToPerson t
            Others =
                others
                |> List.filter
                    (fun c ->
                        match heir with
                        | Some h -> c <> h
                        | None -> true)
        }

let Parse lines =
    lines
    |> List.map ParseToNames
    |> NamesToPerson
```

Nb. Never, ever, ever build a parser like this for production code. Treat this as a "how not to build a parser" example, and go read something like [Phil's excellent parsing posts](http://trelford.com/blog/post/parser.aspx) instead.

So... what can we do this this?

Let's start be parsing our file, and seeing if we can build a nested set of types representing the family tree.

Recursive type building! Go!

```fsharp
module AdventProvider
#if INTERACTIVE
#load "paket-files/fsprojects/FSharp.TypeProviders.StarterPack/src/ProvidedTypes.fsi"
#load "paket-files/fsprojects/FSharp.TypeProviders.StarterPack/src/ProvidedTypes.fs"
#load "Parser.fs"
#endif

open System.Reflection
open ProviderImplementation.ProvidedTypes
open Microsoft.FSharp.Core.CompilerServices
open Microsoft.FSharp.Quotations
open Parser

[<TypeProvider>]
type AdventProvider (cfg : TypeProviderConfig) as this =
    inherit TypeProviderForNamespaces ()

    let ns = "Advent.Provided"
    let asm = Assembly.GetExecutingAssembly()
    let tempAsmPath = System.IO.Path.ChangeExtension(System.IO.Path.GetTempFileName(), ".dll")
    let tempAsm = ProvidedAssembly tempAsmPath

    let t = ProvidedTypeDefinition(asm, ns, "Family", Some typeof<obj>, IsErased = false)
    let parameters = [ProvidedStaticParameter("Genealogy", typeof<string>)]

    do
        t.DefineStaticParameters(
            parameters,
            fun typeName args ->
                let genealogy = args.[0] :?> string
                let inputFile = 
                    System.IO.Path.Combine(cfg.ResolutionFolder, genealogy)
                let raw =
                    System.IO.File.ReadAllLines inputFile
                let input =
                    raw
                    |> Seq.toList
                    |> Parse

                let g = ProvidedTypeDefinition(
                            asm, 
                            ns, 
                            typeName, 
                            Some typeof<obj>, 
                            IsErased = false)
                g.SetAttributes (TypeAttributes.Public ||| TypeAttributes.Class)

                let s = ProvidedProperty("Raw", typeof<string>, IsStatic = true)
                let rawStr = String.concat "\n" raw
                s.GetterCode <- fun _ -> Expr.Value rawStr
                g.AddMember s

                let rec personToType (father : ProvidedTypeDefinition) (person : Person) =
                    let t = ProvidedTypeDefinition(person.Name, Some (father :> System.Type), IsErased = false)
                    t.SetAttributes (TypeAttributes.Class ||| TypeAttributes.Public)
                    father.AddMember t
                    match person.Heir with
                    | Some p -> personToType t p
                    | None -> ()

                match input with
                | Some p ->
                    personToType g p
                | None ->
                    ()

                tempAsm.AddTypes [g]
                
                g
            )

    do
        this.RegisterRuntimeAssemblyLocationAsProbingFolder cfg
        tempAsm.AddTypes [t]
        this.AddNamespace(ns, [t])

[<assembly:TypeProviderAssembly>]
do ()
```

It's not looking too bad... but we're also getting our first hint of trouble to come. The first time I tried to use this provider, I didn't have lines 46 and 55. It turns out that the default attributes of a ``ProvidedTypeDefinition`` set the ``Sealed`` attribute on the class that's generated. If you then try and build a type that inherits from it, you get an error when you try and consume the types from the provider.

But, hey? We've worked around that, right? I'm sure there's no reason it's set that way by default...

And: we have types. Lots of types:

```fsharp
#!/usr/bin/env fsharpi
#r @"AdventProvider.dll"

open AdventProvider
open Advent.Provided

type JesusGenerations = Family<"Genealogy.txt">

printfn "%s" JesusGenerations.Raw

JesusGenerations.Abraham.Isaac.Jacob.Judah.Perez.Hezron.Ram.Amminadab
// ... there's more where that came from
```

We can even do things like this:

```fsharp
let DescendedFromAbraham (person : JesusGenerations.Abraham) =
    true
```

Compile time family tree checking - pretty nifty. Except... when we try and call this function we realise we have a problem. None of these classes have constructors.

Hmmm.

Let's try and add one. Nothing fancy - just a default constructor.

We'll replace the ``personToType`` method with this:

```fsharp
let rec personToType (father : ProvidedTypeDefinition) (person : Person) =
    let t = ProvidedTypeDefinition(person.Name, Some (father :> System.Type), IsErased = false)
    t.SetAttributes (TypeAttributes.Class ||| TypeAttributes.Public)
    let c = ProvidedConstructor([])
    c.InvokeCode <-
        fun args ->
            match args with
            | [] ->
                failwith "Generated constructors should always pass the instance as the first argument!"
            | _ ->
                <@@ () @@>
    t.AddMember c
    father.AddMember t
    match person.Heir with
    | Some p -> personToType t p
    | None -> ()
```

All looks good. In here you can see one of the first differences between erased and generated type. For a generated type, the first input arg to the constructor is the instance of the type to be initialized - and the return type of the constructor should be null.

The only problem is that our type provider errors immediately on usage with an "Argument cannot be null. Parameter name: obj" error. Not immediately informative.

A quick check with a type provider providing a single type later, we can confirm that the constructor above is valid; sounds like we're having issues with the fact that we're inheriting from a provided type. Maybe they're sealed for a reason after all. Still; we're not to be deterred so easily!

*Cue dramatic music of choice!*

Taking an guess, we'll assume this might have something to do with the ``JesusGenerations`` type not having a constructor; we'll add one and try again and... no dice. Same error.

Which is round about the time I noticed that provided constructors also have a ``BaseConstructorCall`` property. Time for a slightly more invasive rewrite, leaving us an overall type provider that looks like this:

```fsharp
module AdventProvider
#if INTERACTIVE
#load "paket-files/fsprojects/FSharp.TypeProviders.StarterPack/src/ProvidedTypes.fsi"
#load "paket-files/fsprojects/FSharp.TypeProviders.StarterPack/src/ProvidedTypes.fs"
#load "Parser.fs"
#endif

open System.Reflection
open ProviderImplementation.ProvidedTypes
open Microsoft.FSharp.Core.CompilerServices
open Microsoft.FSharp.Quotations
open Parser

[<TypeProvider>]
type AdventProvider (cfg : TypeProviderConfig) as this =
    inherit TypeProviderForNamespaces ()

    let ns = "Advent.Provided"
    let asm = Assembly.GetExecutingAssembly()
    let tempAsmPath = System.IO.Path.ChangeExtension(System.IO.Path.GetTempFileName(), ".dll")
    let tempAsm = ProvidedAssembly tempAsmPath

    let t = ProvidedTypeDefinition(asm, ns, "Family", Some typeof<obj>, IsErased = false)
    let parameters = [ProvidedStaticParameter("Genealogy", typeof<string>)]

    do
        t.DefineStaticParameters(
            parameters,
            fun typeName args ->
                let genealogy = args.[0] :?> string
                let inputFile = 
                    System.IO.Path.Combine(cfg.ResolutionFolder, genealogy)
                let raw =
                    System.IO.File.ReadAllLines inputFile
                let input =
                    raw
                    |> Seq.toList
                    |> Parse

                let g = ProvidedTypeDefinition(
                            asm, 
                            ns, 
                            typeName, 
                            Some typeof<obj>, 
                            IsErased = false)
                g.SetAttributes (TypeAttributes.Public ||| TypeAttributes.Class)

                let s = ProvidedProperty("Raw", typeof<string>, IsStatic = true)
                let rawStr = String.concat "\n" raw
                s.GetterCode <- fun _ -> Expr.Value rawStr
                g.AddMember s

                let c = ProvidedConstructor([])
                c.InvokeCode <-
                    fun args ->
                        match args with
                        | [] ->
                            failwith "Generated constructors should always pass the instance as the first argument!"
                        | _ ->
                            <@@ () @@>
                g.AddMember c

                let rec personToType (father : ProvidedTypeDefinition) fatherCtor (person : Person) =
                    let t = ProvidedTypeDefinition(person.Name, Some (father :> System.Type), IsErased = false)
                    t.SetAttributes (TypeAttributes.Class ||| TypeAttributes.Public)
                    let c = ProvidedConstructor([])
                    c.BaseConstructorCall <- fun args -> (fatherCtor, args)
                    c.InvokeCode <-
                        fun args ->
                            match args with
                            | [] ->
                                failwith "Generated constructors should always pass the instance as the first argument!"
                            | _ ->
                                <@@ () @@>
                    t.AddMember c
                    father.AddMember t
                    match person.Heir with
                    | Some p -> personToType t c p
                    | None -> ()

                match input with
                | Some p ->
                    personToType g c p
                | None ->
                    ()

                tempAsm.AddTypes [g]
                
                g
            )

    do
        this.RegisterRuntimeAssemblyLocationAsProbingFolder cfg
        tempAsm.AddTypes [t]
        this.AddNamespace(ns, [t])

[<assembly:TypeProviderAssembly>]
do ()
```

It all builds, we can reference it... and then we get: 

    The type provider 'AdventProvider+AdventProvider' reported an error: User defined subclasses of System.Type are not yet supported

Hmm. Irritating. Especially as the error message is actually incorrect; we're not subclassing System.Type and we know that that was working correctly as the types were being generated correctly before we tried to add constructors to them. But it looks like we might have hit the limits of what the current type provider implementation allows.

But we're still not quite done yet; let's turn the insanity up a notch.

*Cue your choice of even more dramatic music or Benny Hill here*

As well as actual inheritance in .net, we have interfaces which can be used to model inheritance. Let's have a last throw of the dice, and see whether we can create generated interfaces to do compile time ancestry checking.

Adding an ``Interface`` at every level turns out to be fairly easy, and it appears we can create generated interfaces - a useful trick to have up your sleeve. Let's have a look what that looks like:

```fsharp
module AdventProvider
#if INTERACTIVE
#load "paket-files/fsprojects/FSharp.TypeProviders.StarterPack/src/ProvidedTypes.fsi"
#load "paket-files/fsprojects/FSharp.TypeProviders.StarterPack/src/ProvidedTypes.fs"
#load "Parser.fs"
#endif

open System.Reflection
open ProviderImplementation.ProvidedTypes
open Microsoft.FSharp.Core.CompilerServices
open Microsoft.FSharp.Quotations
open Parser

[<TypeProvider>]
type AdventProvider (cfg : TypeProviderConfig) as this =
    inherit TypeProviderForNamespaces ()

    let ns = "Advent.Provided"
    let asm = Assembly.GetExecutingAssembly()
    let tempAsmPath = System.IO.Path.ChangeExtension(System.IO.Path.GetTempFileName(), ".dll")
    let tempAsm = ProvidedAssembly tempAsmPath

    let t = ProvidedTypeDefinition(asm, ns, "Family", Some typeof<obj>, IsErased = false)
    let parameters = [ProvidedStaticParameter("Genealogy", typeof<string>)]

    do
        t.DefineStaticParameters(
            parameters,
            fun typeName args ->
                let genealogy = args.[0] :?> string
                let inputFile = 
                    System.IO.Path.Combine(cfg.ResolutionFolder, genealogy)
                let raw =
                    System.IO.File.ReadAllLines inputFile
                let input =
                    raw
                    |> Seq.toList
                    |> Parse

                let g = ProvidedTypeDefinition(
                            asm, 
                            ns, 
                            typeName, 
                            Some typeof<obj>, 
                            IsErased = false)

                let s = ProvidedProperty("Raw", typeof<string>, IsStatic = true)
                let rawStr = String.concat "\n" raw
                s.GetterCode <- fun _ -> Expr.Value rawStr
                g.AddMember s

                let rec personToType (father : ProvidedTypeDefinition) (fatherInterfaces : System.Type list) (person : Person) =
                    let t = ProvidedTypeDefinition(person.Name, Some typeof<obj>, IsErased = false)
                    let parentInterface =
                        match fatherInterfaces with
                        | [] -> None
                        | h::_ -> Some h
                    let i = ProvidedTypeDefinition("I" + person.Name, None, IsErased = false)
                    i.SetAttributes (TypeAttributes.Public ||| TypeAttributes.Interface ||| TypeAttributes.Abstract)
                    father.AddMembers [t;i]
                    match person.Heir with
                    | Some p -> personToType t (i :> System.Type::fatherInterfaces) p
                    | None -> ()

                match input with
                | Some p ->
                    personToType g [] p
                | None ->
                    ()

                tempAsm.AddTypes [g]
                
                g
            )

    do
        this.RegisterRuntimeAssemblyLocationAsProbingFolder cfg
        tempAsm.AddTypes [t]
        this.AddNamespace(ns, [t])

[<assembly:TypeProviderAssembly>]
do ()
```

Line 58 and 59 do all the work - normally an interface has no base type, and we need to reset the type attributes to make the interface look like an interface to the compiler. This all works well - but doesn't, of course, give us any inheritance. Lets see if we can use those "fatherInterfaces" I've fed into the function to get us any closer.

A brief experiment with ``IDisposable`` shows us that if we change the base type of the interface to ``Some typeof<System.IDisposable>``, that actually works. Again - useful type provider knowledge, but doesn't help us here. No dice on using the parent interface as the base type - we just start getting into more of the problems we were having above inheriting from other generated types.

So let's see what happens if instead we use implement interface instead of trying to inherit the interface; it seems about as reasonable as anything else we're tried so far...

We'll add this:

```fsharp
fatherInterfaces
|> List.iter i.AddInterfaceImplementation
```

after line 59 of the version above and see what happens.

## <a name="conclusion"></a> Conclusion

And suddenly... hey presto! We can do things like this:

```fsharp
#!/usr/bin/env fsharpi
#r @"AdventProvider.dll"

open AdventProvider
open Advent.Provided

type JesusGenerations = Family<"Genealogy.txt">

printfn "%s" (JesusGenerations.Raw.Substring(0, 20) + "...")

let descendentOfAbraham (_ : #JesusGenerations.IAbraham) = true
let descendentOfDavid 
        (_ : 
            #JesusGenerations
                .Abraham
                .Isaac
                .Jacob
                .Judah
                .Perez
                .Hezron
                .Ram
                .Amminadab
                .Nahshon
                .Salmon
                .Boaz
                .Obed
                .Jesse
                .IDavid) = true


// This compiles...
printfn "%A" <| descendentOfAbraham ({ new JesusGenerations.Abraham.IIsaac })

// So does this:
printfn "%A" <|
    descendentOfDavid 
        ({ new JesusGenerations
                .Abraham
                .Isaac
                .Jacob
                .Judah
                .Perez
                .Hezron
                .Ram
                .Amminadab
                .Nahshon
                .Salmon
                .Boaz
                .Obed
                .Jesse
                .David
                .Solomon
                .Rehoboam
                .IAbijah })

// This doesn't - how cool is that?
(* printfn "%A" <|
    descendentOfDavid ({ new JesusGenerations.Abraham.IIsaac }) *)
```

Which personally I think is pretty awesome.

There is, unfortunately, only one problem. Whilst we now have compile time propositional logic... unfortunately our code fails at runtime with a type load error. Whilst the compiler is happy with the IL my random hacking has turned at, apparently the runtime is not.

Maybe next year...

I hope you enjoyed this random journey down the rabbit hole of type providers; and if you're interested in looking into the genealogy a bit further [this article](http://christianity.about.com/od/biblefactsandlists/a/jesusgenealogy.htm) gives a brief overview of a few things, like why we think Jesus has two different genealogies in the bible and how Jewish genealogies didn't always include every generation.

See you next time: and if anyone can get the inheritance to work properly, I'll owe you a beverage of (reasonable) choice!

The code from this blog post can, as normal be found on github in the [Advent2014](https://github.com/mavnn/Advent2014) repository.

It's set up to be developed in Vim or Emacs without project files on a nix system, but it will probably play nicely with Visual Studio as well.
