---
layout: post
title: "Type Providers From the First Floor"
date: 2014-03-19 21:06:05 +0000
comments: true
categories: [fsharp, programming, typeprovider]
---

*This post follows on directly from my previous post [Type Providers from the Ground Up](https//blog.mavnn.co.uk/type-providers-from-the-ground-up/). I highly recommend that you read that first, and check out the relevant example code from GitHub.*

*It's also a bit epic... grab yourself a coffee before you start.*

So we have a working type provider now. Unfortunately, we're missing out on at least two major features that your new type provider will almost certainly want to make use of.

The first is that in our example, we're reading the metadata that defines our types from a fixed file location. In almost every real life case, you will want to be able to parametrize your provider to specify where this instance is getting it's metadata from.

The second is that in many cases getting the metadata will be slow, and the number of types available to generate may be very large. In these situations, you really want to be able to only generate the types that are required as they are requested, especially because this will reduce the size of the final compiled output. This is particularly important for type providers that read from large network based data sources like the Freebase provider.

We'll take the second first, because it's easy - and we like easy...

<!-- more -->

## Generating types on demand

This is in many ways one of the features that makes type providers uniquely powerful compared to code generation. Because the types are being requested by the compiler as needed, type providers can give meaningful access to literally infinite type hierarchies.

So, does all this power come with great cost and complexity? Not really, no.

Let's take the our node creation function, with some bits snipped out:

``` fsharp
let createNodeType id (node : Node) =
    let nodeType = ProvidedTypeDefinition(asm, ns, node.Id.Name, Some typeof<nodeInstance>)
    // ... snip constructors

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

To make the ports deferred, we simply change the ``AddMembers`` call at the end to ``AddMembersDelayed`` and wrap the creation of the array in a function that takes ``unit``.

It ends up looking like this:

``` fsharp
let createNodeType id (node : Node) =
    let nodeType = ProvidedTypeDefinition(asm, ns, node.Id.Name, Some typeof<nodeInstance>)
    // ... snip out the constructor again...

    let addInputOutput () =
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
        [inputPorts;outputPorts]

    nodeType.AddMembersDelayed(addInputOutput)

    nodeType
```

Now the input and output ports of a node will only be generated the first time that the compiler needs them available. If you don't use a particular node in your program, then the compiler will never generate it's ports, and they will not be including in your final build output.

Of course, in this case we're pre-loading all of our metadata anyway, but hopefully this gives you an idea.

## Parametrizing the Data Source

Currently, we're reading the json that's generating our types like this:

``` fsharp
let private nodes = JsonConvert.DeserializeObject<seq<Node>>(IO.File.ReadAllText(@"c:\Temp\Graph.json"))
                    |> Seq.map (fun n -> n.Id.UniqueId.ToString(), n)
                    |> Map.ofSeq
```

Lovely.

Now, you'll probably of noticed from playing with other type providers that they allow you to do funky things like:

``` fsharp
type myThing = FancyProvider<"configStringThing">
```

This is actually one of the things that kept me going for longest in writing my first type provider, and I have to admit I'm still not fully certain why it's done this way.

At the moment, if we strip out all of the type creation logic, our type provider looks like this:

``` fsharp
[<TypeProvider>]
type MavnnProvider (config : TypeProviderConfig) as this =
    inherit TypeProviderForNamespaces ()

    let ns = "Mavnn.Blog.TypeProvider.Provided"
    let asm = Assembly.GetExecutingAssembly()

    // ... massive snip

    let createNodeType id (node : Node) =
        let nodeType = ProvidedTypeDefinition(asm, ns, node.Id.Name, Some typeof<nodeInstance>)
        // ... more snipped here ...

    let createTypes () =
        nodes |> Map.map createNodeType |> Map.toList |> List.map (fun (k, v) -> v)

    do
        this.AddNamespace(ns, createTypes())
```

As you can see, we add the types to the namespace during the initialization of the MavnnProvider type.

This is no good if we want to add parameters - after all, we don't know what they are yet. And the same provider might be used several times with different parameters. Also, when we create our provided type (``let nodeType = ...``) we're putting into a fixed space in the assemblies namespace. Again, this is no good if we want to be able to use more than one of our provider with different parameters.

To get around these issues, we create a "parent" provided type within the type provider which will host an isolated namespace for each parametrized provider instance:

``` fsharp
let mavnnProvider = ProvidedTypeDefinition(asm, ns, "MavnnProvider", Some(typeof<obj>))
```

Then we define some 'static parameters' and call the ``DefineStaticParameters`` method on the parent provided type, still within the construction of the type provider:

``` fsharp
let parameters = [ProvidedStaticParameter("PathToJson", typeof<string>)]

do mavnnProvider.DefineStaticParameters(parameters, fun typeName args ->
    let pathToJson = args.[0] :?> string
    // ... do all our type creation logic in here ...
    )
```

... and then we amend the base TypeProvider type so that the only type it adds to the namespace is the ``mavnnProvider`` type:

``` fsharp
// was: do this.AddNamespace(ns, createTypes())
do this.AddNamespace(ns, [mavnnProvider])
```

At this point, we're creating an independent environment for each instance of the type provider. Unfortunately we need to make several changes to the type creation logic to make this work.

Firstly, we loaded quite a few things globally in the original version - things like the node list now need to happen within the context of `DefineStaticParameters`. You'll also notice that `DefineStaticParameters` gets given a `typeName` as one of the parameters on the callback. This is a compiler generated type name for this instance of the which is passed in when a parameterised provider is defined, and the callback method needs to return a provided type with that name.

So, for example:

``` fsharp
// In a script file called: Script.fsx
#r @"../../Mavnn.Blog.TypeProvider/Mavnn.Blog.TypeProvider/bin/Debug/Newtonsoft.Json.dll"
#r @"../../Mavnn.Blog.TypeProvider/Mavnn.Blog.TypeProvider/bin/Debug/Mavnn.Blog.TypeProvider.dll"

open System
open Mavnn.Blog.TypeProvider.Provided

type thisOne = MavnnProvider<"c:\Temp\Graph.json">
```

Will pass in ``"Script.thisOne" [| box "c:\Temp\Graph.json" |]`` to the callback method, and expect to get back a provided type. So the first thing we'll do in the callback is create the new type which we will then add all of our nodes to.

Keeping all of the amendments separate in your head just gets harder and harder at this point, so let's just few the final annotated method and get an overview of the final result. It's long, but hopefully worth it!

``` fsharp
do mavnnProvider.DefineStaticParameters(parameters, fun typeName args ->
    // All args arrive as type obj - you'll need to cast them back to what
    // you specified for actual usage
    let pathToJson = args.[0] :?> string

    // This is the type that is going to host all the other types
    // and get returned at the end of the method
    let provider = ProvidedTypeDefinition(asm, ns, typeName, Some typeof<obj>, HideObjectMethods = true)

    // ---------- set up ----------
    // This section contains all the methods that where previously global
    // to the module, but now need to be constrained to this instance of
    // the provider
    let nodes = JsonConvert.DeserializeObject<seq<Node>>(IO.File.ReadAllText(pathToJson))
                |> Seq.map (fun n -> n.Id.UniqueId.ToString(), n)
                |> Map.ofSeq

    let GetNode id =
        nodes.[id]

    let ports =
        nodes
        |> Map.toSeq
        |> Seq.map (fun (_, node) -> node.Ports)
        |> Seq.concat
        |> Seq.map (fun p -> p.Id.UniqueId.ToString(), p)
        |> Map.ofSeq

    let GetPort id =
        ports.[id]

    let addInputPort (inputs : ProvidedTypeDefinition) (port : Port) =
        let port = ProvidedProperty(
                        port.Id.Name, 
                        typeof<InputPort>, 
                        GetterCode = fun args -> 
                            let id = port.Id.UniqueId.ToString()
                            <@@ GetPort id |> InputPort @@>)
        inputs.AddMember(port)

    let addOutputPort (outputs : ProvidedTypeDefinition) (port : Port) =
        let port = ProvidedProperty(
                        port.Id.Name, 
                        typeof<OutputPort>, 
                        GetterCode = fun args -> 
                            let id = port.Id.UniqueId.ToString()
                            <@@ GetPort id |> OutputPort @@>)
        outputs.AddMember(port)

    let addPorts inputs outputs (portList : seq<Port>) =
        portList
        |> Seq.iter (fun port -> 
                        match port.Type with
                        | "input" -> addInputPort inputs port
                        | "output" -> addOutputPort outputs port
                        | _ -> failwithf "Unknown port type for port %s/%s" port.Id.Name (port.Id.UniqueId.ToString()))


    // ---------- end set up ----------

    let createNodeType id (node : Node) =
        let nodeType = ProvidedTypeDefinition(node.Id.Name, Some typeof<nodeInstance>)
        let ctor = ProvidedConstructor(
                    [
                        ProvidedParameter("Name", typeof<string>)
                        ProvidedParameter("UniqueId", typeof<Guid>)
                        ProvidedParameter("Config", typeof<string>)
                    ],
                    InvokeCode = fun [name;unique;config] -> <@@ NodeInstance.create (GetNode id) (%%name:string) (%%unique:Guid) (%%config:string) @@>)
        nodeType.AddMember(ctor)

        let addInputOutput () =
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
            [inputPorts;outputPorts]

        nodeType.AddMembersDelayed(addInputOutput)

        provider.AddMember(nodeType)

    // And this is where we actually interate through the loaded nodes,
    // using createNodeType to add each one to the parent provider type.
    let createTypes pathToJson =
        nodes |> Map.map createNodeType |> Map.toList |> List.iter (fun (k, v) -> v)
        
    createTypes pathToJson
    
    // And then we return our fully populated provider.
    provider)
```

Let's just check this all still works...

![Losing!](/images/tp-oh-no.png)

Ah. No. No, it doesn't.

This is where type provider development can get a bit more frustrating. The compiler allows the code above to compile - it's completely valid F# that looks like it should do the right thing. But now, our quotations are doing something different; and evaluating them at runtime fails.

Let's take a look at the constructor that's throwing the error:

``` fsharp
InvokeCode = fun [name;unique;config] -> <@@ NodeInstance.create (GetNode id) (%%name:string) (%%unique:Guid) (%%config:string) @@>)
```

Previously, ``GetNode`` was referring to a public method in the type provider assembly. But if you look above now, it's actually a private method with in the type provider class that we are closing over. But our generated type is in the assembly that's being created, not in the type provider assembly so *it can't access this method*. Even if it was in the same assembly, this method is actually private to the class, so we'd still be stuck. Bearing that in mind, let's try a
rewrite to see if we can get all of our quotations into better shape.

What are our options? Well, we can either capture all private state in types that the quotation evaluator knows about (``string``, mostly!). Or we can make sure that any methods called in the quotations are public.

The first gives us a cleaner interface for the outside world (the ``GetNode`` method should never really have been public in the first place), so let's give it a try.

In our first version of the type provider, we were using the ``GetNode`` method to avoid having to embed the ``Node`` in the constructor directly. But how would we go about putting the node in directly? We need something that creates an ``Expr<Node>``; but ``Node`` isn't a completely trivial type - it's members (``Id`` and ``Ports``) are made of more complex types themselves. Let's start with a simpler challenge, and see if we can make an ``Expr<Id>``.

We already know that:

``` fsharp
let embeddedId (identifier : Id) = <@ identifier @>
```

isn't going to work. The expression evaluator won't know what to do with the ``Id`` type. But ``Id``'s constructor is a public method, as is the ``Guid`` constructor. Let's try it:

``` fsharp
let private embeddedId (id : Id) =
    let guid = sprintf "%A" (id.UniqueId)
    let name = id.Name
    <@ Id(UniqueId = Guid(guid), Name = name) @>
```

Cool. It works, and even has the right signature. Looks like we might be getting somewhere. The ``Port`` type is nearly as straight forward:

``` fsharp
let private embeddedPort (port : Port) =
    let idExpr = embeddedId port.Id
    let type' = port.Type
    <@ Port(Id = %idExpr, Type = type') @>
```

We're using our embeddedId method to 'lift' the port's ``Id`` into an expression, and then splicing that expression into a call to create a new port.

We're on a roll! Just need to do the same for the ``Node`` type itself, with it's... ``List`` of ``Port``s. Ah.

There's probably a more elegant way of doing this, but given this is a functional first language, let's grab the first tool that springs to mind.

Recursion.

``` fsharp
let private embeddedNode (node : Node) =
    let idExpr = embeddedId node.Id
    let portsExpr adder = 
        <@
            let outPorts = Collections.Generic.List<Port>()
            (%adder) outPorts
            outPorts
        @>
    let adder =
        let portExprs =
            Seq.map (fun port -> embeddedPort port) (node.Ports)
            |> Seq.toList
        let rec builder expr remaining =
            match remaining with
            | h::t ->
                builder
                    <@ fun (ports : Collections.Generic.List<Port>) ->
                            (%expr) ports
                            ports.Add(%h) @>
                    t
            | [] ->
                expr
        builder
            <@ fun (ports : Collections.Generic.List<Port>) -> () @>
            portExprs
    <@ Node(Id = %idExpr, Ports = (%portsExpr adder)) @>
```

So, from the top down. ``portsExpr`` creates a quotation that takes an ``adder`` quotation (``Expr<List<Port>> -> unit``) and returns an ``Expr<List<Port>>``. This is what we're going to use in our ``Node`` construction quotation; but first we need the ``adder``; some kind of magic method that takes a List and adds each of the ports from the node that's being passed into ``embeddedNode``. I've built it as a recursive function; the 'zero' state that's passed in looks like this:

``` fsharp
<@ fun (ports : Collections.Generic.List<Port>) -> () @>
```

This is what will happen if the port list on the input node is empty. If it's not empty, we repeated build up nested calls to:

``` fsharp
<@ fun (ports : Collections.Generic.List<Port>) ->
        (%expr) ports
        ports.Add(%h) @>
```

Where ``h`` is the next port from the list. By the end of the process we have a chain of anonymous functions, each in turn closing over the quotation of a port from the input. Finally, we can splice that into the expression that actually creates our node.

Now we can use our new ``embeddedX`` expressions in our provided constructors and methods; for example, the constructor above becomes:

``` fsharp
let ctor = ProvidedConstructor(
            [
                ProvidedParameter("Name", typeof<string>)
                ProvidedParameter("UniqueId", typeof<Guid>)
                ProvidedParameter("Config", typeof<string>)
            ],
            InvokeCode =
                fun [name;unique;config] -> 
                    let nodeExpr = embeddedNode <| GetNode id
                    <@@ NodeInstance.create (%nodeExpr) (%%name:string) (%%unique:Guid) (%%config:string) @@>)
```

Can you see the difference? Now, rather than closing over the ``GetNode`` method, we're closing over the quotation of the node that it returns.

With a sense of deja vu, let's just check this all works...

![Winning!](/images/tp_quotations.png)

And somewhat surprisingly - it does.

If you want to see and play with the code, the version for this post can be found in [the FirstFloor branch of the project on GitHub](https://github.com/mavnn/Mavnn.Blog.TypeProvider/tree/FirstFloor).

As with the first post in the series, let me know your questions and comments.
