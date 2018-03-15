---
layout: post
title: "RouteMaster and the Tale of the Globally Unique Voters"
date: 2018-03-15 21:43:38 +0000
comments: true
categories: ["fsharp", "RouteMaster"]
---
[RouteMaster](https://github.com/RouteMasterIntegration/RouteMaster) a process manager library I've been working on for simplifying the creation of complex work flows in message based systems.

One of the challenges RouteMaster faces is that once you have defined your "route" in RouteMaster, you generally want to run multiple instances of your process manager service in your distributed environment. This means that a lot of care has been taken to make sure that things like work flow state is handled safely, but it also causes a particular challenge for dealing with timeouts.

<!-- more -->

### What's the problem?

RouteMaster nodes for managing the same process maintain a list of messages they are expecting to receive - and how long they're willing to wait for them. This list is stored in a transactional data store.

Approximately every seconds, the list should be scanned, and messages which have not been received before their timeout should be removed and `TimeOut` messages published to the process' time out handlers.

It turns out that this scan is the single slowest action that RouteMaster needs to take... and here we have all of the nodes carrying it out every second or so.

### The solution

My first thought was the sinking feeling that I was going to have to implement a [consensus algorithm](https://en.wikipedia.org/wiki/Consensus_algorithm), and have the nodes "agree" on a master to deal with time outs.

Fortunately I had the good sense to talk to [Karl](https://twitter.com/kjnilsson) before doing so. Karl pointed out that I didn't need _exactly one_ master at any one time; if there was no master for short periods, or multiple masters for short periods, that was fine. The problem only kicks in if there are *lots* of masters at the same time.

He mentioned that there was a known answer in these kinds of situations: have a GUID election.

The logic is fairly straight forward, and goes something like this...

Each node stores some state about itself and the other nodes it has seen. (The full code can be seen at [in the RouteMaster repository if you're curious](https://github.com/RouteMasterIntegration/RouteMaster/blob/master/Core/TimeoutManager.fs), but I'll put enough here to follow the idea).

``` fsharp
type internal State =
    { Id : Guid
      Active : bool
      Tick : int64<Tick>
      LowestGuidSeen : Guid
      LowestGuidSeenTick : int64<Tick>
      GuidsSeen : Map<Guid, int64<Tick>>
      LastPublish : int64<Tick> }
    static member Empty() =
        { Id = Guid.NewGuid()
          Active = false
          Tick = 0L<Tick>
          LowestGuidSeen = Guid.MaxValue
          LowestGuidSeenTick = 0L<Tick>
          GuidsSeen = Map.empty
          LastPublish = -10L<Tick> }
```

As you can see, each node starts off with a unique ID, and keeps track of every other ID it has seen and when. It also sets the "lowest" GUID it's seen so far to the value `Guid.MaxValue`:

``` fsharp
type Guid with
    static member MaxValue =
        Guid(Array.create 16 Byte.MaxValue)
```

A `MailBoxProcessor` is then connected to the message bus (we're in a message based system) and to a one second `Tick` generator.

If a new GUID arrives, we add it to our state:

``` fsharp
    let addGuid guid state =
        if guid <= state.LowestGuidSeen then
            { state with
                Active = guid = state.Id
                LowestGuidSeen = guid
                LowestGuidSeenTick = state.Tick
                GuidsSeen = Map.add guid state.Tick state.GuidsSeen }
        else
            { state with
                GuidsSeen = Map.add guid state.Tick state.GuidsSeen }
```

Every second, when the `Tick` fires, we:

#### Increment the Tick count

``` fsharp 
    let increment state =
        { state with Tick = state.Tick + 1L<Tick> }
```

#### Clean out "old" GUIDs

``` fsharp
    let cleanOld state =
        let liveMap =
            Map.filter (fun _ t -> t + 15L<Tick> < state.Tick) state.GuidsSeen
        if state.LowestGuidSeenTick + 15L<Tick> < state.Tick then
            match Map.toSeq liveMap |> Seq.sortBy fst |> Seq.tryHead with
            | Some (guid, tick) ->
                { state with
                    Active = guid = state.Id
                    LowestGuidSeen = guid
                    LowestGuidSeenTick = tick
                    GuidsSeen = liveMap }
            | None ->
                // If we reach here, we're not even seeing our own announcement
                // messages - something is wrong...
                Message.event Warn "Manager {managerId} is not receiving timeout manager announcements"
                |> Message.setField "managerId" state.Id
                |> logger.logSimple
                { state with
                    Active = true
                    LowestGuidSeen = state.Id
                    LowestGuidSeenTick = state.Tick
                    GuidsSeen = liveMap }
        else state
```

#### Annouce we're live if we haven't for a while

``` fsharp
let internal checkPublishAnnoucement topic (bus : MessageBus) state =
    async {
        if state.LastPublish + 10L<Tick> <= state.Tick then
            do! bus.TopicPublish
                    (TimeoutManagerAnnouncement state.Id)
                    topic
                    (TimeSpan.FromSeconds 15.)
            return { state with LastPublish = state.Tick }
        else
            return state
    }
```

#### Decide if we're a master

This is the clever bit: if the lowest GUID we've seen in a while is our own, we take responsibility for dealing with timed out messages and declare ourselves active. We'll stay active until a message arrives from a node with a lower GUID. There's no guarantee at any particular point that only one node will *definitely* think it's the master, or that a master will *definitely* be the only master - but it's more than good enough for the needs we have here.

## The moral of the story

If you need to do something hard, ask Karl how to do it. No - wait. That's good advice, but the real moral is:

Make sure you're building what you actually need - not something vastly more complex for no practical gain.
