---
layout: post
title: "POSTing to Freya"
date: 2017-10-25 15:52:57 +0100
comments: true
categories: [fsharp,programming,freya]
---
I've written about how nice Freya is as a library, but documentation is still a little light on the ground.

So here's a minimal implementation of a "microservice" Freya API, starting from which dotnet commands to run to install the Freya template, through to a running web service.

Make sure you have an up to date .NET Core SDK installed, and grab yourself the handy dandy Freya template:

``` bash
dotnet new -i "Freya.Template::*"
```

Then create yourself a directory and go into it. The following command will set up a brand new Freya project using kestrel as the underlying webserver, and Hopac (rather than F# Async) for concurrency. Alternatively, you can leave both the options off and you'll get Freya running on Suave with standard Async.

``` bash
dotnet new freya --framework kestrel --concurrency hopac
```

Your project should run at this point; ```dotnet run``` will spin up a webserver on port 5000 which will give a 404 at the root and text responses on /hello and /hello/name paths.

Api.fs is where all the magic of configuring Freya happens - KestrelInterop.fs contains boilerplate for making sure Routing information passes correctly between Kestrel and Freya, and Program.fs just starts Kestrel with our Freya API as an OWIN app.

### Adding JSON

So, this is great and all, but we're building a microservice aren't we? That normally means JSON (or at least something more structured than plain text!).

Let's change things up so that as well as supplying the name to greet in the route, we can POST JSON with a name field to the /hello end point.

To respond in JSON, we need a Freya ``Represent`` record. We're sending a result with a fixed structure, so we don't need a serialization library or anything, we'll just construct the JSON by hand. Stick this near the top of Api.fs:

``` fsharp
open System.Text
open System.Text.RegularExpressions

let representGreeting =
    let before =
        Encoding.UTF8.GetBytes "{ \"greeting\": \""
    let after = Encoding.UTF8.GetBytes "\" }"
    let extremeSanifier =
        RegularExpressions.Regex("[^a-z0-9 ]", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)
    fun name ->
        let safeNameBytes =
            extremeSanifier.Replace(name, "")
            |> Encoding.UTF8.GetBytes
        { Description =
            { Charset = Some Charset.Utf8
              Encodings = None
              MediaType = Some MediaType.Json
              Languages = None }
          Data = Array.concat [before;safeNameBytes;after] }
```

So here we're defining an HTTP representation of a response, including media type and other important information.

Aside: why do we return a lambda at the end rather than making representGreeting itself a function? That's so that we don't want to rebuild the two byte arrays and the regex every time we call the function.

We also need to be able to read incoming JSON. Well, all we want is a string so lets just check that there's an '"' at the beginning and end...

``` fsharp 
open System.IO

let grabString (bodyStream : #Stream) =
    use reader = new StreamReader(bodyStream)
    match reader.ReadToEnd() with
    | str when str.[0] = '"' && str.[str.Length - 1] = '"' ->
        Some <| str.Substring(1, str.Length - 2)
    | _ -> None
```

Now we can start hooking up the actual root that we want. We need to make some additions to ``helloMachine``:

``` fsharp 
let helloMachine =
    freyaMachine {
        // methods [GET; HEAD; OPTIONS]
        methods [GET; HEAD; OPTIONS; POST]
        acceptableMediaTypes [MediaType.Json]
        handleOk sayHello }
```

Magically our endpoint now knows not only that we accept POSTs, but it will end the correct error code if the media type of the POST is not set to JSON.

We also need to update ``sayHello`` and ``name``; we'll extract the method of the request and choose logic for working out the name and creating the response respectively.

``` fsharp
let name_ = Route.atom_ "name"
let method_ = Freya.Optics.Http.Request.method_

let name =
    freya {
        let! requestMethod = Freya.Optic.get method_
        let! nameO =
            match requestMethod with
            | POST ->
                Freya.Optic.get Freya.Optics.Http.Request.body_
                |> Freya.map grabString
            | _ -> Freya.Optic.get name_

        match nameO with
        | Some name -> return name
        | None -> return "World" }

let representResponse greeting =
    freya {
        let! requestMethod = Freya.Optic.get method_
        match requestMethod with
        | POST ->
            return representGreeting greeting
        | _ ->
            return Represent.text greeting
    }
```

And that's everything we should need. Firing up [PostMan](https://www.getpostman.com/) we can find out that posting an empty body gets a 500 (we should probably handle that, looks like the request stream can be null), firing in a string with no media type header gets back a "415 Unsupported Media Type" (did you know that off hand?) and a POST with a correct body (i.e., starts and ends with a '"') gets us back:

``` json
{ "greeting": "Hello michael" }
```

So there you have it. Adding a POST endpoint to Freya.

### Appendix

Here is the complete Api.fs for you to follow along, with open statements moved to the top of the file:

``` fsharp
module Api

open System.IO
open System.Text
open System.Text.RegularExpressions
open Freya.Core
open Freya.Machines.Http
open Freya.Types.Http
open Freya.Routers.Uri.Template

let representGreeting =
    let before =
        Encoding.UTF8.GetBytes "{ \"greeting\": \""
    let after = Encoding.UTF8.GetBytes "\" }"
    let extremeSanifier =
        RegularExpressions.Regex("[^a-z0-9 ]", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)
    fun name ->
        let safeNameBytes =
            extremeSanifier.Replace(name, "")
            |> Encoding.UTF8.GetBytes
        { Description =
            { Charset = Some Charset.Utf8
              Encodings = None
              MediaType = Some MediaType.Json
              Languages = None }
          Data = Array.concat [before;safeNameBytes;after] }

let grabString (bodyStream : #Stream) =
    use reader = new StreamReader(bodyStream)
    match reader.ReadToEnd() with
    | str when str.[0] = '"' && str.[str.Length - 1] = '"' ->
        Some <| str.Substring(1, str.Length - 2)
    | _ -> None


let name_ = Route.atom_ "name"
let method_ = Freya.Optics.Http.Request.method_

let name =
    freya {
        let! requestMethod = Freya.Optic.get method_
        let! nameO =
            match requestMethod with
            | POST ->
                Freya.Optic.get Freya.Optics.Http.Request.body_
                |> Freya.map grabString
            | _ -> Freya.Optic.get name_

        match nameO with
        | Some name -> return name
        | None -> return "World" }

let representResponse greeting =
    freya {
        let! requestMethod = Freya.Optic.get method_
        match requestMethod with
        | POST ->
            return representGreeting greeting
        | _ ->
            return Represent.text greeting
    }

let sayHello =
    freya {
        let! name = name

        return! representResponse (sprintf "Hello, %s!" name) }

let helloMachine =
    freyaMachine {
        // methods [GET; HEAD; OPTIONS]
        methods [GET; HEAD; OPTIONS; POST]
        acceptableMediaTypes [MediaType.Json]
        handleOk sayHello }

let root =
    freyaRouter {
        resource "/hello{/name}" helloMachine }
```
