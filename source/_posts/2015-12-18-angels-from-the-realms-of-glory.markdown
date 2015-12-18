---
layout: post
title: "Angels from the realms of glory"
date: 2015-12-19 12:00:00 +0000
comments: true
categories: [fsharp, agents, FsAdvent]
---

> An angel of the Lord appeared to them, and the glory of the Lord shone around them, and they were terrified. <ref><a href="https://www.biblegateway.com/passage/?search=luke+2:9&version=NIV" title="Luke 2:9">Luke 2:9</a></ref>

It's that time of year again, where the F# community get together to source a collection of weird, wonderful and occasionally useful blog posts on life, the universe and sometimes Christmas.

As mentioned in last years post, I like to go back to the source when it comes to advent posts, so lets dive back into the book of Luke (and learn about agent based programming as we go).

<!-- more -->

### The plan

We're going to simulate the angelic choir as they sing for the shepherds, although with a
couple of minor limitations. One is I don't feel like dealing with cross platform audio issues
(and don't think I could do the voices justice anyway...) and the other is that I can't draw
for toffee.

So we're going to simulate a view of the angels from a long way away out of earshot.

The final result should end up looking something like this (your results may vary depending
on console colour scheme, but I'd suggest dark background for the best effect!):

<img src="/images/angels1.gif"/>

### Step 1: atomic writes to the console

If you've tried to use the ``System.Console`` namespace in .net, you'll have discovered a few
things about it. The biggest problem we want to deal with, is that writing a character in colour
to the console is not atomic.

You have to:

``` fsharp
// Set the cursor to the position you want to write
Console.SetCursorPosition(x, y)
// Change the foreground colour to the colour you want
Console.ForegroundColor <- c
// Write the character
Console.Write (string m)
```

In async code, different threads doing this at the same time will mix these operations up,
as there's no way to know what an other thread is doing with the cursor while you try and
set up your own write.

For this we're going to set up our first agent: the console agent. It will be responsible
for all writes to the screen in our program.

``` fsharp
let (|ConsoleColour|) i =
  if i <= 0 then
    ConsoleColor.Black
  elif i >= 15 then
    ConsoleColor.White
  else
    enum i

let console =
  MailboxProcessor.Start(
    fun agent ->
      let rec inner () =
        async {
          let! (x, y, ConsoleColour c, m : char) = agent.Receive()
          Console.SetCursorPosition(x, y)
          Console.ForegroundColor <- c
          Console.Write (string m)
          return! inner () }
      inner ())

console.Error.Add(fun e -> printfn "%A" e.Message)
```

The ``(|ConsoleColour|)`` construct is what's called an active pattern. With it, we can pattern
match on any integer and be guaranteed to get a valid ConsoleColor enum out. It also spells
"colour" correctly :D.

Then we start a ``MailboxProcessor`` (the default name for an agent in F#). This agent listens
for messages which consist of: an x coordinate, a y coordinate, an int for colour and a character
to write. The overall agent is implemented as an async block and so will not block a thread while
waiting for messages - but it will guarantee that it will not start processing the next message
until the current one is finished.

Hey presto! We can now safely write to the console from any thread simply by calling ``console.Post.``

We'll try it out by creating some random stationary angels.

First, we'll initialize some infinite sequences of random numbers:

``` fsharp
let seedx, seedy, seedc = 100, 150, 200

let randX = Random(seedx)
let randY = Random(seedy)
let randC = Random(seedc)

let randSeq (rand : Random) min' max' =
  Seq.unfold (fun () -> Some(rand.Next(min', max'), ())) ()

let xSeq = randSeq randX xZero (width + xZero - 1)
let ySeq = randSeq randY yZero (height + yZero - 1)
let cSeq = randSeq randC 0 15
```

Then we'll wrap the write in an async method, and draw our angels across the screen concurrently;
each angel will wait 50 milliseconds per unit across the x axis to give a nice staggered appearance.

You can find a full listing in [advent1.fsx](https://github.com/mavnn/advent2015/blob/master/advent1.fsx). Running it should give you something like this:

<img src="/images/angels2.gif"/>

> But the angel said to them, “Do not be afraid. I bring you good news that will cause great joy for all the people. Today in the town of David a Savior has been born to you; he is the Messiah, the Lord. This will be a sign to you: You will find a baby wrapped in cloths and lying in a manger.” <ref><a href="https://www.biblegateway.com/passage/?search=luke+2:10-12&version=NIV" title="Luke 2:10-12">Luke 2:10-12</a></ref>

## Step 2: Add event loop

Onwards! Time to make our angels move. Following on with the theme, we're going to make an agent
responsible for ticking off each 'loop' of events.

We'll add some safety to our console agent to make sure that writes outside the console don't
cause us issues:

``` fsharp
let width  = Console.WindowWidth
let height = Console.WindowHeight

let xZero  = Console.WindowLeft
let yZero  = Console.WindowTop

let (|ConsoleColour|) i =
  if i <= 0 then
    ConsoleColor.Black
  elif i >= 15 then
    ConsoleColor.White
  else
    enum i

let (|X|) x =
  if x < xZero then
    xZero
  elif x >= width then
    width - 1
  else
    x

let (|Y|) y =
  if y < yZero then
    yZero
  elif y >= height then
    height - 1
  else
    y

let console =
  MailboxProcessor.Start(
    fun agent ->
      let rec inner () =
        async {
          let! (X x, Y y, ConsoleColour c, m : char) = agent.Receive()
          Console.SetCursorPosition(x, y)
          Console.ForegroundColor <- c
          Console.Write (string m)
          return! inner () }
      inner ())

console.Error.Add(fun e -> printfn "%A" e.Message)
```

Notice the use of the X and Y active patterns to enforce our domain constraints on the underlying
.net type.

We'll also have some types for keeping track of an angels position and velocity.

``` fsharp
type Vector2 =
  { x : float; y : float }
  static member (+) ({ x = x1; y = y1 }, { x = x2; y = y2 }) =
    { x = x1 + x2; y = y1 + y2 }
  static member (-) ({ x = x1; y = y1 }, { x = x2; y = y2 }) =
    { x = x1 - x2; y = y1 - y2 }
  static member Abs { x = x1; y = y1 } =
    x1 * x1 + y1 * y1
    |> sqrt

type AngelInfo =
  { Position : Vector2
    Velocity : Vector2 }
```

Here we've defined + and - on a two element vector, and a helper function to calculate the vectors
magnitude.

Now we're ready to set up our event loop agent. I'm going to call mine ``ping``.

``` fsharp
type AngelMessage =
  | Init of AsyncReplyChannel<AngelInfo>
  | Next of AngelInfo list * AsyncReplyChannel<AngelInfo>

let ping =
  MailboxProcessor.Start(
    fun agent ->
      let rec inner (angels : MailboxProcessor<AngelMessage> list) infos =
        async {
          // Ask the angels where they will be next
          let! newInfos =
            angels
            |> List.map (fun angel -> angel.PostAndAsyncReply (fun r -> Next(infos, r)))
            |> Async.Parallel

          let newInfos = newInfos |> List.ofArray

          // Erase old locations
          do!
            infos
            |> List.map (fun { Position = p } -> p)
            |> List.map (fun p -> setAsync (int p.x) (int p.y) 0 ' ')
            |> Async.Parallel
            |> Async.Ignore

          // Draw new locations
          do!
            newInfos
            |> List.map (fun { Position = p } -> p)
            |> List.map (fun p -> setAsync (int p.x) (int p.y) 15 '*')
            |> Async.Parallel
            |> Async.Ignore

          do! Async.Sleep 100
          return! inner angels newInfos
        }
      let init () =
        async {
          // Wait for angels to be passed in
          let! (msg : MailboxProcessor<AngelMessage> list) = agent.Receive()

          let! infos =
            msg
            |> List.map (fun angel -> angel.PostAndAsyncReply Init)
            |> Async.Parallel

          return! inner msg (infos |> List.ofArray)
        }
      init ()
    )
```

This agent is a bit more chunky. If you look down to the end of the body, you'll see it starts
by calling ``init``. This method is responsible for waiting for the initial list of angels that
will populate our night sky. The angels themselves will be agents that listen for the AngelMessage
type.

``init`` sends an ``Init`` message to each angel, asking it for it's initial position and velocity.
The message consists solely of a reply channel which the angel will use to pass back the information.

Once all the angels have reported in, we pass control to the recursive inner loop. On each round
through, the ``ping`` agent asks every angel where it's moving to. It then writes spaces to every square on the console that held an angel last
tick, and finally draws the new positions of every angel.

And most of our infrastructure is in place! Let's test it with a collection of angels that will
start with a random position and velocity and move in a straight line for a while.

``` fsharp
let xSeq  = randSeq randX xZero (width + xZero - 1)
let ySeq  = randSeq randY yZero (height + yZero - 1)
let vxSeq = randSeq randX -5 5
let vySeq = randSeq randY -5 5

let createAngel logic angelInfo =
  MailboxProcessor.Start(
    fun agent ->
      let rec inner currentInfo =
        async {
          let! msg = agent.Receive()
          return!
            match msg with
            | Init r ->
              r.Reply currentInfo
              inner currentInfo
            | Next (infos, r) ->
              let newInfo = logic currentInfo infos
              r.Reply newInfo
              inner newInfo
        }
      inner angelInfo)

let angels =
  Seq.zip (Seq.zip xSeq ySeq) (Seq.zip vxSeq vySeq)
  |> Seq.take 10
  |> Seq.map
      (fun ((px, py), (vx, vy)) ->
        { Position = { x = float px; y = float py }; Velocity = { x = float vx; y = float py }})
  |> Seq.map (createAngel (fun c _ -> { c with Position = c.Position + c.Velocity }))
  |> Seq.toList

// Start the whole thing off
ping.Post angels

Console.ReadLine()

Console.ForegroundColor <- ConsoleColor.White
Console.CursorVisible <- true
```

Each of our angels knows how to report its initial state, and how to apply a function called ``logic`` to it's previous state to generate the new position. For testing, the ``logic`` we're passing in is just to add its velocity to it's current position each time its asked.

Full listing is in [advent2.fsx](https://github.com/mavnn/advent2015/blob/master/advent2.fsx), and running it should give us something like this:

<img src="/images/angels3.gif"/>

> Suddenly a great company of the heavenly host appeared with the angel, praising God and saying,
>
> “Glory to God in the highest heaven,
>    and on earth peace to those on whom his favor rests.” <ref><a href="https://www.biblegateway.com/passage/?search=luke+2:13-14&version=NIV" title="Luke 2:13-14">Luke 2:13-14</a></ref>

### Adding some dancing

But! Angels in straight lines doesn't sound much fun. We'll make our angels a bit more interesting
by implementing a simple <a href="https://en.wikipedia.org/wiki/Boids">boid</a> variant.

First we'll add the ability to specify a colour as part of our angel info (check the full listing for details). We'll also expand the vectors to implement multiplication, division and a magnitude limit.

Then we can add a ``logic`` module:

``` fsharp
module Logic =
  let private surrounding radius (us : AngelInfo) (others : AngelInfo list) =
    others
    |> List.filter (fun a -> Vector2.abs (a.Position - us.Position) < radius)

  let private desiredVel angels =
    angels
    |> List.fold
        (fun (v, i) angel ->
          (angel.Velocity + v, i + 1)) ({ x = 0.; y = 0.}, 0)
    |> fun (v, i) ->
        match i with
        | 0 ->
          { x = 0.; y = 0. }
        | _ ->
          { x = v.x / float i; y = v.y / float i }

  let private avoid this angels =
    let dodge v =
      { x = 1. / v.x * -1.
        y = 1. / v.y * -1. } * (List.length angels |> float)
    match angels with
    | [] | [_] -> { x = 0.; y = 0. }
    | _ ->
      angels
      |> List.map (fun angel -> angel.Position - this.Position)
      |> List.reduce (+)
      |> dodge

  let boid midpoint friendRadius dodgeRadius maxAcc maxVel this angels =
    let groupVel =
      surrounding friendRadius this angels
      |> desiredVel
      |> Vector2.limit maxVel
    let avoidCollision =
      surrounding dodgeRadius this angels
      |> avoid this
      |> Vector2.limit maxVel
    let towardsMiddle =
      midpoint - this.Position
      |> Vector2.limit maxVel
    let acceleration =
      (groupVel * 0.5 + avoidCollision * 2. + towardsMiddle)
      / 3.
    { this with Position = this.Position + this.Velocity
                Velocity = (this.Velocity + acceleration) |> Vector2.limit maxVel }

  let stationary this _ =
    { this with Velocity = { x = 0.; y = 0. } }
```

Nothing super exciting here individually - we have methods for discovering other angels nearby
(``surrounding``), the average velocity of a group of angels (``desiredVel``) and a rough guess
at not running into a group of nearby angels (``avoid``). All could probably be improved!

Putting it all together, the ``boid`` method calculates the acceleration the angel would "like" to
have to follow all if its rules fully, and then limits that by a specified maximum acceleration.
I played with the weighting of the rules a bit to get something that looked kind of nice, and also
decided to make my life easier by aiming cohesion towards the middle of the screen rather than the
middle of the flock.

Generating our angels is now just a case of partially applying boid with the parameters of our
choice:

``` fsharp
let angels =
  Seq.zip3 (Seq.zip xSeq ySeq) (Seq.zip vxSeq vySeq) cSeq
  |> Seq.take 40
  |> Seq.map
      (fun ((px, py), (vx, vy), c) ->
       { Position = { x = float px; y = float py }
         Velocity = { x = float vx; y = float vy }
         Colour   = c })
  |> Seq.map (createAngel (Logic.boid midpoint 10. 1. 0.3 1.))
  |> Seq.append
      [(createAngel
         Logic.stationary { Position = midpoint
                            Velocity = { x = 0.; y = 0. }
                            Colour   = 15 })]
  |> Seq.toList
```

The ones in listing [advent3.fsx](https://github.com/mavnn/advent2015/blob/master/advent3.fsx) give something reasonably nice, looking like:

<img src="/images/angels4.gif"/>

One word of warning: there's a bug in the avoidance which I haven't had a chance to track down,
so if you add too many angels they'll all push each other into the top left corner. Oops.

And that's all for now. I hope you enjoyed this brief dive into agent based programming,
and how we can use agents to separate responsibility and protect against unwanted race conditions.

As you can see, this framework allows easy modification of angel logic, and in fact allows for
every angel to have its own implementation without much added complexity - as long as it replies to
the same messages.

Happy Christmas, and God bless.
