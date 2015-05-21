---
layout: post
title: "Serialization in .net"
date: 2015-05-21 16:11:28 +0100
comments: true
categories: [programming]
---
Leaving the confines of your own process's safe little memory space is always a potentially painful moment
when you're coding up an up. Whether it's receiving data from the outside world, passing a message over
RabbitMQ to an other in house service, or writing an audit trail that needs to be accessible for the next
20 years, there's a bunch of considerations that need to be taken into account when you hit the joys of
serialization and deserialization.

<!-- more -->

## Mirror, mirror on the wall

First up on the list is whether or not to use reflection. For those of you who aren't aware, reflection
is a way of inspecting the properties of your .net code at runtime, and various serialization libraries
take advantage of this to try and make your life easier.

The best known example of this is [Json.NET](http://www.newtonsoft.com/json) - which will take any .net
object and try and create a Json representation of it - or vice versa.

``` csharp
Product product = new Product();
product.Name = "Apple";
product.Expiry = new DateTime(2008, 12, 28);
product.Sizes = new string[] { "Small" };

string json = JsonConvert.SerializeObject(product);
// {
//   "Name": "Apple",
//   "Expiry": "2008-12-28T00:00:00",
//   "Sizes": [
//     "Small"
//   ]
// }
```

This is a common technique, but it does have a few problems.

### Versioning

The "schema" here is actually the underlying .net type that you are serializing - this can be great for
quick to implement communications between .net services which can share a "messages" dll with the type in.

Unfortunately, this also plays merry havoc in any scenario where your messages might persist
between versions of your messaging dll. Saving these objects to a document store for example, or trying to run two versions of a service at once (required for seamless deployment)
connected to a messaging bus.

Because .net will only allow you to have one version of an assembly loaded at once, you can't
easily build a way of deserializing the old format.

### Uglyness

This might sound like a purely aesthetic consideration, and therefore beneath us
technical types but the result of automatic serialization is often ugly and strange
looking. And to be fair, it isn't normally a huge problem for as long as you're working
in a .net to .net scenario. But if, for example, you're writing an API to be consumed
from JavaScript your UI developers (which is probably still you, right?) will curse your
name forever more if you go this route. As well as this, as there's no schema, it's very
hard to tell in any other language whether the object you've created will make it through
the deserialization process when it hits .net land again.

### Runtime failure

That ``JsonConvert.SerializeObject`` method up there: it's generic. Which means it will
take any .net object you want to throw at it.

Unfortunately, the number of .net objects it can actually serialize is quite a bit more
restricted than "any .net object you want to throw at it". And it has no way of telling
you that until run time, when it will just throw an exception, which can be pretty painful.

### When to use?

Only use reflection based serialization in situations where you know the serialized
representation will be transient, and where you can test your serialization works at
runtime in advance. Additional, be very suspicious of using reflection based serialization
in any scenario where anything outside the .net ecosystem will need to access the data.

Typical scenarios:

* Caching
* Inter-process communication in distributed systems
* Message bus communications (only if you can guarantee the messages are transient)

Avoid for:

* Permanent persistence
* Defining APIs to be used from outside .net

### Recommended implementation

If you are doing reflection based serialization in .net, you want to use
[FsPickler](https://nessos.github.io/FsPickler/). It covers binary, json, bson and xml
serialization in a single library, is faster than Json.NET and successfully serializes
more types than Json.NET. What's not to like?

## Attribute all the things!

As well as just trying to guess how to serialize things with reflection in .net,
there is also the [Serializable](https://msdn.microsoft.com/en-us/library/system.serializableattribute%28v=vs.110%29.aspx) attribute that allows you to then serialize to a variety
of formats using the ``System.Runtime.Serialization`` name space. This a few advantages
over the raw reflection technique in theory (you can mark specific fields not to be serialized, for example) but to be blunt if you're going to go to this amount of effort you may
as well go for one of the safer options below.

### When to use?

When you're using a Microsoft library that requires you to.

## Safety with (type) class

If you happen to be working in F#, then [member constraints](https://msdn.microsoft.com/en-us/library/dd233203.aspx) allow you to try a more flexible and type safe way of expressing
serialization - in exchange for a little more work.

As an example, the Chiron library allows you to do things like this:

``` fsharp
open Chiron
open Chiron.Operators

type InnerRecord =
    {
        Start : System.DateTime
        Id : System.Guid
    }
    static member FromJson (_ : InnerRecord) =
        (fun s i -> { Start = s; Id = i })
        <!> Json.read "startTime"
        <*> Json.read "identity"
    static member ToJson innerRecord =
        Json.write "startTime" innerRecord.Start
        *> Json.write "identity" innerRecord.Id

type OuterRecord =
    {
        Name : string
        Inner : InnerRecord
    }
    static member FromJson (_ : OuterRecord) =
        (fun n i -> { Name = n; Inner = i })
        <!> Json.read "name"
        <*> Json.read "inner"
    static member ToJson outerRecord =
        Json.write "name" outerRecord.Name
        *> Json.write "inner" outerRecord.Inner

{
  Name = "my object"
  Inner = {
            Start = System.DateTime(2015, 5, 21)
            Id = System.Guid.NewGuid()
          }
}
|> Json.serialize
|> Json.format
// Your json goes here
```

A few interesting things to note here. Firstly, as you've probably guessed, the magic
of telling Chiron how to serialize and deserialize things happens in the ``ToJson`` and
``FromJson`` methods. What might not be so obvious is that if these methods are not
implemented with the correct signature, than ``Json.serialize`` will not compile when
fed the erroneous object. Which does wonders for eliminating run time errors!

Also, if you look carefully at the To and From methods you'll see that there's no need
for the fields in the Json and the .net object to have the same name. In fact, you can
apply what ever logic you want within them, allowing you to match a specific schema,
allow for different versions of the serialized data to be deserialized or just generally
make the serialized version prettier to use from other places.

You do, of course, have to actually write the From and To methods, which is definitely
more work. Having said that, it's not quite as bad as it sounds though: as you can see
from the ``OuterRecord`` type with it's ``InnerRecord`` field, and can nest the To and
From methods nicely - and the type system will check that your object is serializable
all the way down. Nice.

### When to use?

Any time when you might have to persist data between versions, or process data during
the serialization/deserialization process - and you can specify your data types in F#.

### Recommended implementation

[Fleece](https://github.com/mausch/Fleece) and [Chiron](https://github.com/xyncro/chiron/)
both implement these techniques. Fleece is a more established library that has been tested
for longer, but I have had some performance issues with it in libraries with a lot of types
that implement To and From methods. Chiron is a little bit... cutting edge in age, but
has always been fast and reliable for me so far.

We currently use Fleece in one of our projects, and have provided some support to improving
the testing of Chiron as it looks like a hopeful alternative.

Edit: Eirik points out in the comments that FsPickler (mentioned above) also has a mechanism
for defining type safe (de)serialization [using Picklers](http://nessos.github.io/FsPickler/tutorial.html#Picklers-and-Pickler-combinators). I couldn't possibly guess where the library
got it's name.

## All the rest

I'm sure that there are other ways of tackling these problems - for example, for our
customer facing "business" APIs we're moving to specifying our API using hand crafted
XSD and WSDL files and then autogenerating code behind. This assumes, of course, you
have some reason to be using SOAP. But if you do, it works an awful lot better than
trying to autogenerate the schema from the code - a path that's lead me to worlds of
pain both as the consumer and producer of the schemas.

But the routes above are the most common paths that I've come across as a .net developer
and I've often discovered them being used in the "wrong" places. Retroactively having to
version reflection based APIs is a particular pain point that I'd recommend avoiding if
you possibly can!
