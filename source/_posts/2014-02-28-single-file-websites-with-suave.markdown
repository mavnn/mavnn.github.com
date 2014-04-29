---
layout: post
title: "Single file websites with Suave"
date: 2014-02-28 09:54:46 +0000
comments: true
categories: [fsharp, programming, suave]
---

> As of a few days ago, the embedded module [was merged](https://github.com/SuaveIO/suave/pull/100/files) into Suave master. Enjoy!

I'm a great fan of [Suave](http://suave.io/) for simple web development in F#. I highly recommend checking out the site for details, but in the mean time I'd like to share a little trick I've been using for rapid prototyping that I'm finding very useful.

The Suave.Http module contains a few helpers for serving static files from disk. Unfortunately, depending on use case and deployment strategy, relying on the location of a bunch of files on disk can be problematic.

So (open source to the rescue!) I cracked open the code and wrote a small alternative implementation that serves files from the current assembly's embedded resources. I'm finding it especially useful for single page JavaScript apps where you have a small number of resources and then a lot of end points providing api functionality.

Setting up your website looks something like this:

``` fsharp
module Website
open System
open Suave.Http
open Suave.Types
open Embedded

let app =
    choose [
        // serve the embedded index.html for "/"
        GET >>= url "/" >>= resource "index.html"
        // check if the request matches the name of an embedded resource
        // if it does, serve it up with a reasonable cache
        GET >>= browse_embedded
        // If it doesn't, try and trigger your api end points
        GET >>= url "/json" >>== (fun _ -> serveJson <| makeData())
        GET >>= url "/carrier" >>== (fun _ -> getCarrierCodes ())
        // Nothing else has worked - 404
        NOT_FOUND "Sorry, couldn't find your page"
    ]

web_server default_config app
```

And the embedded module looks like this:

``` fsharp
module Embedded

open System
open System.IO
open System.Reflection
open Suave
open Suave.Http
open Suave.Types
open Suave.Socket

let private ass = Assembly.GetExecutingAssembly()

let private resources =
    ass.GetManifestResourceNames()

let private CACHE_CONTROL_MAX_AGE = 600

let private lastModified = DateTime.UtcNow

let private send_embedded resourceName r =
    let write_embedded file (r : HttpRequest) = async {
      use s = ass.GetManifestResourceStream(resourceName)

      if s.Length > 0L then
        do! async_writeln r.connection (sprintf "Content-Length: %d" s.Length) r.line_buffer

      do! async_writeln r.connection "" r.line_buffer

      if s.Length > 0L then
        do! transfer_x r.connection s }

    async { do! response_f 200 "OK" (write_embedded resourceName) r } |> succeed

let resource resourceName =
    if resources |> Array.exists ((=) resourceName) then
      let send_it _ = 
        let mimes = mime_type <| IO.Path.GetExtension resourceName
        #if DEBUG
        set_mime_type mimes 
        >> send_embedded (resourceName)
        #else
        set_header "Cache-Control" (sprintf "max-age=%d" CACHE_CONTROL_MAX_AGE)
        >> set_header "Last-Modified" (lastModified.ToString("R"))
        >> set_header "Expires" (DateTime.UtcNow.AddSeconds(float(CACHE_CONTROL_MAX_AGE)).ToString("R")) 
        >> set_mime_type mimes 
        >> send_embedded (resourceName)
        #endif
      warbler ( fun (r:HttpRequest) ->
        let modified_since = (r.headers ? ``if-modified-since`` )
        match modified_since with
        | Some v -> let date = DateTime.Parse v
                    if lastModified > date then send_it ()
                    else NOT_MODIFIED
        | None   -> send_it ())
    else
      never

let browse_embedded : WebPart =
    warbler (fun req -> resource (req.url.TrimStart([| '/' |])))
```

[@ad3mar](https://twitter.com/ad3mar) if you feel like rolling this into Suave, you can consider it licenced under what ever is most convenient. An official licence file would make me much happier using Suave in production, by the way (hint, hint).

Edit: ad3mar has pointed out in the comments that Suave is already Apache2 licensed, I just failed to find the file last time I looked.
