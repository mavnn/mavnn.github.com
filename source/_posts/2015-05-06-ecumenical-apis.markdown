---
layout: post
title: "Ecumenical APIs"
date: 2015-05-06 10:44:16 +0100
comments: true
categories: [programming,fsharp,csharp]
---

One of the big sells of shared runtime functional languages such as F#, Scala
and Clojure is that you can carrying on using the surrounding library ecosystem
and your existing code. The different paradigm occasionally causes a little
pain, but there are plenty of blog posts about how to wrap OO interfaces in a
functionally friendly way.

This is not one of those blog posts. This is about making sure that your
colleages who are consuming your shiny new code in an imperative language
(generally C# in my case) don't threaten to defenistrate you.

At [15below](http://15below.com) we've recently had need in some of our services
of taking a distributed lock between servers. There are many services available
designed for doing this, but after some deliberation we decided that we didn't
want to add a new piece of infrastructure purely for this one purpose. So
[Sproc.Lock](http://15below.github.io/Sproc.Lock) was born: SQL Server based
distributed locking.

In this post, I'm not going to talk about the design of the service. What I'm
going to write about is how I engineered the API to be pleasent to use from both
C# and F#, giving a idiomatic interface from both languages.

<!-- more -->

## The original interface (F#)

The F# interface was written first, and follows a pattern that will feel
immediately familiar to an F# programmer. Our lock can be of 3 types (global,
organisation or environment) and so we have a discriminated union (``Lock``)
representing these three options.

(I've removed the implementations of the various bits to leave the shape of the
code clear)

``` fsharp
/// Type representing a Lock that has definitely been acquired. Locks are
/// IDisposable; disposing the lock will ensure it is released.
type Lock =
     /// A lock that applies globally across the lock server
     | Global of ...
     /// A lock scoped to a specific organisation
     | Organisation of ...
     /// A lock scoped to a particular environment belonging to a particular organisation
     | Environment of ...
     /// The LockId acquired. Useful in combination when getting one of a list of locks to determine which was free.
     member lock.LockId =
         ...
     /// Disposing releases the lock
     member lock.Dispose () =
         ...
     interface IDisposable with
         /// Disposing releases the lock
         member lock.Dispose () =
            lock.Dispose()
```

The lock is ``IDisposable`` to take advantage of .net's most common resource
management idiom. You can release a lock by disposing it.

Then, of course, when we try and acquire a lock we may or may not be able to -
the whole point of locks is that you cannot obtain them if someone else has
locked it already, after all.

So we have a second discriminated union (``LockResult``) wrapping the first,
with (again) three potential cases:

``` fsharp
/// A type representing the possible results of attempting to acquire a lock.
type LockResult =
     /// A lock was successfully acquired
     | Locked of Lock
     /// No lock was available
     | Unavailable
     /// The attempt to acquire a lock caused an error in SQL Server
     | Error of int
     /// Disposing a lock result disposes the lock if it was acquired, and has no effect otherwise
     member x.Dispose () =
        match x with
        | Locked l -> l.Dispose()
        | Unavailable -> ()
        | Error _ -> ()
     interface IDisposable with
        member x.Dispose () =
            x.Dispose()
```

Again, this is ``IDisposable`` so that you can just dispose of your overall
``LockResult`` object which makes a lot of the code cleaner.

So: how do we get a ``LockResult``? Well, we have a set of functions for getting
locks. Let's have a look at the skeleton of one of them:

``` fsharp
// val GetOrganisationLock : string -> string -> TimeSpan -> string -> LockResult
let GetOrganisationLock connString organisation (maxDuration : TimeSpan) lockIdentifier =
    ...
```

What's this doing? Well, it's going to (try and) create a lock scoped to a
particular database and organisation with a particular ID, returning a
``LockResult``. 

From an API design point of view, what's interesting here is the order of the
arguments. [Currying](https://en.wikipedia.org/wiki/Currying) enables easy
partial application, and here it is very likely that the application will want
to take all locks from the same database (making the first parameter) and
reasonably likely that it will always want them scoped to the same organisation
(second parameter). This is a common pattern in languages that allow for easy
currying, and invariably a consumer of this library in F# will end up with a
partially applied helper function looking something like this:

``` fsharp
// val getLock : string -> LockResult
let getLock =
    GetOrganisationLock "myDbConnString" "OrgName" (TimeSpan.FromMinutes 5.)
```

We also have a set of helper functions for common operations we might want to
carry out on locks, all of which take a higher order function as part of their
arguments. Let's have a look at ``AwaitLock`` which will wait for a lock to
become available for a specified length of time, rather then returning
immediately with an ``Unavailable`` result:

``` fsharp
// val AwaitLock : TimeSpan -> (unit -> LockResult) -> LockResult
let AwaitLock (timeOut : TimeSpan) getLock =
    ...

// Using it using the helper above:
let awaitMyLock identifier =
    AwaitLock (TimeSpan.FromSeconds 2.) (getLock identifier)
```

If we then want (say) to wait up to 2 seconds for one of a list of possible
locks to become available, we can then compose this function with the
``OneOfLocks`` function:

``` fsharp
// val OneOfLocks : ('a -> LockResult) -> seq<'a> -> LockResult
let OneOfLocks getLock lockIds =
    ...

// Using it using await helper:
let pickLock () =
    OneOfLocks awaitMyLock ["LockId1";"LockId2"] 
```

I'm sure the comments will disagree, but I'm actually pretty happy with this as
an F# interface to this library. It's not strictly pure, but that's an option in
F#, and the combination of composable functions and careful choice of parameter
order make for concise and readable code.

So, we're done - right?

Unfortunately not. This code would be truely horrible to use from C#, and we
still use a lot of C# here - some of our (stranger?) developers even prefer
it. Why would it be so nasty?

* Consuming discriminated unions from C# is verbose to the point of unusable
* Partial application is a pain in C#, and no one wants to repeat the connection
string everytime they want a lock
* Function composition is possible in C# but is not idiomatic and may make the
  capabilities of the library unclear

## API Take 2: the "OO" namespace

In thinking about the kind of API I would expect for a locking library in C#, a
few things immediately sprang to mind:

* I would expect some kind of configurable provider object or factory
* Out of flow returns are normally signalled by exceptions
* Function composition only for more unusual calling options

Wrapping the functional API turned out to be reasonably simple. A couple of
custom exception types and the ``OOise`` method later (I love that function
name, even if I say so myself) we can easily wrap our functional API in
something that makes sense in C# land - they either return an acquired,
``IDisposable`` lock or throw.

``` fsharp
/// Exception thrown by ``LockProvider`` if none of the specified locks are available.
type LockUnavailableException (message) =
    inherit System.Exception(message)

/// Exception thrown by ``LockProvider`` if a lock request errors on SQL Server.
/// ``LockErrorCode`` is the SQL error response.
type LockRequestErrorException (errorCode) as this =
    inherit System.Exception(sprintf "Error code: %d" errorCode)
    do
        this.Data.Add(box "ErrorCode", box errorCode)
    member x.LockErrorCode
        with get () =
            x.Data.["ErrorCode"] |> unbox<int>

let private OOise lockId getLock =
    match getLock lockId with
    | Locked l -> l
    | Unavailable -> raise <| LockUnavailableException(sprintf "Lock %s was unavailable." lockId)
    | Error i -> raise <| LockRequestErrorException i
```

Then, a simple ``LockProvider`` class allows for all the normal patterns we've
come to know (and in some cases love) such as dependency injection:

``` fsharp
type LockProvider (connString : string) =
    member x.GlobalLock (lockId, maxDuration) =
        GetGlobalLock connString maxDuration |> OOise lockId
    member x.OrganisationLock (lockId, organisation, maxDuration) =
        // Rest of the implementations snipped
        ...
    member x.EnvironmentLock (lockId, organisation, environment, maxDuration) =
        ...
    member x.AwaitGlobalLock (lockId, maxDuration, timeOut) =
        ...
    member x.AwaitOrganisationLock (lockId, organisation, maxDuration, timeOut) =
        ...
    member x.AwaitEnvironmentLock (lockId, organisation, environment, maxDuration, timeOut) =
        ...
    /// Build a ``System.Func`` that returns a lock based on lockId and provide a list of lockIds.
    /// If any of the locks are available, it will pick one of the available locks at random.
    member x.OneOf<'t> (getLock : System.Func<'t, Lock>, lockIds) =
        ...
    /// Build a ``System.Func`` that returns a lock based on lockId and provide a list of lockIds.
    /// If any of the locks are available, it will pick one of the available locks at random.
    /// If none are available it will wait until one is, or ``timeOut`` has passed.
    member x.AwaitOneOf<'t> (getLock : System.Func<'t, Lock>, lockIds, timeOut) =
        ...
```

As you can see, by the time we get to the ``OneOf`` members, we're pretty much
forced into taking higher order functions to avoid a combinatorial explosion of
members (not that that always seems to deter OO API designers...). Other than
that, I think we're left with an API which will immediately make sense to a C#
developer: you can new up a ``LockProvider``, you have a specified list of
exception types to expect, and you can easily intellisense your way around all
of the available options.

Our C# consuming code ends up looking a bit like this:

``` csharp
using System;
using Sproc.Lock.OO;


namespace MyApp
{
    class Thing
    {
        static void DoLockRequiringWork()
        {
            var provider = new LockProvider("sql connection string");
            try
            {
                using (var lock2 = provider.GlobalLock("MyAppLock", TimeSpan.FromMinutes(5.0)))
                {
                    // If I get here, I have a lock!
                    // Doing stuff!
                } // Lock released when Disposed
            }
            catch (LockUnavailableException)
            {
                // Could not get the lock
                throw;
            }
            catch (LockRequestErrorException)
            {
                // Getting the lock threw an error
                throw;
            }
        }
    }
}
```

Note the very different parameter order, placing the parameters that change most
frequently at the beginning of the list as you would normally expect in C#. This
makes a surprisingly large difference to how easy the code is to consume.

Again: quite nice, if I do say so myself.

So there you have it - want to take play nicely the whole .net ecosystem? Be
kind to your consumers, and build them an ecumenical API!
