---
layout: post
title: "Testing ProvidedType.fs by Example"
date: 2015-02-16 12:12:56 +0000
comments: true
categories: [fsharp, programming, typeprovider]
---
The [Type Provider Starter Pack](https://github.com/fsprojects/FSharp.TypeProviders.StarterPack) was designed with two purposes initially. Firstly, to be a canonical repository for the ProvidedTypes files which provide a source file based API for creating type providers. And secondly, to be a set of tutorials and examples for people wanting to dip their toes into building type providers for the first time.

To be honest, it's not been doing a complete job of either:

* I think most people are using it as the source of ProvidedTypes.fs and .fsi now days, but it didn't provide any infrastructure or testing for progressing the library.
* The "examples" were limited to a link to my [tutorial on building type providers](/type-providers-from-the-ground-up/)

Today, that's changed. And I need your help!

### Testing ProvidedTypes

Once I started thinking about it, it became clear that the code needed for basic type provider examples, and the code needed to test ProvidedTypes.fs were basically identical.

So I implemented a system for compiling and testing example .fsx scripts within the Starter Pack repository.

Want to help out? As long as you have some basic git and F# knowledge, it's easy!

<!-- more -->

#### Fork the repository and pull down a clone

#### Add an example to the ``/examples`` directory

Structure the example as below and save it as an .fsx file:

``` fsharp
#if INTERACTIVE
#load "../src/ProvidedTypes.fsi"
#load "../src/ProvidedTypes.fs"
#endif

open ProviderImplementation.ProvidedTypes
open Microsoft.FSharp.Core.CompilerServices
open System.Reflection

[<TypeProvider>]
type BasicProvider (config : TypeProviderConfig) as this =
    inherit TypeProviderForNamespaces ()

    let ns = "StaticProperty.Provided"
    let asm = Assembly.GetExecutingAssembly()

    let createTypes () =
        let myType = ProvidedTypeDefinition(asm, ns, "MyType", Some typeof<obj>)
        let myProp = ProvidedProperty("MyProperty", typeof<string>, IsStatic = true,
                                        GetterCode = (fun args -> <@@ "Hello world" @@>))
        myType.AddMember(myProp)
        [myType]

    do
        this.AddNamespace(ns, createTypes())

[<assembly:TypeProviderAssembly>]
do ()
```

The ``#if INTERACTIVE`` block at the top will allow you to write your example in Visual Studio, without us requiring a separate project for each example provider.

#### Add a set of tests in a .fsx script in the ``/examples`` directory

The test file for the example above looks like this, and again should be saved as an .fsx file:

``` fsharp
#if INTERACTIVE
#r @"../packages/Nunit.Runners/tools/nunit.framework.dll"
#r @"../test/StaticProperty.dll"
#endif

open NUnit.Framework
open StaticProperty.Provided

[<Test>]
let ``Static property should have been created`` () =
    Assert.AreEqual("Hello world", MyType.MyProperty)
```

Note the two #r references at the top. Remember what you choose to call the dll!

#### Hooking up the examples so they get built and tested

The main build file is where the magic happens - [build.fsx](https://github.com/fsprojects/FSharp.TypeProviders.StarterPack/blob/master/build.fsx) in the root directory.

Squirrelled away in there is a target called ``Examples``. It's contents look like this:

``` fsharp
let examples =
    [
        {
            Name = "StaticProperty"
            ProviderSourceFiles = ["StaticProperty.fsx"]
            TestSourceFiles = ["StaticProperty.Tests.fsx"]
        }
        {
            Name = "ErasedWithConstructor"
            ProviderSourceFiles = ["ErasedWithConstructor.fsx"]
            TestSourceFiles = ["ErasedWithConstructor.Tests.fsx"]
        }
    ]

let testNunitDll = testDir @@ "nunit.framework.dll"

do
    if File.Exists testNunitDll then
        File.Delete testNunitDll
    File.Copy (nunitDir @@ "nunit.framework.dll", testNunitDll)

let fromExampleDir filenames =
    filenames
    |> List.map (fun filename -> exampleDir @@ filename)

examples
|> List.iter (fun example ->
        // Compile type provider
        let output = testDir @@ example.Name + ".dll"
        let setOpts = fun def -> { def with Output = output; FscTarget = FscTarget.Library }
        Fsc setOpts (List.concat [pt;fromExampleDir example.ProviderSourceFiles])

        // Compile test dll
        let setTestOpts = fun def ->
            { def with 
                Output = testDir @@ example.Name + ".Tests.dll"
                FscTarget = FscTarget.Library
                References = [output;nunitDir @@ "nunit.framework.dll"] }
        Fsc setTestOpts (fromExampleDir example.TestSourceFiles)
    )
```

You will need to add your example to the ``examples`` list at the top of the target. ``Name`` is the name of the dll that will be produced for your type provider. ``ProviderSourceFiles`` is the fsx file with your type provider example code. And ``TestSourceFiles`` is the code of your tests.

If you check further down, the call to the compiler to compile your provider will automatically prepend the ProvidedTypes files, so there's no need to list those. And the call to the compiler to run your tests will have references added for the provider you just built and ``nunit.framework.dll``.

So what are you waiting for? Get writing some examples!
