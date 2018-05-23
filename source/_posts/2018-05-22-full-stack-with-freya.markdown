---
layout: post
title: "Full Stack with Freya"
date: 2018-05-22 15:04:00 +0100
comments: true
categories: ["fsharp","freya","fable"]
---
Yesterday night I was about to demo a quick server/client pair with Freya and Fable, and it all went a bit wrong. Some of the issues weren't related to what I did (computers, gotta love 'em) but others were just bits of configuration that I didn't have at my finger tips.

This means it's time for a little practice for me, and a mini-tutorial for you (and future me).

<!-- more -->

## What we're going to do

We're going to build a small server application based on Freya which will serve JSON and be a nice RESTful (in the loose sense) API.

Then, we're going to configure Fable with Elmish to load data from that API. The crucial thing here is that we're going to configure both projects such that we have a seamless development work flow; automated recompile and restart of the server on code changes, and automatic recompile/reload of the Fable UI on change.

## The server

Make sure your dotnet core Freya template is up to date:

``` bash
dotnet new -i Freya
```

In a root directory for our overall solution, run:

``` bash
dotnet new freya -lang f# -c hopac -f kestrel -o FateServer
```

This will create a new directory called "FateServer" with a F# project in it. Go into the directory and make sure everything has restored correctly:

``` bash
cd FateServer
dotnet restore
dotnet build
```

One thing I've been slowly learning with dotnet core is that the `restore` run by default during a build doesn't always seem to be as effective as actually running the full restore command. Just in general, if Core is behaving strangely, running `restore` is a good starting point.

Next up is making our server log something: by default, Kestrel logs basically nothing.

Install the logging package (it's not part of the default Freya template):

``` bash
dotnet add package Microsoft.Extensions.Logging.Console
dotnet restore
```

In `Program.fs` add the following at the end of the open statements:

``` fsharp
open Microsoft.AspNetCore.Builder
open Microsoft.AspNetCore.Hosting
open Microsoft.Extensions.Logging

let configureLogging (b : IWebHostBuilder) =
    b.ConfigureLogging(fun l -> l.AddConsole() |> ignore)
```

Then inject the method into your WebHost configuration pipeline:

``` fsharp
    WebHost.create ()
    |> WebHost.bindTo [|"http://localhost:5000"|]
    |> WebHost.configure configureApp
    |> configureLogging
    |> WebHost.buildAndRun
```

Hey presto! Run your application and get logs!

To finish off the niceties of civilized development, let's add the watch command to our server.

Crack open the `fsproj` file and add the following ItemGroup to it:

``` xml
<ItemGroup>
    <DotNetCliToolReference Include="Microsoft.DotNet.Watcher.Tools" Version="2.0.0" />
</ItemGroup> 
```

Run `dotnet restore` and from now on running `dotnet watch run` to start continuous development with file watching should work.

Now we just need to serve up some JSON. We want a send a format which Fable understands, and the kind people at the Fable project have written a Newtonsoft configuration for doing exactly that.

Stop watching the build long enough to run:

``` bash
dotnet add package Fable.JsonConverter
dotnet restore
```

Next, set up the domain. Create a new file `Character.fs` (we're going to be sending back and forth [Fate Accelerated](https://fate-srd.com/fate-accelerated/get-started) characters as data). Make sure you add it to the project file before `Api.fs`.

``` fsharp
module Character

type LadderLevel =
    | BeyondLegendary of int
    | Legendary
    | Epic
    | Superb
    | Great
    | Good
    | Fair
    | Average
    | Mediocre
    | Poor
    | Terrible
    | Abysmal
    | BeyondAbysmal of int

type Character =
    { Name : string
      Careful : LadderLevel
      Clever : LadderLevel
      Flashy : LadderLevel
      Forceful : LadderLevel
      Quick : LadderLevel
      Sneaky : LadderLevel
      HighConcept : string
      Trouble : string
      Aspects : string list
      Stunts : string list }
```

Now move across to `Api.fs`. You'll see that it defaults to a single "greeting" endpoint which responds with a text response. Let's add a helper for sending JSON correctly, immediately after the existing `open` statements:

``` fsharp
open Freya.Machines.Http.Cors
open Freya.Types.Http.Cors
open System
open System.IO
open Newtonsoft.Json
open Character

let jsonConverter = Fable.JsonConverter() :> JsonConverter

module Represent =
    let json<'a> value =
        let data =
            JsonConvert.SerializeObject(value, [|jsonConverter|])
            |> Text.UTF8Encoding.UTF8.GetBytes
        let desc =
            { Encodings = None
              Charset = Some Charset.Utf8
              Languages = None
              MediaType = Some MediaType.Json }
        { Data = data
          Description = desc }
```

Next, delete the entire rest of the file and add the following:

``` fsharp
// This endpoint requires a URL template with the "name" atom
let name_ = Route.atom_ "name"

let name =
    freya {
        let! nameO = Freya.Optic.get name_

        match nameO with
        | Some name -> return name
        | None -> return failwith "Name is a compulsory element of the URL" }

// We're going to hard code our data for now
let exampleCharacters =
    Map [
        "bob", { Name = "Bob Bobson"
                 Careful = Mediocre
                 Clever = Fair
                 Flashy = Fair
                 Forceful = Average
                 Quick = Average
                 Sneaky = Good
                 HighConcept = "The eternal example"
                 Trouble = "Lives in the test"
                 Aspects = [ "It's only Bob"
                             "Is he... the recursive one?"
                             "I've got Fred's back!" ]
                 Stunts = [ "Because everyone assumes I don't exist, I get +2 on Sneaky rolls to not be noticed." ] }
    ]

// Once per request, try and load the named character (see the memo at the end)
let character =
    freya {
        let! name = name
        return Map.tryFind (name.ToLowerInvariant()) exampleCharacters
    } |> Freya.memo

let characterExists =
    character |> Freya.map (fun c -> c.IsSome)

let sendCharacter =
    freya {
        let! character = character
        return Represent.json (character.Value) }

let characterMachine =
    freyaMachine {
#if DEBUG
        cors
        corsOrigins [ SerializedOrigin.parse "http://localhost:8080" ]
#endif
        methods [GET; HEAD; OPTIONS]
        exists characterExists
        handleOk sendCharacter }

let root =
    freyaRouter {
        resource "/character/{name}" characterMachine }
```

There's quite a lot going on in there, but what we've defined with `characterMachine` is a resource which checks if a character exists, and sends it as Fable readable JSON if it does. We then configure a route to point to it.

Critically, we also turn on [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) (Cross Origin Resource Sharing) for localhost:8080 for debug builds. This will enable requests from our Fable client running it's development server on a different port to talk to the server.

Edit: Zaid Ajaj [points out](https://twitter.com/zaid_ajaj/status/999177873431891968) that you can also configure webpack's dev server to proxy to your development front end. If you're writing a system where your API and client will be running on the same domain, check out how to do that below.

## The client

Go back up into the root directory of the solution, and run:

``` bash
dotnet new -i Fable.Template.Fulma.Minimal
```

To get a dotnet core template for Fable with F# wrappers for React and Bulma - as well as Elmish pre-installed.

Then run:

``` bash
dotnet new fulma-minimal -lang f# -o FateClient
```

To create our client application.

Go into the newly created project directory, and use the built in build scripts to get everything up and running:

``` bash
cd FateClient
./fate.sh -t watch
```

On first run, it will download most of the internet, but such is modern net development.

Browse on over to [http://localhost:8080/](http://localhost:8080/) to see the base template before we start hacking away!

Very pretty: and in `App.fs` we can see the nice clean Elmish code driving it.

If you're running both API and client on the same domain, this is also a good time to update your webpack config (you'll find `webpack.config.js` in your FateClient directory). Amend the `devServer` section as follows:

``` json
    devServer: {
      proxy: {
        '/character/*': {
          target: 'http://localhost:5000',
          changeOrigin: true
        }
      },
      contentBase: "./static",
      publicPath: "/",
      hot: true,
      inline: true
    },
```

If you do this, you'll want to change the URL below used to load the data.

Now! Let's start hacking away. Firstly, we're going to want to share our character types. I've decided here that they are owned by the server, so we need to link the file into the Fable project.

In `FateClient.fsproj`, add change:

``` xml
  <ItemGroup>
    <Compile Include="App.fs" />
  </ItemGroup>
```

to:

``` xml
  <ItemGroup>
    <Compile Include="..\..\FateServer\Character.fs" />
    <Compile Include="App.fs" />
  </ItemGroup>
```

Now we can load up our character. In `App.fs`, it's time to expand our model. Change our Elmish app as below:

``` fsharp
module App.View

open Elmish
open Fable.Helpers.React
open Fable.Helpers.React.Props
open Fable.PowerPack
open Fable.PowerPack.Fetch
open Fulma
open Fulma.FontAwesome
open Character

type Model =
    { IsLoading : bool
      Character : Character option
      ErrorMessage : string option }

type Msg =
    | CharacterLoaded of Character
    | LoadingError of string

let loadBob () =
    promise {
        let props =
            [ RequestProperties.Method HttpMethod.GET ]
        #if DEBUG
        // Use "/character/bob" here if you've set up the webpack proxy
        return! fetchAs<Character> "http://localhost:5000/character/bob" props
        #else
        return! fetchAs<Character> "http://api.example.com/character/bob" props
        #endif
    }

let init _ =
    { IsLoading = true
      Character = None
      ErrorMessage = None },
    Cmd.ofPromise loadBob () CharacterLoaded (fun e -> LoadingError e.Message)

let private update msg model =
    match msg with
    | CharacterLoaded bob ->
        { model with IsLoading = false
                     Character = Some bob }, Cmd.none
    | LoadingError error ->
        { model with IsLoading = false
                     Character = None
                     ErrorMessage = Some error }, Cmd.none

let loadingMessage model =
    if model.IsLoading then
        [ str "Loading..." ]
    else []

let isRounded : IHTMLProp list =
    [ Style [ BorderRadius "25px" ] ]

let characterView character =
    [ Hero.hero [ Hero.Color IsBlack
                  Hero.Props isRounded ] [
        Hero.body [] [
            Container.container [ Container.IsFluid
                                  Container.Modifiers
                                      [ Modifier.TextAlignment (Screen.All, TextAlignment.Centered) ] ] [
                Heading.h1 [] [ str character.Name ]
                p [] [
                    strong [] [ str "High Concept: " ]
                    str character.HighConcept
                ]
                p [] [
                    strong [] [ str "Trouble: " ]
                    str character.Trouble
                ]
            ]
        ]
      ]
      Columns.columns [] [
          Column.column [] [
              Heading.h2 [] [ str "Approaches" ]
              Table.table
                  [ Table.IsBordered
                    Table.IsStriped ]
                  [ thead []
                        [ tr []
                              [ th [] [ str "Approach" ]
                                th [] [ str "Level" ] ] ]
                    tbody []
                        [ tr []
                              [ td [] [ str "Careful" ]
                                td [] [ str <| character.Careful.ToString() ] ]
                          tr []
                              [ td [] [ str "Clever" ]
                                td [] [ str <| character.Clever.ToString() ] ]
                          tr []
                              [ td [] [ str "Flashy" ]
                                td [] [ str <| character.Flashy.ToString() ] ]
                          tr []
                              [ td [] [ str "Forceful" ]
                                td [] [ str <| character.Forceful.ToString() ] ]
                          tr []
                              [ td [] [ str "Quick" ]
                                td [] [ str <| character.Quick.ToString() ] ]
                          tr []
                              [ td [] [ str "Sneaky" ]
                                td [] [ str <| character.Sneaky.ToString() ] ] ]
                  ]
          ]
          Column.column [] [
              Heading.h2 [] [ str "Other Aspects" ]
              ul [] [
                  yield! [ for a in character.Aspects -> li [] [ str a ] ]
              ]
              Heading.h2 [] [ str "Stunts" ]
              ul [] [
                  yield! [ for s in character.Stunts -> li [] [ str s ] ]
              ]
          ]
      ]
    ]

let errorView message =
    [ Notification.notification [ Notification.Color IsDanger ] [
        str message
    ] ]

let private view model dispatch =
    Container.container [] [
        Content.content [ ]
          [ yield! loadingMessage model
            match model.Character with
            | Some c ->
                yield! characterView c
            | None -> ()
            match model.ErrorMessage with
            | Some m ->
                yield! errorView m
            | None -> () ]
    ]

open Elmish.React
open Elmish.Debug
open Elmish.HMR

Program.mkProgram init update view
#if DEBUG
|> Program.withHMR
#endif
|> Program.withReactUnoptimized "elmish-app"
#if DEBUG
|> Program.withDebugger
#endif
|> Program.run
```

And there you have it - a simple app that loads "Bob" from our server, using the generic `fetchAs` method to cast the JSON back into our strongly typed world. Making the application interactive and more attractive is left to the user; it gets quite addictive with a nice type safe wrapper over React and auto-reloading.

Till next time...

![The Final Result](/images/bob_bobson.png)
