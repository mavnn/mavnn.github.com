---
layout: post
title: "Going Functionally SOLID"
date: 2014-04-11 11:45:47 +0100
comments: true
categories: [fsharp, programming, 15below]
---

*The one giant robot every programmer should know and love! Meet Big O!*

![Big O](/images/Big_o.jpg)

*For all your algorithmic complexity needs. And any giant mecha in need of a good pounding.*

And now, back to your regularly scheduled blog post...

Inspired both by [Mark Seemann's excellent blog post](http://blog.ploeh.dk/2014/03/10/solid-the-next-step-is-functional/) and by my ongoing campaign to introduce functional programming techniques to [15below](http://www.15below.com/) developers who aren't familiar with them yet, I decided it was time to run a mini-series on applying good principles like [SOLID](http://en.wikipedia.org/wiki/Solid_%28object-oriented_design%29) in a functional world.

We run weekly one hour "Developer Education" sessions. For this series I started with a badly written piece of code (it came naturally, given I had limited prep time...) in a style of someone who has kind of heard about SOLID and functional programming:

* __SOLID__: "So, eh, I need some interfaces and things. Concrete bad, interface good. In wonder what the whole DI thing is?"
* __Functional__: "And, erm. Chainable functions? Fluent APIs, maybe? That's kind of functional, right?"

<!-- More -->

And then we had a open house suggesting modifications to the code where I made the changes live as we went along. In this first session, we only got as far as making the code a bit more solid - tune back in next month for the make it functional session..

Deciding that we needed a more interesting example domain than sending emails for once, I decided to go the whole hog. Below you'll find the before and after versions of "HeavyGearSOLID"'s unit representation code.

Because everything is better with giant robots.

The session was a fun change of pace from other things we've done, and sparked off a nice bit of discussion (although not as much as I hoped... heckle more, 15below people!). I'm quite looking forward to the next part of the series.

## Before

``` fsharp
namespace ``メタルギアソリッド``

open System
open Utils

type IMecha =
    abstract Walk : Direction * int -> IMecha
    abstract Jump : Direction * int -> IMecha
    abstract Fly : Direction * int -> IMecha
    abstract Position : int * int
    abstract Hits : int
    abstract Destroyed : bool
    abstract Dodge : int
    abstract Armour : int
    abstract TakeDamage : int -> IMecha
    abstract FireCannon : IMecha * int -> IMecha
    abstract FireMissiles : IMecha * int -> IMecha

type GiantRobo (position) =
    let _position = ref position
    let _hits = ref 100
    let _destroyed = ref false
    let _dodge = ref 5
    let _armour = ref 20
    let rand = Random()
    interface IMecha with
        member x.Walk (dir, distance) =
            let iMecha = x :> IMecha
            if distance > 4 then
                failwith "GiantRobo is slow!"
            else
                _position := Move (!_position) dir distance
                iMecha
        member x.Jump (_, _) =
            raise <| NotImplementedException("GiantRobo can't jump")
        member x.Fly (_, _) =
            raise <| NotImplementedException("GiantRobo can't fly")
        member x.Position =
            !_position
        member x.Hits =
            !_hits                        
        member x.Destroyed =
            !_destroyed
        member x.Dodge =
            !_dodge
        member x.Armour =
            !_armour
        member x.TakeDamage damage =
            _hits := !_hits - damage
            _destroyed := !_hits <= 0
            x :> IMecha
        member x.FireCannon (target, roll) =
            if roll > target.Dodge then
                target.TakeDamage (max 0 (60 - target.Armour))
            else
                target
        member x.FireMissiles (target, roll) =
            raise <| NotImplementedException("Giant Robo has no missiles")

type ITransformingMecha =
    inherit IMecha
    abstract Mode : string
    abstract ``Transform!`` : string -> ITransformingMecha

type VF1 (position) =
    let _position = ref position
    let _hits = ref 50
    let _destroyed = ref false
    let _dodge = ref 10
    let _armour = ref 10
    let _mode = ref "Battroid"
    interface ITransformingMecha with
        member x.Walk (dir, distance) =
            let iMecha = x :> IMecha
            if !_mode = "Fighter" then failwith "No legs in Fighter mode!"
            if distance > 6 then
                failwith "VF-1 isn't that fast!"
            else
                _position := Move (!_position) dir distance
                iMecha
        member x.Jump (dir, distance) =
            let iMecha = x :> IMecha
            if !_mode = "Fighter" then failwith "Jumping in Fighter mode makes no sense!"
            let maxDistance =
                match !_mode with
                | "GERWALK" -> 8
                | "Battroid" -> 6
                | _ -> failwith "No good"
            if distance > maxDistance then
                failwith "VF-1 isn't that fast!"
            else
                _position := Move (!_position) dir distance
                iMecha
        member x.Fly (dir, distance) =
            let iMecha = x :> IMecha
            if !_mode = "Battroid" then failwith "Battroid mode can't fly"
            let maxDistance =
                match !_mode with
                | "Fighter" -> 20
                | "GERWALK" -> 15
                | _ -> failwith "No good"
            if distance > maxDistance then
                failwith "VF-1 isn't that fast!"
            else
                _position := Move (!_position) dir distance
                iMecha
        member x.Position =
            !_position
        member x.Hits =
            !_hits                        
        member x.Destroyed =
            !_destroyed
        member x.Dodge =
            !_dodge
        member x.Armour =
            !_armour
        member x.TakeDamage damage =
            _hits := !_hits - damage
            _destroyed := !_hits <= 0
            x :> IMecha
        member x.FireCannon (target, roll) =
            if roll > target.Dodge then
                target.TakeDamage (max 0 (20 - target.Armour))
            else
                target
        member x.FireMissiles (target, roll) =
            if roll > (target.Dodge / 2) then
                target.TakeDamage (max 0 (60 - target.Armour))
            else
                target
        member x.Mode =
            !_mode
        member x.``Transform!`` mode =
            match mode with
            | "Fighter" ->
                _mode := "Fighter"
            | "GERWALK" ->
                _mode := "GERWALK"
            | "Battroid" ->
                _mode := "Battroid"
            | _ ->
                failwith "Not a valid VF-1 mode"
            x :> ITransformingMecha
```

## After

``` fsharp
namespace ``メタルギアソリッド``

open System
open Utils

type Location =
    {
        Position : int * int
        Altitude : int
    }

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

type NormalDestructable (hits, dodge, armour) =
    let _hits = ref 100
    let _destroyed = ref false
    let _dodge = ref 5
    let _armour = ref 20
    interface IDestructable with
        member x.Hits =
            !_hits                        
        member x.Destroyed =
            !_destroyed
        member x.Dodge =
            !_dodge
        member x.Armour =
            !_armour
        member x.TakeDamage damage =
            _hits := !_hits - damage
            _destroyed := !_hits <= 0
            x :> IDestructable

type GiantRobo (position, destructable : #IDestructable) =
    let _position = ref position
    member x.Position =
        !_position
    interface IWalk with
        member x.Walk (dir, distance) =
            if distance > 4 then
                failwith "GiantRobo is slow!"
            else
                { Position = Move (!_position) dir distance; Altitude = 0 }
    interface IDestructable with
        member x.Hits = destructable.Hits
        member x.Destroyed = destructable.Destroyed
        member x.Dodge = destructable.Dodge
        member x.Armour = destructable.Armour
        member x.TakeDamage damage = destructable.TakeDamage damage
    interface IHazWeapons with
        member x.WMDs =
            [{ new IHazCannon with 
                member x.Fire (target, roll) =
                    if roll > target.Dodge then
                        target.TakeDamage (max 0 (60 - target.Armour))
                    else
                        target }]

type ITransforming =
    abstract Mode : string
    abstract ``Transform!`` : string -> ITransforming

type VF1 (position) =
    let _position = ref position
    let _mode = ref "Battroid"
    member x.Position =
        !_position
    interface IWalk with
        member x.Walk (dir, distance) =
            if !_mode = "Fighter" then failwith "No legs in Fighter mode!"
            if distance > 6 then
                failwith "VF-1 isn't that fast!"
            else
                { Position = Move (!_position) dir distance; Altitude = 0 }
    interface IJump with
        member x.Jump (dir, distance) =
            if !_mode = "Fighter" then failwith "Jumping in Fighter mode makes no sense!"
            let maxDistance =
                match !_mode with
                | "GERWALK" -> 8
                | "Battroid" -> 6
                | _ -> failwith "No good"
            if distance > maxDistance then
                failwith "VF-1 isn't that fast!"
            else
                { Position = Move (!_position) dir distance; Altitude = 0 }
    interface IFly with
        member x.Fly (dir, distance) =
            if !_mode = "Battroid" then failwith "Battroid mode can't fly"
            let maxDistance =
                match !_mode with
                | "Fighter" -> 20
                | "GERWALK" -> 15
                | _ -> failwith "No good"
            if distance > maxDistance then
                failwith "VF-1 isn't that fast!"
            else
                { Position = Move (!_position) dir distance; Altitude = 0 }
    interface IHazWeapons with
        member x.WMDs =
            [
                { new IHazCannon with
                    member x.Fire (target, roll) =
                        if roll > target.Dodge then
                            target.TakeDamage (max 0 (20 - target.Armour))
                        else
                            target };
                 { new IHazMissiles with
                    member x.Fire (target, roll) =
                        if roll > (target.Dodge / 2) then
                            target.TakeDamage (max 0 (60 - target.Armour))
                        else
                            target }
            ]
    interface ITransforming with
        member x.Mode =
            !_mode
        member x.``Transform!`` mode =
            match mode with
            | "Fighter" ->
                _mode := "Fighter"
            | "GERWALK" ->
                _mode := "GERWALK"
            | "Battroid" ->
                _mode := "Battroid"
            | _ ->
                failwith "Not a valid VF-1 mode"
            x :> ITransforming
```

