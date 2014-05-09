---
layout: post
title: "Functionally SOLID 2"
date: 2014-05-09 13:43:02 +0100
comments: true
categories: [fsharp, programming, 15below]
---

*This post follows on directly from [Going Functionally SOLID](/going-functionally-solid)*

In our first session looking at [SOLID](http://en.wikipedia.org/wiki/Solid_%28object-oriented_design%29) and functional programming, we tried to apply some SOLID principles to an example piece of code.

We ended up with a set of interfaces like those below, and robot classes could then implement the interfaces to define their capabilities and state. I mentioned the example code was for a giant robot game, yes?

<!-- more -->

```fsharp
type IDestructable =
    abstract Armour : int
    abstract Dodge : int
    abstract Hits : int
    abstract Destroyed : bool
    abstract TakeDamage : int -> IDestructable

type IWalk =
    abstract Walk : Direction * int -> Location

type IJump =
    abstract Jump : Direction * int -> Location

type IFly =
    abstract Fly : Direction * int -> Location

type IHazWeapon =
    abstract Fire : IDestructable * int -> IDestructable

type IHazWeapons =
    abstract WMDs : List<IHazWeapon>

type IHazCannon =
    inherit IHazWeapon

type IHazMissiles =
    inherit IHazWeapon

type ITransforming =
    abstract Mode : string
    abstract ``Transform!`` : string -> ITransforming
```

For anyone who's worked with SOLID OO code before, this should be looking fairly familiar, and it should be obvious how you could build a class that accepted implementations of these interfaces in it's constructor and then carried the state of the robot (location, hits remaining, etc) around as mutable fields.

But... this is a turn based game, and we've decided that we want to use a [minimax](en.wikipedia.org/wiki/Minimax) approach to choosing moves for the computer player. Minimax is effectively a tree search, which means that implementing it looks like it would be a prime moment for a bit of concurrency. Each branch of the tree can be calculated independently, after all.

Unfortunately... our SOLID OO approach is not looking very thread safe. Functional programming revolves around the idea that code is [referentially transparent](http://en.wikipedia.org/wiki/Referential_transparency_%28computer_science%29) and that data types are [immutable](http://en.wikipedia.org/wiki/Immutable_object). These two properties immediately lead to thread safe code.

So the rest of the session was spent trying out how different parts of the API code be modelled in a more functional way - splitting out state into separate immutable value objects, using functions in the place of single method interfaces and playing with discriminated unions (not strictly functional programming related, but they do seem to crop up regularly in functional style languages).

The end results, raw from the discussion, are below. A bit of a mix of the "interface" and experiments in how you would use it. I think it came out quite nicely, showing how all of the SOLID principles (apart from maybe "L"!) fall out naturally in nicely designed functional code just as they do in good OO code. In fact some of them, such as "Interface Segregation" and "Single Responsibility" are things you almost have to work to avoid - they both fall out naturally from passing around
pure functions to implement behaviour.

```fsharp
type Destructable =
    {
        Armour : int
        Dodge : int
        Hits : int
        Destroyed : bool
    }

// Interface segregation and 
// Single responsibility at work
type WeaponFunc =
    Destructable -> int -> Destructable

type Weapon =
    | Missile of WeaponFunc
    | Cannon of WeaponFunc

type MoveFunc =
    Location -> (Direction * int) -> Location

type Move =
    | Run of MoveFunc
    | Jump of MoveFunc
    | Fly of MoveFunc
    
type Robot =
    {
        Id : string
        MovementTypes : Move list
        Weapons : Weapon list
        Location : Location
        DamageStatus : Destructable
    }

// Dependency inversion!
let GiantRobo =
    {
        Id = "GiantRobo"
        MovementTypes = [ Run <| fun l m -> l ]
        Weapons = [ Cannon <| fun d i -> d ]
        Location = { Position = (0, 0); Altitude = 0 }
        DamageStatus = { Armour = 10; Dodge = 5; Hits = 100; Destroyed = false }
    }

// Open/closed principle via higher order
// functions
let makeFly runFunc l m =
    let newPosition = runFunc l m
    { newPosition with Altitude = 100 }

let TinyRobo =
    {
        Id = "TinyRobo"
        MovementTypes = [ Run <| fun l m -> { l with Position = (10, 10) } ]
        Weapons = [ Cannon <| fun d i -> d ]
        Location = { Position = (0, 0); Altitude = 0 }
        DamageStatus = { Armour = 10; Dodge = 5; Hits = 100; Destroyed = false }
    }


// Separating behaviour and state
module BlowThingsUp =
    let TakeDamage destructable damage =
        let newHits = destructable.Hits - damage
        {   destructable with
                Hits = newHits
                Destroyed = newHits <= 0
        }
            
// Different possibilities for
// extending that would normally be handled
// by inheritance in OO
module TransformVF1 =
    let transform robot =
        {
            robot with
                MovementTypes = [Fly <| fun l m -> { l with Altitude = 100 }]
        }
 
type TransformFunc =
    Robot -> Robot

type RobotModel =
    | NormalRobot of Robot
    | TransformingRobot of Robot * TransformFunc

type MaybeTransformFunc =
    MaybeTransformingRobot -> MaybeTransformingRobot

and MaybeTransformingRobot =
    {
        Id : string
        MovementTypes : Move list
        Weapons : Weapon list
        Location : Location
        DamageStatus : Destructable
        Transform : MaybeTransformFunc option
    }

let Transform mtr =
    match mtr.Transform with
    | None ->
        mtr
    | Some trans ->
        trans mtr
```

Enjoy, and comments welcome - this was live coded in a group environment, so I'm sure plenty of opportunities for nicer code were missed!

