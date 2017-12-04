---
layout: post
title: "Advent 2017 - Reading from the Firehose with Fable"
date: 2017-12-04 14:00:00 +0100
comments: true
published: false
categories: [fable, fsharp, fsadvent]
---
Each year, the F# programming community creates an advent calendar of blog posts, coordinated by Sergey Tihon [his blog](https://sergeytihon.com/2017/10/22/f-advent-calendar-in-english-2017/).

I really like the idea, and have taken part in [2016](https://blog.mavnn.co.uk/advent-2016/), [2015](https://blog.mavnn.co.uk/angels-from-the-realms-of-glory/) & [2014](https://blog.mavnn.co.uk/modelling-inheritance-with-inheritance/).

Below is this year's post.

# The plan: speed read Christmas

So; you want to find out what Christmas is about, where it really came... but you don't have much time.

The solution is obvious: take the famous bible passages that churches read every year, and speed read them!

Let's build an app to help us with that.

<!-- more -->

## The tools: Fable and Elmish

Fable is a F# to JavaScript compiler, and Elmish is a library for it designed to provide a Elm/Redux style workflow around it.

If you haven't used Elm or Redux before, the basic idea is that our application will be based around three things:

- A state type. This type will contain all of the information about the state of the application at any moment
- A message type. This will be a discriminated union with a case for each type of "message" that can update the state of the application.
- An update function. This is called every time a message is triggered; it takes the previous state and the message that has just arrived, and produces a new state.

These three things are all we need to manage the state of the application, but then we end up needing one final concept: subscribers.

Subscribers can take the current state, but more importantly they are passed a "dispatch" function that allows them to dispatch messages to the applications message queue. This is how we deal with all inputs in an Elmish application, whether from a user or whether it's things like network requests completing and delivering information our application needs.

The main, most important subscriber is the "view" (i.e. how we're going to show things to the user). In our app, our view will be displayed via a Fable wrapper for React, creating a single page web application. The view is nearly always capable of also dispatching messages - this is how we model things like buttons the user can click on.

## Getting started

Let's start by setting up the application framework. We'll need dotnet core installed, and node with a reasonably recent version of yarn if you want to follow along at home.

Make yourself a new directory, and then on the command line you can run the following commands:

``` sh
dotnet new -i Fable.Template
```

Installs the Fable template for dotnet core.

``` sh
dotnet new fable
```

Creates a new Fable project in this directory, using the directory name for the project name.

``` sh
yarn install
dotnet restore
```

Download all the basic dependencies, both for dotnet and JavaScript.

## Adding our dependencies

Apart from using Fable itself, we also want to make use of Elmish and it's React plugin.

Add these two libraries to paket.dependencies:

```
nuget Fable.Elmish.Browser
nuget Fable.Elmish.React
```

Then in the src directory add them to our Fable project as well (in paket.references):

```
Fable.Elmish.Browser
Fable.Elmish.React
```

Run a paket install to download and add the dotnet parts of the libraries to your project:

```
mono .paket/paket.exe install
```

Then go into the "src" directory and add the JavaScript libraries that these Fable libraries depend on in the browser.

```
cd src
yarn add react react-dom
dotnet restore
```

## Setting up the webpage

Let's adapt our HTML, in the "public" folder. The Fable template project assumes that we're going to be using a canvas. We're writing a text only application, so we'll just replace the canvas node with a standard `div` and mark it with an id which we'll use to tell react where to render the html our code will generate.

Your index.html should end up looking like this:

``` html
<!doctype html>
<html>
<head>
  <title>Simple Fable App</title>
  <meta http-equiv='Content-Type' content='text/html; charset=utf-8'>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="shortcut icon" href="fable.ico" />
  <link rel="stylesheet"  href="index.css" />
  <script src="https://cdn.polyfill.io/v2/polyfill.js?features=es6,fetch"></script>
</head>
<body>
  <div id="react-element"></div>
  <script src="bundle.js"></script>
</body>
</html>
```

We're going to speed read by displaying each word of the text really big in the middle of the screen one by one (so that you don't need to move your eyes to read).

Add in a `index.css` file with the following to set up styles for a large centered container and a class for displaying really large text.

``` css
html {
  font-family: sans-serif;
}

.container {
  text-align: center;
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}

.theText {
  font-size: 5em;
  margin: 20px;
}
```

## Writing "JavaScript"

Fable compiles F# to JavaScript, and comes with tooling to watch your code and update it automatically.

Fire up yarn by going into your "src" directory and running:

```
dotnet fable yarn-start
```

This will start the fable compiler and keep it running in the background.

We've already decided we want to use Elmish with the React view. We're also going to be loading some external data so we'll want access to the Fetch API.

Let's open up all the namespaces which might be relevant:

``` fsharp
module Advent2017

open System
open Fable.Core
open Fable.Core.JsInterop
open Fable.Import
open Fable.Import.Browser
open Fable.Import.React
open Fable.Import.ReactDom
open Fable.Helpers.React.Props
open Fable.PowerPack
open Fable.PowerPack.Fetch
open Elmish
open Elmish.React
module R = Fable.Helpers.React
```

Then we need a model; this holds all of the state of our app. The text to be speed read will be stored as an array of strings; we'll keep a `Max` field with the index of the last word to make our logic nice and explicit, the `Index` of the word currently being displayed, the number of ticks `SinceLast` time we updated the word and the current number of `TicksPerUpdate`.

``` fsharp
type Model =
    { Text : string []
      Max : int
      Index : int
      SinceLast : int
      TicksPerUpdate : int }
```

The `Msg` type represents all the ways that our app can be updated. The user can ask for the text to become faster, or slower; we can finish loading the text via a web request; and a `Tick` of our timer can go past.

``` fsharp
type Msg =
    | Faster
    | Slower
    | ReceivedText of string []
    | Tick

```

And the actual update logic takes one of those messages and a previous state, and gives us a new state:

``` fsharp
let update msg model =
    match msg with
    | Tick ->
        match model with
        | { TicksPerUpdate = tpu; SinceLast = sl } when sl >= tpu && tpu >= 0 ->
            { model with
                Index = min model.Max (model.Index + 1)
                SinceLast = 0 }
        | { TicksPerUpdate = tpu; SinceLast = sl } when sl >= (tpu * -1) && tpu < 0 ->
            { model with
                Index = max 0 (model.Index - 1)
                SinceLast = 0 }
        | _ ->
            { model with SinceLast = model.SinceLast + 1 }
    | Faster ->
        { model with TicksPerUpdate = model.TicksPerUpdate - 1 }
    | Slower ->
        { model with TicksPerUpdate = model.TicksPerUpdate + 1 }
    | ReceivedText text ->
        { model with
            Text = text
            Max = Array.length text - 1 }
```

I was feeling a bit silly, so you can make the application go "so fast it goes backwards." I mean, I've had user requirements that make less sense than that before!

Having defined our types and abstract logic, we now need to write the actual functionality of our app, working our way up to a method which starts it off with an initial state.

First some low level grunge for downloading the text we want to read.

We'll need a url and an auth token for the API we're using (esv.org provide a really nice API by the way).

``` fsharp
let requestUri =
    [ "https://api.esv.org/v3/passage/text/?q=John%201"
      "&include-passage-references=false"
      "&include-first-verse-numbers=false"
      "&include-verse-numbers=false"
      "&include-footnotes=false"
      "&include-footnote-body=false"
      "&include-passage-horizontal-lines=false"
      "&include-heading-horizontal-lines=false"
      "&include-headings=false"
      ] |> String.concat ""
      
let authToken = "TEST"
```

We've split it up over multiple lines to make it readable as I'm specifying a lot of options. Nearly all of the them boil down to removing optional metadata from the text (such as verse numbers and translation footnotes). For speed reading we just want the actual words. If you want to run this application a lot, you'll need to register your application on esv.org to get your own auth token.

The text it tries to download is John 1; it's one of the most famous Christmas texts, but also very poetic in it's presentation. I love it, but if you just want "the Christmas story" try a base url of `"https://api.esv.org/v3/passage/text/?q=Luke%201-Luke%202:21"` instead.

Now, some boiler plate to extract the passage from the JSON blob that esv.org send back to us. I'm totally ignoring any errors that might occur in the request here, you probably don't want to do that in a real application.

``` fsharp
let toText (res : Response) =
    res.text()

let (|Val|_|) key = Map.ofSeq >> (Map.tryFind key)

let extractPassage (str : string) =
    let json = Json.ofString str
    match json with
    | Ok (Json.Object (Val "passages" (Json.Array [|Json.String first|]))) -> first
    | _ -> "Error"

let getText dispatch =
    fetch requestUri [ requestHeaders [ Authorization <| sprintf "Token %s" authToken ] ]
    |> Promise.bind toText
    |> Promise.map extractPassage
    |> Promise.iter (fun text -> text.Split(Array.empty<char>, StringSplitOptions.RemoveEmptyEntries)
                                 |> ReceivedText
                                 |> dispatch)
```

So `getText` will, when passed a `dispatch` function, call our Url, get the text of he body, throw away everything apart from the text of the passage we actually requested, and then split the passage on any whitespace.

We also want regular `ticks` coming through and prompting us to move onto the next word (or the previous if we're going backwards...).

``` fsharp
let triggerUpdate (dispatch : Msg -> unit) =
    window.setInterval((fun _ -> dispatch Tick), 100) |> ignore
```

Next up, we need our view. The view will both receive new versions of the model as they are created, but will also receive a dispatch functions so it can feed new messages into our `update` function.

``` fsharp
let view model dispatch =
    match model.Text with
    | t when Array.isEmpty t ->
        R.div []
            [ R.div [] [R.str "Loading..."] ]
    | _ ->
        R.div [ ClassName "container" ]
            [ R.button [ OnClick (fun _ -> dispatch Faster) ] [ R.str "Faster" ]
              R.div [ ClassName "theText" ] [ R.str model.Text.[model.Index]  ]
              R.button [ OnClick (fun _ -> dispatch Slower) ] [ R.str "Slower" ]
              R.div [] [ R.str <| sprintf "Ticks Per Update: %d" model.TicksPerUpdate ] ]
```

It displays a placeholder while we're loading data, and then buttons to speed up and slow down the speed reading rate.

Finally, we can fire up our application.

``` fsharp
let init () =
    { Text = Array.empty
      Max = 0
      Index = 0
      SinceLast = 0
      TicksPerUpdate = 10 }

Program.mkSimple init update (lazyView2 view)
|> Program.withSubscription (fun _ -> Cmd.ofSub getText)
|> Program.withSubscription (fun _ -> Cmd.ofSub triggerUpdate)
|> Program.withReact "react-element"
|> Program.run
```

We just set our initial state and then tell react which element in our html we want to render our view in. Because we are registering `getText` and `triggerUpdate` as subscriptions, they will be passed a `dispatch` function and kicked off immediately, so the first thing our app will do is try and download the text.

Once the text is loaded, we'll start going forwards through the text, and are buttons for reading faster and slower will be displayed.

Let's see it in action:

![The speed reader in action](/images/speed_reading.gif)

And there we have it - I hope you'll enjoy this brief trip into writing user interfaces in F#, and your _speedy_ recap of one of the most famous readings from the Christmas story!

## Appendix: The full App.fs

``` fsharp
module Advent2017

open System
open Fable.Core
open Fable.Core.JsInterop
open Fable.Import
open Fable.Import.Browser
open Fable.Import.React
open Fable.Import.ReactDom
open Fable.Helpers.React.Props
open Fable.PowerPack
open Fable.PowerPack.Fetch
open Elmish
open Elmish.React
module R = Fable.Helpers.React

type Model =
    { Text : string []
      Max : int
      Index : int
      SinceLast : int
      TicksPerUpdate : int }

type Msg =
    | Faster
    | Slower
    | ReceivedText of string []
    | Tick

let update msg model =
    match msg with
    | Tick ->
        match model with
        | { TicksPerUpdate = tpu; SinceLast = sl } when sl >= tpu && tpu >= 0 ->
            { model with
                Index = min model.Max (model.Index + 1)
                SinceLast = 0 }
        | { TicksPerUpdate = tpu; SinceLast = sl } when sl >= (tpu * -1) && tpu < 0 ->
            { model with
                Index = max 0 (model.Index - 1)
                SinceLast = 0 }
        | _ ->
            { model with SinceLast = model.SinceLast + 1 }
    | Faster ->
        { model with TicksPerUpdate = model.TicksPerUpdate - 1 }
    | Slower ->
        { model with TicksPerUpdate = model.TicksPerUpdate + 1 }
    | ReceivedText text ->
        { model with
            Text = text
            Max = Array.length text - 1 }

let requestUri =
    [ "https://api.esv.org/v3/passage/text/?q=John%201"
      "&include-passage-references=false"
      "&include-first-verse-numbers=false"
      "&include-verse-numbers=false"
      "&include-footnotes=false"
      "&include-footnote-body=false"
      "&include-passage-horizontal-lines=false"
      "&include-heading-horizontal-lines=false"
      "&include-headings=false"
      ] |> String.concat ""

let authToken = "1835f44e7a76468e1de1de8ebd3b7a095bf8f98d"

let toText (res : Response) =
    res.text()

let (|Val|_|) key = Map.ofSeq >> (Map.tryFind key)

let extractPassage (str : string) =
    let json = Json.ofString str
    match json with
    | Ok (Json.Object (Val "passages" (Json.Array [|Json.String first|]))) -> first
    | _ -> "Error"

let getText dispatch =
    fetch requestUri [ requestHeaders [ Authorization <| sprintf "Token %s" authToken ] ]
    |> Promise.bind toText
    |> Promise.map extractPassage
    |> Promise.iter (fun text -> text.Split(Array.empty<char>, StringSplitOptions.RemoveEmptyEntries)
                                 |> ReceivedText
                                 |> dispatch)

let triggerUpdate (dispatch : Msg -> unit) =
    window.setInterval((fun _ -> dispatch Tick), 100) |> ignore

let view model dispatch =
    match model.Text with
    | t when Array.isEmpty t ->
        R.div []
            [ R.div [] [R.str "Loading..."] ]
    | _ ->
        R.div [ ClassName "container" ]
            [ R.button [ OnClick (fun _ -> dispatch Faster) ] [ R.str "Faster" ]
              R.div [ ClassName "theText" ] [ R.str model.Text.[model.Index]  ]
              R.button [ OnClick (fun _ -> dispatch Slower) ] [ R.str "Slower" ]
              R.div [] [ R.str <| sprintf "Ticks Per Update: %d" model.TicksPerUpdate ] ]

let init () =
    { Text = Array.empty
      Max = 0
      Index = 0
      SinceLast = 0
      TicksPerUpdate = 10 }

Program.mkSimple init update (lazyView2 view)
|> Program.withSubscription (fun _ -> Cmd.ofSub getText)
|> Program.withSubscription (fun _ -> Cmd.ofSub triggerUpdate)
|> Program.withReact "react-element"
|> Program.run
```
