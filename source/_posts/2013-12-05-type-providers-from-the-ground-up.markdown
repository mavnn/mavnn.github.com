---
layout: post
title: "Type Providers from the Ground Up"
date: 2013-12-05 11:28
comments: true
categories: [fsharp, programming]
---
In the ground tradition of blog posts as both documentation and augmented memory, I've just added our first [Type Provider](http://blogs.msdn.com/b/dsyme/archive/2013/01/30/twelve-type-providers-in-pictures.aspx) to the code base. Time to write up the details before a) I forget them and b) anyone else needs to modify the code.

So, first things first. Before we get to the actual problem space at hand, let's try and provide a type. Any type...

1) Create yourself a new Visual Studio F# library project (2012 or up should work).

2a) Install the [F# TypeProvider Starter Pack](https://www.nuget.org/packages/FSharp.TypeProviders.StarterPack/) or

2b) add [ProvidedTypes.fs](https://raw.github.com/fsharp/FSharp.Data/master/src/CommonProviderImplementation/ProvidedTypes.fs) and [ProvidedTypes.fsi](https://raw.github.com/fsharp/FSharp.Data/master/src/CommonProviderImplementation/ProvidedTypes.fsi) to the project as the first couple of files.

In either case, make sure that the .fsi file appears before the .fs file in your project listing, and that both appear before any type provider code - you will probably have to manually re-order them.

These are provided as code files rather than as compiled dlls due to complications with security and AppDomains when referencing dlls in the type provider assembly. For now just add them in - you really don't want to be re-creating the code in there by hand.

3) Replace the contents of Library1.fs with something like this:

{% gist 7803991 Part1.fs %}

So, that's great and it builds. We have a type provider class and an assembly that knows it's a type providing assembly. Unfortunately, it doesn't actually provide any types yet. Let's try it.

<!--more-->

Update Library1.fs in your solution with something that looks like this, and then we'll run through what's going on, and how to test it.

{% gist 7803991 Part2.fs %}

First things first - it looks like it should provide a class with a static property, but how do we test it?

It turns out it's harder than it looks. If you reference your brand new type provider in Visual Studio, that instance of Visual Studio will promptly lock the dll file. Which means you can't recompile it. So referencing the dll from within the instance of Visual Studio you're using to develop it is a no go.

Fire up a second copy of Visual Studio (you went for the extra RAM option on your hardware, yes?) and create an F# project in it. Add an fsx file that looks something like this:

{% gist 7803991 Part3.fsx %}

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

```
let addI i =
    <@@ 1 + (%%i) @@>
```

This gives a function of `Expr -> Expr`, and now we can do things like `let add2 = addI <@@ 2 @@>` (gives `val add2 : Expr = Call (None, op_Addition, [Value (1), Value (2)])`) or `let add2MultipliedByX x = addI <@@ 2 * x @@>` (gives `val add2MultipliedByX : x:int -> Expr`) and what we get back is effectively the AST of the first F# expression with the second spliced in to evaluate as you will. So in our `GetterCode` above, we are actually providing the AST that will be compiled into the `get_MyPropertyMethod` of the type when it is created.

The second thing that you need to know about quotations for current purposes is that the thing evaluating them may or may not be able to handle the F# expression you've created. Which again we'll get back to in a moment!

So far, our type isn't very exciting. You can't even construct an instance of it. Let's see what we can do about that, with a replacement `createTypes` method:

{% gist 7803991 Part4.fs %}

Now we can construct our type (in two ways, no less). As the underlying CLR type is an `object` we can store pretty much anything as the internal representation of an instance of our type. The `InvokeCode` parameter of the constructors needs to return a quotation that will return the internal representation of the object when it's evaluated. We're going to return a string (which we need to cast to an obj), and using the splicing syntax above we can inject the parameters of the constructor into the quotation (for the constructor which has a parameter).

Similarly, we also add a property (notice that we're not setting it to be a static property this time). Because this property is not static, the first item in the `args` Array is the instance of the type itself (similar to the way that you define an extension method). So we can splice that into our method quotation (remembering to cast it from `obj` to `string`) and expose the underlying state of the object for all the world to see.

And now you can do things like this:

{% gist 7803991 Part5.fsx %}

## And the point is?

Well - this is great, except the perceptive among you will have noticed that we're just generating a static type here. We could have just declared it using normal syntax.

So let's try going a step further. Let's say that we have some Json definitions of graph nodes types, each with a defined set of input and output "ports". All of these graph bits are given to us as a Json array, and each Node type and port has a Guid identifier and a friendly name.

Our input JSON looks something like this:

{% gist 7803991 Part6.json %}

Things start getting a bit more in depth here, so you might want to check out the full code for this post, available on [GitHub](https://github.com/mavnn/Mavnn.Blog.TypeProvider), and follow along in your favourite development environment.

We'll let someone else deal with the parsing - add a Nuget reference to `Newtonsoft.Json` to your type provider, and let's have a third reprise of `createTypes`.

First, we'll need some classes to deserialize the Json into. Out of the box Newtonsoft doesn't do a great job on F# core classes (although that's changing), so for the moment we'll create some classic OO style mutable types:

{% gist 7803991 Part7.fs %}

(Don't worry though, these aren't what we'll actually expose as the main interface.)

Turning our Json into the our new CLR types is straight forward:

{% gist 7803991 Part8.fs %}

Now the interesting part. To build a graph out of these nodes, we need to be able to do a few things.

Firstly, we need to be able to build a specific instance of a node type: which `Split` node is this? 

Let's help ourselves out by having a concrete type as an the underlying type for our instances:

{% gist 7803991 Part9.fs %}

And then constructing a more specific type with a constructor for each node type we've read from the Json:

{% gist 7803991 Part10.fs %}

So now we can construct (look back at the json) a `Simple` node instance by using `let simple = Simple("simpleInstance", Guid.NewGuid(),"MyConfig")`. And it already has our `InstanceId`, `Config` and `Node` properties from the underlying type.

Good progress - but we don't have a nice way of representing the inputs and outputs? We want to be able to write some kind of connection builder function afterwards that won't allow you to connect to outputs to each other, or similar silliness, so we're going to need separate types for inputs and outputs.

{% gist 7803991 Part11.fs %}

And finally, we'll update our node creation function to add two subtypes to each node type called `Inputs` and `Outputs`, and then create properties on those objects to represent each port. Our full type creation for a node now looks something like this:

{% gist 7803991 Part12.fs %}

Leaving only one final mystery. What are the `GetPort` and `GetNode` methods - and why am I using them in the quotations rather than just using something like `<@@ node @@>`?

Well, if you remember I mentioned earlier that the evaluation of a quotation is limited by the implementation of the evaluator used. The type provider files you included right at the beginning contain an evaluator that turn a quotation into IL instructions - but, it doesn't include support for literals of custom types. In fact, if you check in [the relevant part of ProvidedTypes.fs](https://github.com/fsharp/FSharp.Data/blob/master/src/CommonProviderImplementation/ProvidedTypes.fs#L1876) you'll see that it's actually quite prescriptive.

So, what we do is we build a couple of private helper methods that know how to find the correct port or node from one of the types that is allowed - in this case, a `string`:

{% gist 7803991 Part13.fs %}

So, there you have it. A complete, working type provider that uses meta data supplied in Json format to create CLR types. Lots of things still to be added for production ready code (delayed loading, handling multiple ports with the same names, not hard coding the filename, etc).

![Winning...](/images/typeprovider.png)


Any questions or corrections, fire away. As mentioned, this is very much the first time I've used type providers - but even this level of usage is providing a goodly amount of value for us.
