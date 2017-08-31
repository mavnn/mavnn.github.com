---
layout: post
title: "System.Console is why we can't have nice things"
date: 2017-08-31 16:30:18 +0100
comments: true
categories: [dotnet,prognet,fsharp]
---
In writing a simple tutorial for this years [Progressive .Net](https://skillsmatter.com/conferences/8268-progressive-dot-net-2017#program) I thought I'd use the Console to allow some nice visual feedback with requiring a dependency.

TD;LR: ```System.Console``` (at least on dotnet core 2.0) is not as threadsafe as you'd hope, and means that writing any simple cross platform console UI is nearly impossible.

<!-- more -->

So, I started with a draw method like this:

``` fsharp
type Coord =
    { X : int
      Y : int }

let draw changes =
    changes
    |> Seq.iter (fun (coord, item : char) ->
        Console.CursorLeft <- coord.X
        Console.CursorTop <- coord.Y
        Console.Write item)
```

This method just takes a sequence of coordinates and characters to write in them, and then moves the cursor around the console to write your inputs. And it works fine.

Then I wanted a sequence of keys pressed by the user:

``` fsharp
type Directions =
    | Up
    | Down
    | Left
    | Right
    | Stay

let inputUnfolder prev =
    let read = Console.ReadKey(true)
    match read.Key with
    | ConsoleKey.UpArrow ->
        Some (Up, Up)
    | ConsoleKey.DownArrow ->
        Some (Down, Down)
    | ConsoleKey.LeftArrow ->
        Some (Left, Down)
    | ConsoleKey.RightArrow ->
        Some (Right, Right)
    | _ ->
        Some (prev, prev)
        
let keysPressed =
    Seq.unfold inputUnfolder Stay
```

Again, this works fine. And as long as you take one item from the input stream, do all your drawing and then take the next item everything continues to be good.

But... this story doesn't end here. What I was really after was accepting key presses on one thread, and drawing on another.

First problem: it turns out that calling ```Console.ReadKey``` on one thread, and setting ```Console.CursorTop/Left``` on another causes a deadlock.

A bit of research led to the ```Console.KeyAvailable``` property, and rewriting ```inputFolder```:

``` fsharp
let rec inputUnfolder prev =
    if Console.KeyAvailable then
        let read = Console.ReadKey(true)
        match read.Key with
        | ConsoleKey.UpArrow ->
            Some (Up, Up)
        | ConsoleKey.DownArrow ->
            Some (Down, Down)
        | ConsoleKey.LeftArrow ->
            Some (Left, Down)
        | ConsoleKey.RightArrow ->
            Some (Right, Right)
        | _ ->
            Some (prev, prev)
    else
        Async.Sleep 1 |> Async.RunSynchronously
        inputUnfolder prev
```

Yeah! Spin loop. That looks totally healthy.

Unfortunately, we now have the issue that because ```Console.ReadKey``` is not actively blocking at the moment the key is pressed, the input key is printed directly to the console. There doesn't appear to be anyway of blocking this.

The real pity about all of this is not that it's just wasted a couple of hours of my life writing a "simple" tutorial (although that's pretty annoying!); it's the fact that with dotnet core being genuinely cross platform, I was hoping to use it to write a few nice console UI based applications. It turns out that apart from the well know performance issues of ```System.Console```, it doesn't currently appear to be possible at all.
