---
layout: post
title: "Type Providers from the Ground Up"
date: 2013-12-05 11:28
comments: true
categories: [fsharp, programming, typeprovider]
---

*This post is part of a series: [part 2](/type-providers-from-the-first-floor/) follows on directly from this post.*

In the ground tradition of blog posts as both documentation and augmented memory, I've just added our first [Type Provider](http://blogs.msdn.com/b/dsyme/archive/2013/01/30/twelve-type-providers-in-pictures.aspx) to the code base. Time to write up the details before a) I forget them and b) anyone else needs to modify the code.

So, first things first. Before we get to the actual problem space at hand, let's try and provide a type. Any type...

1) Create yourself a new Visual Studio F# library project (2012 or up should work).

2a) Install the [F# TypeProvider Starter Pack](https://www.nuget.org/packages/FSharp.TypeProviders.StarterPack/) or

2b) add [ProvidedTypes.fs](https://raw.github.com/fsharp/FSharp.Data/master/src/CommonProviderImplementation/ProvidedTypes.fs) and [ProvidedTypes.fsi](https://raw.github.com/fsharp/FSharp.Data/master/src/CommonProviderImplementation/ProvidedTypes.fsi) to the project as the first couple of files.

In either case, make sure that the .fsi file appears before the .fs file in your project listing, and that both appear before any type provider code - you will probably have to manually re-order them.

These are provided as code files rather than as compiled dlls due to complications with security and AppDomains when referencing dlls in the type provider assembly. For now just add them in - you really don't want to be re-creating the code in there by hand.

3) Replace the contents of Library1.fs with something like this:

``` fsharp
module Mavnn.Blog.TypeProvider

open ProviderImplementation.ProvidedTypes
open Microsoft.FSharp.Core.CompilerServices

[<TypeProvider>]
type MavnnProvider (config : TypeProviderConfig) as this =
    inherit TypeProviderForNamespaces ()

[<assembly:TypeProviderAssembly>]
do ()
```

So, that's great and it builds. We have a type provider class and an assembly that knows it's a type providing assembly. Unfortunately, it doesn't actually provide any types yet. Let's try it.

<!--more-->

Update Library1.fs in your solution with something that looks like this, and then we'll run through what's going on, and how to test it.

``` fsharp
module Mavnn.Blog.TypeProvider

open ProviderImplementation.ProvidedTypes
open Microsoft.FSharp.Core.CompilerServices
open System.Reflection

[<TypeProvider>]
type MavnnProvider (config : TypeProviderConfig) as this =
    inherit TypeProviderForNamespaces ()

    let ns = "Mavnn.Blog.TypeProvider.Provided"
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

First things first - it looks like it should provide a class with a static property, but how do we test it?

It turns out it's harder than it looks. If you reference your brand new type provider in Visual Studio, that instance of Visual Studio will promptly lock the dll file. Which means you can't recompile it. So referencing the dll from within the instance of Visual Studio you're using to develop it is a no go.

Fire up a second copy of Visual Studio (you went for the extra RAM option on your hardware, yes?) and create an F# project in it. Add an fsx file that looks something like this:

``` fsharp
// Your path may vary...
#r @"../../Mavnn.Blog.TypeProvider/Mavnn.Blog.TypeProvider/bin/Debug/Mavnn.Blog.TypeProvider.dll"

open Mavnn.Blog.TypeProvider.Provided

// Type `MyType.MyProperty` on next line down.
```

Start typing, and... hurrah! Intellisense on your new, provided type with static property. Evaluate the script in F# interactive for one of the longest "Hello World" programs you've ever seen.

*You will need to close this instance of Visual Studio every time you want to recompile the type provider.*

## What's going on here?

We're declaring a new namespace and detecting the current assembly so we can inject things into it. During our initializing for the type provider, we then add that namespace to the assembly (`this.AddNamespace(...)`) along with a type created in the slightly (at the moment) misnamed `createTypes` method.

In `createTypes` we're first creating a type (`MyType`) which will be a direct member of the namespace we're creating (we'll get onto nested types shortly), then we're creating a static property and adding it to the type. `AddNamespace` takes a list of types, so will add the one we have to a list and pass it back.

`MyType`'s underlying representation in the CLR has been defined as `obj`, which means that if you try and access it in a non-F# language it will appear to the compiler as an `object`.

All well and good... except for the rather bizarre `<@@ ... @@>` syntax in our static property. Obviously, in some way it's creating a get method for the property that returns `"Hello world"`, but how does it do it? 

This syntax represents a [code quotation](http://msdn.microsoft.com/en-us/library/dd233212.aspx), and rather than being compiled into your program it will compile to an object that represents an expression.

Did that make your brain hurt? Mine too... I'm not going to go into quotations in great detail here (partly as I don't understand them well enough!) but we'll need to cover a couple of basics.

To give you a flavour, the quotation `<@@ 1 + 2 @@>` compiles to `Quotations.Expr = Call (None, op_Addition, [Value (1), Value (2)])`. Not very exciting so far, but how about:

``` fsharp
let addI i =
    <@@ 1 + (%%i) @@>
```

This gives a function of `Expr -> Expr`, and now we can do things like `let add2 = addI <@@ 2 @@>` (gives `val add2 : Expr = Call (None, op_Addition, [Value (1), Value (2)])`) or `let add2MultipliedByX x = addI <@@ 2 * x @@>` (gives `val add2MultipliedByX : x:int -> Expr`) and what we get back is effectively the AST of the first F# expression with the second spliced in to evaluate as you will. So in our `GetterCode` above, we are actually providing the AST that will be compiled into the `get_MyPropertyMethod` of the type when it is created.

The second thing that you need to know about quotations for current purposes is that the thing evaluating them may or may not be able to handle the F# expression you've created. Which again we'll get back to in a moment!

So far, our type isn't very exciting. You can't even construct an instance of it. Let's see what we can do about that, with a replacement `createTypes` method:

``` fsharp
    let createTypes () =
        let myType = ProvidedTypeDefinition(asm, ns, "MyType", Some typeof<obj>)
        let myProp = ProvidedProperty("MyProperty", typeof<string>, IsStatic = true, 
                                        GetterCode = fun args -> <@@ "Hello world" @@>)
        myType.AddMember(myProp)

        let ctor = ProvidedConstructor([], InvokeCode = fun args -> <@@ "My internal state" :> obj @@>)
        myType.AddMember(ctor)

        let ctor2 = ProvidedConstructor(
                        [ProvidedParameter("InnerState", typeof<string>)],
                        InvokeCode = fun args -> <@@ (%%(args.[0]):string) :> obj @@>)
        myType.AddMember(ctor2)

        let innerState = ProvidedProperty("InnerState", typeof<string>,
                            GetterCode = fun args -> <@@ (%%(args.[0]) :> obj) :?> string @@>)
        myType.AddMember(innerState)

        [myType]
        
    do
        this.AddNamespace(ns, createTypes())
```

Now we can construct our type (in two ways, no less). As the underlying CLR type is an `object` we can store pretty much anything as the internal representation of an instance of our type. The `InvokeCode` parameter of the constructors needs to return a quotation that will return the internal representation of the object when it's evaluated. We're going to return a string (which we need to cast to an obj), and using the splicing syntax above we can inject the parameters of the constructor into the quotation (for the constructor which has a parameter).

Similarly, we also add a property (notice that we're not setting it to be a static property this time). Because this property is not static, the first item in the `args` Array is the instance of the type itself (similar to the way that you define an extension method). So we can splice that into our method quotation (remembering to cast it from `obj` to `string`) and expose the underlying state of the object for all the world to see.

And now you can do things like this:

``` fsharp
// Your path may vary...
#r @"../../Mavnn.Blog.TypeProvider/Mavnn.Blog.TypeProvider/bin/Debug/Mavnn.Blog.TypeProvider.dll"

open Mavnn.Blog.TypeProvider.Provided

let thing = MyType()
let thingInnerState = thing.InnerState

let thing2 = MyType("Some other text")
let thing2InnerState = thing2.InnerState

// val thing : Mavnn.Blog.TypeProvider.Provided.MyType = "My internal state"
// val thingInnerState : string = "My internal state"
// val thing2 : Mavnn.Blog.TypeProvider.Provided.MyType = "Some other text"
// val thing2InnerState : string = "Some other text"
```

## And the point is?

Well - this is great, except the perceptive among you will have noticed that we're just generating a static type here. We could have just declared it using normal syntax.

So let's try going a step further. Let's say that we have some Json definitions of graph nodes types, each with a defined set of input and output "ports". All of these graph bits are given to us as a Json array, and each Node type and port has a Guid identifier and a friendly name.

Our input JSON looks something like this:

``` json
[
   {
      "Id":{
         "Name":"Simple",
         "UniqueId":"0ab82262-0ad3-47d3-a026-615b84352822"
      },
      "Ports":[
         {
            "Id":{
               "Name":"Input",
               "UniqueId":"4b69408e-82d2-4c36-ab78-0d2327268622"
            },
            "Type":"input"
         },
         {
            "Id":{
               "Name":"Output",
               "UniqueId":"92ae5a96-6900-4d77-832f-d272329f8a90"
            },
            "Type":"output"
         }
      ]
   },
   {
      "Id":{
         "Name":"Join",
         "UniqueId":"162c0981-4370-4db3-8e3f-149f13c001da"
      },
      "Ports":[
         {
            "Id":{
               "Name":"Input1",
               "UniqueId":"c0fea7ff-456e-4d4e-b5a4-9539ca134344"
            },
            "Type":"input"
         },
         {
            "Id":{
               "Name":"Input2",
               "UniqueId":"4e93c3b1-11bc-422a-91b8-e53204368714"
            },
            "Type":"input"
         },
         {
            "Id":{
               "Name":"Output",
               "UniqueId":"fb54728b-9602-4220-ba08-ad160d92d5a4"
            },
            "Type":"output"
         }
      ]
   },
   {
      "Id":{
         "Name":"Split",
         "UniqueId":"c3e44941-9182-41c3-921c-863a82097ba8"
      },
      "Ports":[
         {
            "Id":{
               "Name":"Input",
               "UniqueId":"0ec2537c-3346-4503-9f5a-d0bb49e9e431"
            },
            "Type":"input"
         },
         {
            "Id":{
               "Name":"Output1",
               "UniqueId":"77b5a50c-3d11-4a67-b14d-52d6246e78c5"
            },
            "Type":"output"
         },
         {
            "Id":{
               "Name":"Output2",
               "UniqueId":"d4d1e928-5347-4d51-be54-8650bdfe9bac"
            },
            "Type":"output"
         }
      ]
   }
]
```

Things start getting a bit more in depth here, so you might want to check out the full code for this post, available on [GitHub](https://github.com/mavnn/Mavnn.Blog.TypeProvider), and follow along in your favourite development environment.

We'll let someone else deal with the parsing - add a Nuget reference to `Newtonsoft.Json` to your type provider, and let's have a third reprise of `createTypes`.

First, we'll need some classes to deserialize the Json into. Out of the box Newtonsoft doesn't do a great job on F# core classes (although that's changing), so for the moment we'll create some classic OO style mutable types:

``` fsharp
type Id () =
    member val UniqueId = Guid() with get, set
    member val Name = "" with get, set

type Port () =
    member val Id = Id() with get, set
    member val Type = "" with get, set

type Node () =
    member val Id = Id() with get, set
    member val Ports = Collections.Generic.List<Port>() with get, set
```

(Don't worry though, these aren't what we'll actually expose as the main interface.)

Turning our Json into the our new CLR types is straight forward:

``` fsharp
let nodes =
    JsonConvert.DeserializeObject<seq<Node>>(IO.File.ReadAllText(@"c:\Temp\Graph.json"))
```

Now the interesting part. To build a graph out of these nodes, we need to be able to do a few things.

Firstly, we need to be able to build a specific instance of a node type: which `Split` node is this? 

Let's help ourselves out by having a concrete type as an the underlying type for our instances:

``` fsharp
type nodeInstance =
    {
        Node : Node
        InstanceId : Id
        Config : string
    }

module private NodeInstance =
    let create node name guid config =
        { Node = node; InstanceId = Id(Name = name, UniqueId = guid); Config = config }  
```

And then constructing a more specific type with a constructor for each node type we've read from the Json:

``` fsharp
let nodeType = ProvidedTypeDefinition(asm, ns, node.Id.Name, Some typeof<nodeInstance>)
let ctor = ProvidedConstructor(
            [
                ProvidedParameter("Name", typeof<string>)
                ProvidedParameter("UniqueId", typeof<Guid>)
                ProvidedParameter("Config", typeof<string>)
            ],
            InvokeCode = fun [name;unique;config] -> <@@ NodeInstance.create (GetNode id) (%%name:string) (%%unique:Guid) (%%config:string) @@>)
```

So now we can construct (look back at the json) a `Simple` node instance by using `let simple = Simple("simpleInstance", Guid.NewGuid(),"MyConfig")`. And it already has our `InstanceId`, `Config` and `Node` properties from the underlying type.

Good progress - but we don't have a nice way of representing the inputs and outputs? We want to be able to write some kind of connection builder function afterwards that won't allow you to connect to outputs to each other, or similar silliness, so we're going to need separate types for inputs and outputs.

``` fsharp
// Check out the excellent article at F# for Fun and Profit
// on using single case Discriminated Unions for data modelling
// http://fsharpforfunandprofit.com/posts/designing-with-types-single-case-dus/

type InputPort = | InputPort of Port
type OutputPort = | OutputPort of Port
```

And finally, we'll update our node creation function to add two subtypes to each node type called `Inputs` and `Outputs`, and then create properties on those objects to represent each port. Our full type creation for a node now looks something like this:

``` fsharp
let addInputPort (inputs : ProvidedTypeDefinition) (port : Port) =
    let port = ProvidedProperty(
                    port.Id.Name, 
                    typeof<InputPort>, 
                    GetterCode = fun args -> 
                        let id = port.Id.UniqueId.ToString()
                        <@@ GetPort id @@>)
    inputs.AddMember(port)

let addOutputPort (outputs : ProvidedTypeDefinition) (port : Port) =
    let port = ProvidedProperty(
                    port.Id.Name, 
                    typeof<OutputPort>, 
                    GetterCode = fun args -> 
                        let id = port.Id.UniqueId.ToString()
                        <@@ GetPort id @@>)
    outputs.AddMember(port)

let addPorts inputs outputs (portList : seq<Port>) =
    portList
    |> Seq.iter (fun port -> 
                    match port.Type with
                    | "input" -> addInputPort inputs port
                    | "output" -> addOutputPort outputs port
                    | _ -> failwithf "Unknown port type for port %s/%s" port.Id.Name (port.Id.UniqueId.ToString()))

let createNodeType id (node : Node) =
    let nodeType = ProvidedTypeDefinition(asm, ns, node.Id.Name, Some typeof<nodeInstance>)
    let ctor = ProvidedConstructor(
                [
                    ProvidedParameter("Name", typeof<string>)
                    ProvidedParameter("UniqueId", typeof<Guid>)
                    ProvidedParameter("Config", typeof<string>)
                ],
                InvokeCode = fun [name;unique;config] -> <@@ NodeInstance.create (GetNode id) (%%name:string) (%%unique:Guid) (%%config:string) @@>)
    nodeType.AddMember(ctor)

    let outputs = ProvidedTypeDefinition("Outputs", Some typeof<obj>)
    let outputCtor = ProvidedConstructor([], InvokeCode = fun args -> <@@ obj() @@>)
    outputs.AddMember(outputCtor)
    outputs.HideObjectMethods <- true

    let inputs = ProvidedTypeDefinition("Inputs", Some typeof<obj>)
    let inputCtor = ProvidedConstructor([], InvokeCode = fun args -> <@@ obj() @@>)
    inputs.AddMember(inputCtor)
    inputs.HideObjectMethods <- true
    addPorts inputs outputs node.Ports

    // Add the inputs and outputs types of nested types under the Node type
    nodeType.AddMembers([inputs;outputs])

    // Now add some instance properties to expose them on a node instance.
    let outputPorts = ProvidedProperty("OutputPorts", outputs, [],
                        GetterCode = fun args -> <@@ obj() @@>)
    let inputPorts = ProvidedProperty("InputPorts", inputs, [],
                        GetterCode = fun args -> <@@ obj() @@>)

    nodeType.AddMembers([inputPorts;outputPorts])

    nodeType
```

Leaving only one final mystery. What are the `GetPort` and `GetNode` methods - and why am I using them in the quotations rather than just using something like `<@@ node @@>`?

Well, if you remember I mentioned earlier that the evaluation of a quotation is limited by the implementation of the evaluator used. The type provider files you included right at the beginning contain an evaluator that turn a quotation into IL instructions - but, it doesn't include support for literals of custom types. In fact, if you check in [the relevant part of ProvidedTypes.fs](https://github.com/fsharp/FSharp.Data/blob/master/src/CommonProviderImplementation/ProvidedTypes.fs#L1876) you'll see that it's actually quite prescriptive.

So, what we do is we build a couple of private helper methods that know how to find the correct port or node from one of the types that is allowed - in this case, a `string`:

``` fsharp
let private nodes = JsonConvert.DeserializeObject<seq<Node>>(IO.File.ReadAllText(@"c:\Temp\Graph.json"))
                    |> Seq.map (fun n -> n.Id.UniqueId.ToString(), n)
                    |> Map.ofSeq

let GetNode id =
    nodes.[id]

let private ports =
    nodes
    |> Map.toSeq
    |> Seq.map (fun (_, node) -> node.Ports)
    |> Seq.concat
    |> Seq.map (fun p -> p.Id.UniqueId.ToString(), p)
    |> Map.ofSeq

let GetPort id =
    ports.[id]
```

So, there you have it. A complete, working type provider that uses meta data supplied in Json format to create CLR types. Lots of things still to be added for production ready code (delayed loading, handling multiple ports with the same names, not hard coding the filename, etc).

![Winning...](/images/typeprovider.png)


Any questions or corrections, fire away. As mentioned, this is very much the first time I've used type providers - but even this level of usage is providing a goodly amount of value for us.

And if you're ready for the next challenge... off to [part 2](/type-providers-from-the-first-floor/) with you!
