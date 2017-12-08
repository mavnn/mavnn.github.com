---
layout: post
title: "Logging Freya"
date: 2017-12-08 15:43:57 +0000
comments: true
categories: [fsharp, freya]
---
Eugene Tolmachev asked in a comment on a previous post [how I handle dependency injection](http://disq.us/p/1oeml1a) with [Freya](https://freya.io/).

So... my first, slightly annoying answer is that I try not to. Mark Seeman has written about this in a [great series of blog posts](http://blog.ploeh.dk/2017/01/27/from-dependency-injection-to-dependency-rejection/) which I won't try and repeat here.

Still, there are occasions where you want to quickly and easily do... something.. with a dependency making use of the context that being inside a Freya workflow provides. Let's quickly walk through how I inject a logger into a Freya workflow which "knows" about things like the request ID Kestrel has assigned to the current request.

I'm going to use Serilog as an example below, but you could also use any other structured logging library (I like Logary, but there isn't a .NET Core release at time of writing).

<!-- more -->

I'll annotate the code inline to give you an idea what it's doing.

So; our first module is shared code which you'll probably want to reuse across all of your Freya services. Put it in a separate .fs file (it assumes Serilog has been taken as a dependency).

``` fsharp
module Logging

open Aether.Operators
open Freya.Core
open Freya.Optics
open Serilog
open Serilog.Context
open Serilog.Configuration

// We'll expand the Request module with two news Optics;
// one uses the "RequestId" constant defined by the Owin
// specification to extract the ID assigned to this request.
// The other we'll define in the "serilog" name space in the
// Freya context Dictionary (all owin keys start "owin.")
[<RequireQualifiedAccess>]
module Request =
    let requestId_ =
            State.value_<string> Constants.RequestId
        >-> Option.unsafe_

    // An optic for focussing on an ILogger in the Freya
    // state. That's great, but how does the ILogger get
    // there? Read on...
    let logger_ =
            State.value_<ILogger> "serilog.logger"
        >-> Option.unsafe_

// As a structured logging library, you can attach an
// array of "values" to a Serilog event - we'll use this
// helper to give us a more "F#ish" API
type SerilogContext =
    { Template : string
      Values : obj list }

[<RequireQualifiedAccess>]
module Log =
    // Extract the request ID once per request
    let private rid =
        Freya.Optic.get Request.requestId_
        |> Freya.memo

    // Extract the ILogger once per request
    let private ilogger =
        Freya.Optic.get Request.logger_
        |> Freya.memo

    // A method to inject an ILogger *into* the Freya
    // state
    let injectLogger (config : LoggerConfiguration) =
        let logger =
            config
                .Enrich.FromLogContext()
                .CreateLogger()
            :> ILogger
        freya {
            do! Freya.Optic.set Request.logger_ logger
            return Next
        }

    // From here on in is just an F# friendly wrapper
    // around Serilog.

    // Start building up a new log message with a
    // message template
    let message template =
        { Template = template
          Values = [] }

    // Add a value to the message context
    let add value context =
        { context with Values = (box value)::context.Values }

    // Function that knows how to send a message with all of the
    // values correctly associated, and the requestId set
    let private send f context =
        freya {
            let! requestId = rid
            let! logger = ilogger
            using
                (LogContext.PushProperty("RequestId", requestId))
                (fun _ ->
                     let values =
                         context.Values
                         |> List.toArray
                         |> Array.rev
                     f logger context.Template values)
        }

    // The four standard log levels
    let debug context =
        let f (logger : ILogger) template (values : obj []) =
            logger.Debug(template, values)
        send f context

    let info context =
        let f (logger : ILogger) template (values : obj []) =
            logger.Information(template, values)
        send f context

    let warn context =
        let f (logger : ILogger) template (values : obj []) =
            logger.Warning(template, values)
        send f context

    let error context =
        let f (logger : ILogger) template (values : obj []) =
            logger.Error(template, values)
        send f context
```

So that's great and all... but how and where do we actually call that `injectLogger` function?

Well, that goes in your application root where you build your final Freya app.

Mine normally ends up looking something like this:

``` fsharp
let root logConfig =
    let routes =
        freyaRouter { (* My resources here *) }
    Log.injectLogger logConfig
    |> (flip Pipeline.compose) routes
    |> (flip Pipeline.compose) notFound
```

Because `injectLogger` returns a Freya `Pipeline` type which *always* passes handling onto the next step in the pipeline, all that first step does is add in a newly initialized ILogger to the Freya state, and then passes things on down the chain as normal.

In your Freya code, logging looks like this:

``` fsharp
let notFoundResponse =
    freya {
        let! path = Freya.Optic.get Request.path_
        do! Log.message "Why am I logging a GUID like this one {guid} on requests to {path}?"
            |> Log.add (Guid.NewGuid())
            |> Log.add path
            |> Log.info
        return representJson "We couldn't find that"
    }
```

Notice that `do!` is required for logging now, as our log methods have type `Freya<unit>`. This is what allows us to add the request specific context to our logs without explicitly having to append it ourselves every time.

I'm not sure if this strictly answers Eugene's question, but I hope all you (potential) Freya users out there find it helpful regardless.
