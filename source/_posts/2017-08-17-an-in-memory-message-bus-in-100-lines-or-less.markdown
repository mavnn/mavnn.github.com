---
layout: post
title: "An In Memory Message Bus in 100 Lines or Less"
date: 2017-08-17 15:15:43 +0100
comments: true
categories: [fsharp, easynetq]
---
In reimplementing an [EasyNetQ process manager](/process-management-in-easynetq/) one of the things I wanted to keep from the original project was an in memory message bus that could be used for testing without requiring a running RabbitMQ server. The code has ended up being pleasingly short and also uses a few techniques that seemed interesting, so I thought I'd document it here as part of the design process.

Please note we're not going for a full re-implementation of RabbitMQ in memory here, but this does give us enough to do some useful testing!

<!-- more -->

> Author's note: since this post was written, this code was updated to be async. I've added the new version as appendix 2

## What are we building?

In the main process manager library, I'm starting to hash out the underlying types which will drive the various abstractions in play. As a consumer of the library, you'll probably never have cause to use these types directly.

One of these is an interface class representing a message bus which routes on a combination of [topic](https://github.com/EasyNetQ/EasyNetQ/wiki/Topic-Based-Routing) and .net type (i.e. how EasyNetQ routes by default). It looks like this:

``` fsharp
type Topic = Topic of string

type ProcessManagerBus =
    inherit IDisposable

    abstract member Publish<'a when 'a : not struct> :
        'a -> TimeSpan -> unit
    abstract member TopicPublish<'a when 'a : not struct> :
        'a -> Topic -> TimeSpan -> unit
    abstract member Subscribe<'a when 'a : not struct> :
        SubscriptionId -> ('a -> unit) -> unit
    abstract member TopicSubscribe<'a when 'a : not struct> :
        SubscriptionId -> Topic -> ('a -> unit) -> unit
```

Production code will wrap an instance of an EasyNetQ `IBus` here, but for testing we're going to build an in memory version.

## Underlying concepts

What concepts are we going to have in play here? Well, there's going to be subscribers, who should have an action called when a relevant message is published. And we're going to want to be able to actually publish the messages.

It makes sense to model the message bus as an agent which can have commands sent to it (a `MailboxProcessor` in F# terms), so let's model the commands we want to be able to send first:

``` fsharp
module EasyNetQ.ProcessManager.MemoryBus

open System
open EasyNetQ.ProcessManager.Types

type private Subscriber =
    abstract Action : obj -> unit
    abstract Type : Type
    abstract Binding : string

type private Subscriber<'a> =
    { SubscriptionId : SubscriptionId
      Binding : string
      Action : 'a -> unit }
    interface Subscriber with
        member x.Action o =
            o |> unbox<'a> |> x.Action
        member __.Type =
            typeof<'a>
        member x.Binding =
            x.Binding

type private BusMessage =
    | Publish of obj * Type * DateTime * Topic option
    | Subscribe of Subscriber
    | Stop of AsyncReplyChannel<unit>
```

So, a subscriber knows what topic it is binding to (which might include wildcards, we'll get there in a moment), which `type` it is listening for, and an action to call when that type arrives. The agent will need to store a list of subscribers, so we wrap our generic `Subscriber<'a>` type in a non-generic interface (`Subscriber`).

The `BusMessage` type then reflects the three things that we might ask the agent to do: publish a message to current subscribers, add a subscriber, or shut down and reply when shutting down is complete.

## Add the logic

We'll also need some logic for determining whether a topic published to match a topic which has been bound to by a subscriber. Topics in RabbitMQ are multipart strings with `.` separators - "one.two.three", and messages must be published to a specific topic. But when you bind a subscriber, you can bind with two types of wildcard. A `*` matches a "section" (so binding to "*.two" will receive messages published to "one.two" and "1.two"), while a `#` finishes a binding string and matches any number of sections (so binding to "one.#" will match "one.two", "one.2" and "one.two.three").

Our logic ends up looking like this:

``` fsharp
let private compareSection (topicSection : string, bindingSection : string) =
    match bindingSection with
    | "#" | "*" -> true
    | _ when bindingSection = topicSection -> true
    | _ -> false

let private topicBindingMatch topicOpt (binding : string) =
    match topicOpt with
    | Some (Topic topic) ->
        let topicSections = topic.Split '.'
        let bindingSections = binding.Split '.'
        if bindingSections.[bindingSections.Length - 1] = "#" then
            // Seq.zip truncates the longer sequence of the two
            // provided - so here we ignore any sections beyond
            // the "#"
            Seq.zip topicSections bindingSections
            |> Seq.forall compareSection
        else
            // If there's no "#" at the end of the binding, there
            // can only be a match if there is exactly the same number
            // of sections; check that before zipping the sections
            // together to compare
            if bindingSections.Length = topicSections.Length then
                Seq.zip topicSections bindingSections
                |> Seq.forall compareSection
            else
                false
    | None ->
        // If there is no publish topic, the only binding which can match
        // is "#" as there are no sections to compare.
        binding = "#"
```

## Build the agent

We now have all of the logic our agent requires. Let's put into together into an `Async` recursive function listening for commands.

``` fsharp
let rec private loop subscribers (agent : MailboxProcessor<BusMessage>) =
    async {
        let! msg = agent.Receive()
        match msg with
        | Stop chan ->
            chan.Reply ()
            return ()
        | Subscribe s ->
            return! loop (s::subscribers) agent
        | Publish (message, type', expireTime, topic) ->
            if expireTime > DateTime.UtcNow then
                subscribers
                |> List.filter (fun x -> type' = x.Type
                                           && topicBindingMatch topic x.Binding)
                |> List.iter (fun x -> x.Action message)
            return! loop subscribers agent
    }
```

With the correct types to guide us, this function ends up almost trivial. If we receive a stop message, we reply to say we're stopped and then return `unit`, meaning we'll process no further messages.

If we receive a subscriber, we just add it to the list of subscribers and call back into the loop.

And finally, if there's a request to publish we check the message hasn't expired and then call of the subscribers that have the correct type and a matching binding (before calling back into the loop).

## Wrap it all in the correct interface

Now we just need a type which implements the `ProcessManagerBus` interface and we're done. We want `Dispose` to stop the underlying agent, and the other methods are straight forward translations. The only real thing of note here is the line `do agent.Error.Add raise`. This is needed because by default exceptions thrown in `MailboxProcessor`s kill the background thread the agent loop is running on, but are not propagated up to the overall process. That's not the behaviour we want here: if a subscriber throws, we want to know about the error.

``` fsharp
type MemoryBus () =
    let agent = MailboxProcessor.Start(loop [])
    do agent.Error.Add raise
    interface IDisposable with
        member __.Dispose() =
            agent.PostAndReply Stop
    interface ProcessManagerBus with
        member __.Publish (message : 'a) expiry =
            agent.Post (Publish (box message, typeof<'a>, DateTime.UtcNow + expiry, None))
        member __.TopicPublish (message : 'a) topic expiry =
            agent.Post (Publish (box message, typeof<'a>, DateTime.UtcNow + expiry, Some topic))
        member __.Subscribe sid action =
            agent.Post (Subscribe { SubscriptionId = sid; Binding = "#"; Action = action })
        member __.TopicSubscribe sid (Topic binding) action =
            agent.Post (Subscribe { SubscriptionId = sid; Binding = binding; Action = action })
```

## Fin

And there you have it! An in memory message bus in 100 lines or less of F# code. For bonus points, here's a simple set of test cases for it so you can see what it looks like in action.

``` fsharp
module EasyNetQ.ProcessManager.Tests.MemoryBus

open System
open EasyNetQ.ProcessManager.Types
open EasyNetQ.ProcessManager.MemoryBus
open Expecto

type T1 = T1 of string
type T2 = T2 of string

[<Tests>]
let memoryBusTests =
    testList "memory bus tests" [
        testCase "Basic send/subscibe works" <| fun _ ->
            let receivedMessage = ref None
            let bus = new MemoryBus() :> ProcessManagerBus
            let subId = SubscriptionId "t1"
            bus.Subscribe<T1> subId (fun (T1 m) -> receivedMessage := Some m)
            bus.Publish (T1 "message") (TimeSpan.FromMinutes 1.)
            bus.Dispose()
            Expect.equal (!receivedMessage) (Some "message") "Should match"

        testCase "Subscribe filters correctly by type" <| fun _ ->
            let receivedMessage = ref None
            let bus = new MemoryBus() :> ProcessManagerBus
            let subId = SubscriptionId "t1"
            bus.Subscribe<T2> subId (fun (T2 m) -> receivedMessage := Some m)
            bus.Publish (T1 "message") (TimeSpan.FromMinutes 1.)
            bus.Dispose()
            Expect.equal (!receivedMessage) None "Should match"

        testCase "Can publish to topic" <| fun _ ->
            let receivedMessage = ref None
            let bus = new MemoryBus() :> ProcessManagerBus
            let subId = SubscriptionId "t1"
            bus.TopicSubscribe<T1> subId (Topic "one.two") (fun (T1 m) -> receivedMessage := Some m)
            bus.TopicPublish (T1 "message") (Topic "one.two") (TimeSpan.FromMinutes 1.)
            bus.Dispose()
            Expect.equal (!receivedMessage) (Some "message") "Should match"

        testCase "Only receives from matching topic" <| fun _ ->
            let receivedMessage = ref None
            let bus = new MemoryBus() :> ProcessManagerBus
            let subId = SubscriptionId "t1"
            bus.TopicSubscribe<T1> subId (Topic "one.two") (fun (T1 m) -> receivedMessage := Some m)
            bus.TopicPublish (T1 "message") (Topic "two.one") (TimeSpan.FromMinutes 1.)
            bus.Dispose()
            Expect.equal (!receivedMessage) None "Should match"

        testCase "Matching wildcard topic is matched" <| fun _ ->
            let receivedMessage = ref None
            let bus = new MemoryBus() :> ProcessManagerBus
            let subId = SubscriptionId "t1"
            bus.TopicSubscribe<T1> subId (Topic "*.two") (fun (T1 m) -> receivedMessage := Some m)
            bus.TopicPublish (T1 "message") (Topic "one.two") (TimeSpan.FromMinutes 1.)
            bus.Dispose()
            Expect.equal (!receivedMessage) (Some "message") "Should match"
    ]
```

## Appendix 1

Just to round everything off, here's a listing of the complete implementation from beginning to end.

File 1:

``` fsharp
module EasyNetQ.ProcessManager.Types

open System

type SubscriptionId = SubscriptionId of string
type Topic = Topic of string

type ProcessManagerBus =
    inherit IDisposable

    abstract member Publish<'a when 'a : not struct> :
        'a -> TimeSpan -> unit
    abstract member TopicPublish<'a when 'a : not struct> :
        'a -> Topic -> TimeSpan -> unit
    abstract member Subscribe<'a when 'a : not struct> :
        SubscriptionId -> ('a -> unit) -> unit
    abstract member TopicSubscribe<'a when 'a : not struct> :
        SubscriptionId -> Topic -> ('a -> unit) -> unit
```

File 2:

``` fsharp
module EasyNetQ.ProcessManager.MemoryBus

open System
open EasyNetQ.ProcessManager.Types

type private Subscriber =
    abstract Action : obj -> unit
    abstract Type : Type
    abstract Binding : string

type private Subscriber<'a> =
    { SubscriptionId : SubscriptionId
      Binding : string
      Action : 'a -> unit }
    interface Subscriber with
        member x.Action o =
            o |> unbox<'a> |> x.Action
        member __.Type =
            typeof<'a>
        member x.Binding =
            x.Binding

type private BusMessage =
    | Publish of obj * Type * DateTime * Topic option
    | Subscribe of Subscriber
    | Stop of AsyncReplyChannel<unit>

let private compareSection (topicSection : string, bindingSection : string) =
    match bindingSection with
    | "#" | "*" -> true
    | _ when bindingSection = topicSection -> true
    | _ -> false

let private topicBindingMatch topicOpt (binding : string) =
    match topicOpt with
    | Some (Topic topic) ->
        let topicSections = topic.Split '.'
        let bindingSections = binding.Split '.'
        if bindingSections.[bindingSections.Length - 1] = "#" then
            Seq.zip topicSections bindingSections
            |> Seq.forall compareSection
        else
            if bindingSections.Length = topicSections.Length then
                Seq.zip topicSections bindingSections
                |> Seq.forall compareSection
            else
                false
    | None ->
        binding = "#"

let rec private loop subscribers (agent : MailboxProcessor<BusMessage>) =
    async {
        let! msg = agent.Receive()
        match msg with
        | Stop chan ->
            chan.Reply ()
            return ()
        | Subscribe s ->
            return! loop (s::subscribers) agent
        | Publish (message, type', expireTime, topic) ->
            if expireTime > DateTime.UtcNow then
                subscribers
                |> List.filter (fun x -> type' = x.Type
                                           && topicBindingMatch topic x.Binding)
                |> List.iter (fun x -> x.Action message)
            return! loop subscribers agent
    }

type MemoryBus () =
    let agent = MailboxProcessor.Start(loop [])
    do agent.Error.Add raise
    interface IDisposable with
        member __.Dispose() =
            agent.PostAndReply Stop
    interface ProcessManagerBus with
        member __.Publish (message : 'a) expiry =
            agent.Post (Publish (box message, typeof<'a>, DateTime.UtcNow + expiry, None))
        member __.TopicPublish (message : 'a) topic expiry =
            agent.Post (Publish (box message, typeof<'a>, DateTime.UtcNow + expiry, Some topic))
        member __.Subscribe sid action =
            agent.Post (Subscribe { SubscriptionId = sid; Binding = "#"; Action = action })
        member __.TopicSubscribe sid (Topic binding) action =
            agent.Post (Subscribe { SubscriptionId = sid; Binding = binding; Action = action })
```

## Appendix 1

The async version!

File 1:

``` fsharp
module EasyNetQ.ProcessManager.Types

open System

type SubscriptionId = SubscriptionId of string
type Topic = Topic of string

type ProcessManagerBus =
    inherit IDisposable

    abstract member Publish<'a when 'a : not struct> :
        'a -> TimeSpan -> Async<unit>
    abstract member TopicPublish<'a when 'a : not struct> :
        'a -> Topic -> TimeSpan -> Async<unit>
    abstract member Subscribe<'a when 'a : not struct> :
        SubscriptionId -> ('a -> Async<unit>) -> unit
    abstract member TopicSubscribe<'a when 'a : not struct> :
        SubscriptionId -> Topic -> ('a -> Async<unit>) -> unit
```

File 2:

``` fsharp
module EasyNetQ.ProcessManager.MemoryBus

open System
open EasyNetQ.ProcessManager.Types

type private Subscriber =
    abstract Action : obj -> Async<unit>
    abstract Type : Type
    abstract Binding : string

type private Subscriber<'a> =
    { SubscriptionId : SubscriptionId
      Binding : string
      Action : 'a -> Async<unit> }
    interface Subscriber with
        member x.Action o =
            o |> unbox<'a> |> x.Action
        member __.Type =
            typeof<'a>
        member x.Binding =
            x.Binding

type private BusMessage =
    | Publish of obj * Type * DateTime * Topic option
    | Subscribe of Subscriber
    | Stop of AsyncReplyChannel<unit>

let private compareSection (topicSection : string, bindingSection : string) =
    match bindingSection with
    | "#" | "*" -> true
    | _ when bindingSection = topicSection -> true
    | _ -> false

let private topicBindingMatch topicOpt (binding : string) =
    match topicOpt with
    | Some (Topic topic) ->
        let topicSections = topic.Split '.'
        let bindingSections = binding.Split '.'
        if bindingSections.[bindingSections.Length - 1] = "#" then
            Seq.zip topicSections bindingSections
            |> Seq.forall compareSection
        else
            if bindingSections.Length = topicSections.Length then
                Seq.zip topicSections bindingSections
                |> Seq.forall compareSection
            else
                false
    | None ->
        binding = "#"

let rec private loop subscribers (exiting : AsyncReplyChannel<unit> option) (agent : MailboxProcessor<BusMessage>) =
    async {
        match exiting with
        | Some chan when agent.CurrentQueueLength = 0 ->
            return chan.Reply()
        | _ ->
            let! msg = agent.Receive()
            match msg with
            | Stop chan ->
                return! loop subscribers (Some chan) agent
            | Subscribe s ->
                return! loop (s::subscribers) exiting agent
            | Publish (message, type', expireTime, topic) ->
                if expireTime > DateTime.UtcNow then
                    let matchingSubs =
                        subscribers
                        |> List.filter (fun x -> type' = x.Type
                                                  && topicBindingMatch topic x.Binding)
                    for sub in matchingSubs do
                        sub.Action message |> Async.StartImmediate
                return! loop subscribers exiting agent
    }

type MemoryBus () =
    let agent = MailboxProcessor.Start(loop [] None)
    do agent.Error.Add raise
    interface IDisposable with
        member __.Dispose() =
            agent.PostAndReply Stop
    interface ProcessManagerBus with
        member __.Publish (message : 'a) expiry =
            agent.Post (Publish (box message, typeof<'a>, DateTime.UtcNow + expiry, None))
            async.Zero()
        member __.TopicPublish (message : 'a) topic expiry =
            agent.Post (Publish (box message, typeof<'a>, DateTime.UtcNow + expiry, Some topic))
            async.Zero()
        member __.Subscribe sid action =
            agent.Post (Subscribe { SubscriptionId = sid; Binding = "#"; Action = action })
        member __.TopicSubscribe sid (Topic binding) action =
            agent.Post (Subscribe { SubscriptionId = sid; Binding = binding; Action = action })
```
