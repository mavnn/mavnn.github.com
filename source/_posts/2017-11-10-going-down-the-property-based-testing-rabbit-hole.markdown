---
layout: post
title: "Going Down the Property Based Testing Rabbit Hole"
date: 2017-11-10 15:28:47 +0000
comments: true
categories: [fsharp, fscheck]
---
Image, if you will, a card game.

(Don't worry, there's code later. Lots of code.)

It's not a complex card game; it's a quick and fun game designed to represent over the top martial arts combat in the style of Hong Kong cinema or a beat 'em up game.

Each player has a deck of cards which represent their martial art; different arts are differently weighted in their card distribution. These cards come in four main types:

### 1 Normal cards

A "normal" card comes in one of four suits:

* Punch
* Kick
* Throw
* Defend

They also carry a numerical value between 1 and 10, which represents both how "fast" they are and (except for defend cards) how much damage they do. A Defend card can never determine damage.

### 2 Special Attack cards

The fireballs, whirling hurricane kicks and mighty mega throws of the game. A special attack card lists two suits: one to use for the speed of the final attack, and one for the damage. This allows you to play 3 cards together to create an attack which is fast yet damaging.

### 3 Combo Attack cards

A flurry of blows! Combo cards also list two suits: one for speed, and one for the "follow up" flurry. This allows you to play 3 cards together, one of which determines the speed of the attack while the other adds to the total damage. For example, if you play a Punch/Kick Combo with a Punch 3 and a Kick 7 you end up with a speed 3, damage 10 attack.

### 4 Knockdown cards

You can combine a knockdown card with any other valid play to create an action that will "knockdown" your opponent.

## The code

(This is an *example* of property based testing; if you need an *introduction* first, check out [Breaking Your Code in New and Exciting Ways](/fscheck-breaking-your-code-in-new-and-exciting-ways/) or the [the video version](/sdd-conf-2015/))

There are of course other rules to the game; but let's assume for a moment we're coding this game up in F#. We've defined a nice domain model:

``` fsharp
module BlackBelt.Domain.Types

open System

type Suit =
    | Punch
    | Kick
    | Throw
    | Defend

type NormalCard =
    { Suit : Suit
      Value : int }

type ComboCard =
    { SpeedSuit : Suit
      FollowUpSuit : Suit }

type SpecialAttackCard =
    { SpeedSuit : Suit
      DamageSuit : Suit }

type Card =
    | Normal of NormalCard
    | Combo of ComboCard
    | Special of SpecialAttackCard
    | Knockdown

type Action =
    { Speed : int
      Damage : int
      Suit : Suit
      Knockdown : bool }

type PlayerId = PlayerId of string

type Player =
    { Name : string
      Id : PlayerId
      Deck : Card list
      Stance : Card list
      Health : int }

type WaitingFor =
    | Attack
    | Counter of PlayerId * Action
    | StanceCard

type Game =
    { GameId : Guid
      Player1 : Player
      Player2 : Player
      TurnOf : PlayerId
      WaitingFor : WaitingFor }
```

And now we want to write a function that takes the rules for playing cards above, and turns a `Card list` into an `Action option` (telling you if the list is a valid play, and what action will result if it is).

This function is pretty critical to the overall game play, and may well also be used for validating input in the UI so getting it right will make a big difference to the experience of playing the game.

So we're going to property test our implementation in every which way we can think of...

First step: make yourself a placeholder version of the function to reference in your tests:

``` fsharp
module BlackBelt.Domain.Logic

let toAction cards = None
```

Now, let's start adding properties. All of the rest goes in a single file, but I'm going to split it up with some commentary as we go.

``` fsharp
module BlackBelt.Tests.Logic

open Expecto
open Expecto.ExpectoFsCheck
open FsCheck
open BlackBelt.Domain.Logic
open BlackBelt.Domain.Types

let allSuitsBut suit =
    [Punch;Kick;Throw;Defend]
    |> List.filter ((<>) suit)
    |> Gen.elements

// We need a custom generator here as only some
// values are valid
type DomainArbs() =
    static member NormalCard() : Arbitrary<NormalCard> =
        gen {
            let! suit = Arb.generate<Suit>
            let! value = Gen.choose(1, 10)
            return
                { Suit = suit
                  Value = value }
        } |> Arb.fromGen

    static member SpecialAttackCard() : Arbitrary<SpecialAttackCard> =
        gen {
            let! damageSuit = allSuitsBut Defend
            let! speedSuit = Arb.generate<Suit>
            return
                { SpeedSuit = speedSuit
                  DamageSuit = damageSuit }
        } |> Arb.fromGen

    static member ComboCard() : Arbitrary<ComboCard> =
        gen {
            let! speedSuit = allSuitsBut Defend
            let! followupSuit = allSuitsBut Defend
            return
                { SpeedSuit = speedSuit
                  FollowUpSuit = followupSuit }
        } |> Arb.fromGen
```

We'll start off with a few general purpose bits for generating random types in our domain. I haven't gone the whole hog in making illegal states unrepresentable here, so we need to constrain a few things (like the fact that cards only have values from 1 to 10, and that you can't combo into a defend card for extra damage).

Now: let's start generating potential plays of cards. Our properties will be interested in whether a particular play is valid or invalid, and we will want to know what the resulting `Action` should be for valid plays.

So we define a union to create instances of:

``` fsharp
type GeneratedAction =
    | ValidAction of Card list * Action
    | InvalidAction of Card list
```

Now let's add all of the valid actions we can think of.

``` fsharp
let makeNormalAction =
    gen {
        let! normal = Arb.generate<NormalCard>
        let cards = [Normal normal]
        let action =
            { Speed = normal.Value
              Damage =
                  if normal.Suit = Defend then
                      0
                  else
                      normal.Value
              Suit = normal.Suit
              Knockdown = false }
        return cards, action
    }
```

So; a normal card on it's own is always a valid play, the only thing we need to watch out for is that a Defend card causes no damage.

``` fsharp
let makeComboAttack =
    gen {
        let! comboCard = Arb.generate<ComboCard>
        let! normal1 = Arb.generate<NormalCard>
        let! normal2 = Arb.generate<NormalCard>
        let cards =
            [ Normal { normal1 with Suit = comboCard.SpeedSuit }
              Normal { normal2 with Suit = comboCard.FollowUpSuit }
              Combo comboCard ]
        let attack =
            { Speed =
                  if comboCard.SpeedSuit = comboCard.FollowUpSuit then
                      min normal1.Value normal2.Value
                  else
                      normal1.Value
              Damage = normal1.Value + normal2.Value
              Suit = comboCard.SpeedSuit
              Knockdown = false }
        return cards, attack
    }
```

Here we'll generate the combo card and two other cards, and then we'll override the suit of the two normal cards to ensure they're legal to be played with the combo card.

There's a quirk here (which in reality I noticed after trying to run these tests). If the two suits are the same, the fast card should determine the speed regardless of "order".

``` fsharp
let makeSpecialAttack =
    gen {
        let! specialCard = Arb.generate<SpecialAttackCard>
        let! damageValue = Gen.choose(2, 10)
        let! speedValue = Gen.choose(1, damageValue - 1)
        let cards =
            [ Normal { Suit = specialCard.SpeedSuit; Value = speedValue }
              Normal { Suit = specialCard.DamageSuit; Value = damageValue }
              Special specialCard ]
        let attack =
            { Speed = speedValue
              Damage = damageValue
              Suit = specialCard.SpeedSuit
              Knockdown = false }
        return cards, attack
    }
```

Special attack cards have an additional constraint: playing a high value speed card with a low value damage card would actually *disadvantage* the player, and so is not considered a valid play.

``` fsharp
let makeKnockdownAttack =
    gen {
        let! cards, baseAttack =
            Gen.oneof [ makeNormalAction
                        makeComboAttack
                        makeSpecialAttack ]
        let cards = Knockdown::cards
        let attack = { baseAttack with Knockdown = true }
        return cards, attack
    }
```

Here we make use of the generators we've constructed above to create a Knockdown action.

``` fsharp
let makeValidAction =
    gen {
        let! validAction =
            Gen.oneof [ makeNormalAction
                        makeComboAttack
                        makeSpecialAttack
                        makeKnockdownAttack ]
        return ValidAction validAction
    }
```

Which allows us to write a `ValidAction` generator.

Now, more interesting is trying to generate plays which are not valid. We're not trusting the UI to do any validation here, so let's just come up with everything we can think of...

``` fsharp 
let multipleNormal =
    gen {
       let! first = Arb.generate<NormalCard>
       let! normals = Gen.nonEmptyListOf Arb.generate<NormalCard>
       return first::normals |> List.map Normal
    }
```

More than one normal card with out an other card to combine them is out.

``` fsharp
let incompleteComboOrSpecial =
    gen {
        let! special =
            Gen.oneof [ Gen.map Combo Arb.generate<ComboCard>
                        Gen.map Special Arb.generate<SpecialAttackCard> ]
        let! other = Arb.generate<Card>
        return [special; other]
    }
```

A combo or special card always requires precisely two normal cards to be a valid play; so here, we only generate one.

``` fsharp
let onlyKnockdown =
    Gen.constant [Knockdown]
```

A combo card can only be played as part of an otherwise valid play, and isn't allowed on it's own.

``` fsharp
let unmatchedSpeedCombo =
    gen {
        let! combo = Arb.generate<ComboCard>
        let! normal1 = Arb.generate<NormalCard>
        let! unmatched = allSuitsBut combo.SpeedSuit
        let! normal2 = Arb.generate<NormalCard>
        let n1 = { normal1 with Suit = unmatched }
        return [Combo combo; Normal n1; Normal normal2]
    }

let unmatchedSpeedSpecial =
    gen {
        let! special = Arb.generate<SpecialAttackCard>
        let! normal1 = Arb.generate<NormalCard>
        let! unmatched = allSuitsBut special.SpeedSuit
        let! normal2 = Arb.generate<NormalCard>
        let n1 = { normal1 with Suit = unmatched }
        return [Special special; Normal n1; Normal normal2]
    }

let unmatchedDamageCombo =
    gen {
        let! combo = Arb.generate<ComboCard>
        let! normal1 = Arb.generate<NormalCard>
        let! unmatched = allSuitsBut combo.FollowUpSuit
        let! normal2 = Arb.generate<NormalCard>
        let n2 = { normal2 with Suit = unmatched }
        return [Combo combo; Normal normal1; Normal n2]
    }

let unmatchedDamageSpecial =
    gen {
        let! special = Arb.generate<SpecialAttackCard>
        let! normal1 = Arb.generate<NormalCard>
        let! unmatched = allSuitsBut special.DamageSuit
        let! normal2 = Arb.generate<NormalCard>
        let n2 = { normal2 with Suit = unmatched }
        return [Special special; Normal normal1; Normal n2]
    }
```

There's lots of ways to combine three cards which are not valid combos or specials. Here we use are `allSuitsBut` helper function to always play just the wrong card compared to what's needed.

``` fsharp
let swappedSpecial =
    gen {
        let! specialCard = Arb.generate<SpecialAttackCard>
        if specialCard.SpeedSuit = specialCard.DamageSuit then
            return [Special specialCard]
        else
            let! speedValue = Gen.choose(2, 10)
            let! damageValue = Gen.choose(1, speedValue)
            let cards =
                [ Normal { Suit = specialCard.SpeedSuit; Value = speedValue }
                  Normal { Suit = specialCard.DamageSuit; Value = damageValue }
                  Special specialCard ]
            return cards
    }
```

And here we create special attacks which are slower than they are damaging. If the speed and damage suit are the same, the cards could be used either way around to create a valid action, so instead we just return the Special card on it's own without companions to form a different invalid play.

``` fsharp
let makeInvalidAction =
    gen {
        let! invalidAction =
            Gen.oneof [ multipleNormal
                        incompleteComboOrSpecial
                        onlyKnockdown
                        unmatchedSpeedCombo
                        unmatchedSpeedSpecial
                        unmatchedDamageCombo
                        unmatchedDamageSpecial
                        swappedSpecial ]
        return InvalidAction invalidAction
    }
```

There's more that could be added here, but I decided that was enough to keep me going for the moment and so added my invalid action generator here.

``` fsharp
type ActionArbs() =
    static member GeneratedAction() : Arbitrary<GeneratedAction> =
        gen {
            return! Gen.oneof [
                        makeValidAction
                        makeInvalidAction
                    ]

        } |> Arb.fromGen

let actionConfig =
    { FsCheckConfig.defaultConfig with
        arbitrary = [typeof<DomainArbs>
                     typeof<ActionArbs>] }
[<Tests>]
let toAction =
    testPropertyWithConfig actionConfig "toAction function" <| fun action ->
        match action with
        | ValidAction (cards, action) ->
            Expect.equal (toAction cards) (Some action) "Is an action"
        | InvalidAction cards ->
            Expect.isNone (toAction cards) "Is not an attack"
```

Finally, I wired up the generators and defined the single property this function should obey: it should return the correct action for a valid play, or `None` if the play is erroneous.

## The wrap

Hopefully this is a useful example for those of you using property based tests of how you can encode business logic into them: although this looks like a lot of code, creating even single examples of each of these cases would have been nearly as long and fair less effective in testing.

It does tend to lead to a rather iterative approach to development, where as your code starts working for some of the use cases, you begin to notice errors in or missing cases you need to generate, which helps you find more edges cases in your code and round the circle you go again.

If you want, you're very welcome to take this code to use as a coding Kata - but be warned, it's not as simple a challenge as you might expect from the few paragraphs at the top of the post!
