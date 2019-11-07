---
layout: post
title: "Free Probabilities"
date: 2019-11-06 18:37:04 +0000
comments: true
categories: haskell
---

As the Monty Python crew would say: "Now for something completely different!"

> TL;DR: I'm going to turn a `Monad` of probabilities into a `Free Monad` of probabilities and this is not nearly so scary as it sounds. Also, it's actually useful!

I've been using a bit more Haskell recently, and after watching a demo from a [colleague](https://twitter.com/schtoeffel) I wanted to solve a problem that's been bouncing around my brain for a while.

I do a fair bit of both game playing and game design (in the board game and tabletop roleplaying sense of 'game'), and I'm often interested in either generating random values or investigating how likely the result of a random process is.

Let's give an example; if I model a dice roll with the "spread" of possible outcomes, it might look like this:

``` haskell
{-# LANGUAGE DeriveFunctor #-}

import Protolude
import Data.Ratio

type Probability = Ratio Integer

newtype Spread a =
  Spread [(a, Probability)]
  deriving (Show, Eq, Functor)
  
dice :: Spread Integer
dice = Spread [(1, 1 % 6)
              ,(2, 1 % 6)
              ,(3, 1 % 6)
              ,(4, 1 % 6)
              ,(5, 1 % 6)
              ,(6, 1 % 6)
              ]
```

<!-- more -->

This basically just means that if I roll that dice, I have a 1 in 6 chance of rolling any of the 6 numbers. Now, there are rules for combining conditional probabilities: let's start adding these in.

Haskell has basically given us one for free; if something always happens, we can adjust all of the potential outcomes to incorporate the "something". This can be modeled by being able to `map` over the values in our `Spread`.

Let's add 10 to our dice roll, regardless of what's rolled:

``` haskell
-- λ> fmap ((+) 10) dice
Spread [(11,1 % 6),(12,1 % 6),(13,1 % 6),(14,1 % 6),(15,1 % 6),(16,1 % 6)]
```

So far, so good. Let's see if we can take this a bit further; turn `Spread` into an `Applicative`.

``` haskell
instance Applicative Spread where
  pure v = Spread [(v, 1 % 1)]
  (Spread fs) <*> (Spread xs) =
    Spread [(f x, p1 * p2) | (f, p1) <- fs, (x, p2) <- xs]
```

Here we set up two things; first, `pure` enables us to take any individual value and turn into a `Spread` of that value. From a logical point of view, the total probability of all of the items in a spread must add up to "1" (we'll enforce that with smart constructors later) so there's only one choice here. `pure` returns a `Spread` with a single item in it - probability of that outcome? Certain.

`<*>` is the operator that allows us to take a `Spread` of functions `a -> b` and a `Spread` of inputs `a` and return a `Spread b`. Hmm. How should that work?

Well, to work out the probability of an event A which is conditional on event B, you just multiply the two probabilities together. So `<*>` turns out to be reasonably straight forward: you take all possible combinations of functions and inputs, and return each output with a probability of (probability of function * probability of input).

So that's done, but doesn't look immediately useful. It does, however, allow us to escalate one more level: `Monad`.

``` haskell
instance Monad Spread where
  (>>=) = bind

bind :: Spread a -> (a -> Spread b) -> Spread b
bind (Spread xs) f = Spread $ concatMap concatinate xs
  where
    combineConditional (Spread children, parentProb) =
      map (\(v, prob) -> (v, parentProb * prob)) children
    concatinate (v, p) = combineConditional (f v, p)
```

So we're back on conditional probabilities again. We take each of our values from the input spread and apply our function to it. Then we multiply the probability of the outcome in the "child" spread with the probability of the "parent" input - and finally we concatinate the whole lot back together into a single list and wrap it up in `Spread` again.

The way the laws of probability (and, well, fraction multiplication) work, if the total probability in each of our `Spread`s is 1, the total probability across all of our outcomes after a bind will also be 1. Neat! Now we have something we can use.

Let's add 10 to every dice that rolls more than 3!

``` haskell
weirdRoll :: Spread Integer
weirdRoll = do
  roll <- dice
  if roll > 3 then
    pure (roll + 10)
  else
    pure roll
    
-- Spread [(1,1 % 6),(2,1 % 6),(3,1 % 6),(14,1 % 6),(15,1 % 6),(16,1 % 6)]
```

This is starting to look good.

We do have a problem though: this is a very useful representation for when we want to know every possible outcome and it's probability of happening - but that's not always desirable, or possible.

Let's take a famous example; a game where you flip a coin. If it comes up tails it pays out £1.00 - if you get heads you pay again with double the pay out. How much do you want to pay to take part in this game?

``` haskell
doubleOnHeads :: Integer -> Spread Integer
doubleOnHeads last = do
  isTails <- Spread [(True, 1 % 2), (False, 1 % 2)]
  if isTails then
    pure last
  else
    doubleOnHeads (last * 2)
```

Which promptly creates an infinite last of possible outcome states. In an other use case, it can be nice to just pick an outcome from the sample space. For example, if I want to model how much damage a warrior in my Pathfinder game does with a long sword I may want to look at the probability spread... or I might just want to pick a result at random.

So I want to take this existing monadic data structure, but execute it with different execution strategies. Which meant when someone at work mentioned `Free` monads in a demo and mentioned that they capture the shape of a monad without executing it, my ears pricked up.

The theory says that we can take any `Functor` and turn it into a `Free Monad`; so turning a `Monad` into a `Free Monad` must be even easier, no?

``` haskell
import Control.Monad.Free

type Prob = Free Spread
```

Well, the first step is pretty straight forward. Now we can create `Prob` representations of dependent probabilities just like before!

Let's have a few functions to create `Spread`s which are both guaranteed to be "meaningful" and lifted into our new `Prob` type.

``` haskell
-- Turn a list of equally likely outcomes into a `Prob`
ofList :: [a] -> Prob a
ofList xs =
  let denom = fromIntegral $ length xs
   in lift $ Spread $ map (, 1 % denom) xs

-- Turn a single outcome into a one item `Prob` with likelyhood of "1"
certain :: a -> Prob a
certain = pure

-- Turn a list of outcomes with relative likehood to each other
-- into a `Prob`
ofWeightedList :: [(a, Integer)] -> Prob a
ofWeightedList xs =
  let denom = sum $ map snd xs
   in lift $ Spread $ map (\(v, w) -> (v, w % denom)) xs
```

Now we can rewrite our previous example:

``` haskell
weirdRoll2 :: Prob Integer
weirdRoll2 = do
  roll <- ofList [1..6]
  if roll > 3 then
    pure (roll + 10)
  else
    pure roll
```

Success! Kind of. This looks great, and type checks, but I can't actually evaluate the result any more.

Let's see if we can deal with that. The `Control.Monad.Free` library provides a hopefully named function called `iterM`.

The full type annotation looks like this:

```
iterM :: (Monad m, Functor f) => (f (m a) -> m a) -> Free f a -> m a
```

Ouch. Well, we have a `Monad` we want to turn things into (`Spread`). And we have the `Functor` which our `Free Spread` is created from which is... `Spread`. So let's start plugging in names:

```
iterM :: (Spread (Spread a) -> Spread a) -> Free Spread a -> Spread a
```

Looking carefully, it looks like all I actually need to supply is a function `(Spread (Spread a)) -> Spread a`. Let's see if we can find an easy way to do that in [Hoogle](https://hoogle.haskell.org/), a search engine that allows us to search for function signatures.

Searching for [Monad m => (m (m a)) -> m a][1] turns up `join` which is already part of the `Monad` type class. Abstraction for the win!

``` haskell
getSpread :: Prob a -> Spread a
getSpread = iterM join

isWorking :: Bool
isWorking = getSpread weirdRoll2 == weirdRoll
-- True
```

Good stuff. Now life gets really interesting. Let's add in ways of picking a single sample out of a `Prob` without evaluating the entire outcome space.

First, we need a way of picking a single outcome from a `Spread`. We'll break it down into two functions; `pickFromSpread` starts from the knowledge that the probabilities in a `Spread` always add up to 1:

``` haskell
pickFromSpread :: Spread a -> IO a
pickFromSpread (Spread xs) =
  pickSample (1 % 1) xs
```

It has a return type of `IO a` because picking a random value means the function is not referentially transparent.

Our second function decides whether to take pick the first sample from a list of `[(a, Probability)]` based on the Probability of the first item compared to the total of all of the Probabilities in the list. We pass in the total of the remaining probabilities as an argument each time, as the list may be infinite so we don't want to `sum` across it.

``` haskell
import "random" System.Random

pickSample :: Probability -> [(a, Probability)] -> IO a
pickSample totalProb ((outcome, prob):rest) = do
  -- rescale our probability to be out of "1"
  let actualProbability = prob / totalProb
  let n = numerator actualProbability
  let d = denominator actualProbability
  pick <- randomRIO (1, d)
  if pick <= n
    then pure outcome
    else pickSample (totalProb - prob) rest
pickSample _ [] = panic "This shouldn't ever happen! Oops."
```

We can now go from `Spread a` to `IO a`. Let's plug that into `iterM`'s type signature again and see what we get:

```
iterM :: (Monad m, Functor f) => (f (m a) -> m a) -> Free f a -> m a

(m = IO a, f = Spread a)

iterM :: (Spread (IO a) -> IO a) -> Free Spread a -> IO a
```

This looks pretty similar to before, where we used `join` to unwrap nested `Spread` structures. If we could turn that `Spread (IO a)` into a `IO (IO a)` than we could call `join` with it - which we can, because that's exactly what `pickFromSpread` does!

``` haskell
getSample :: Prob a -> IO a
getSample = iterM (join . pickFromSpread)
```

Now we can call start pulling random samples out of a `Prob`:

``` haskell
-- λ> getSample weirdRoll2
15
-- λ> getSample weirdRoll2
2
-- λ> getSample weirdRoll2
3
```

This is very fast, and even works well on infinitely recursive definitions like our coin flip above:

``` haskell
-- λ> getSample $ lift (doubleOnHeads 1)
1
-- λ> getSample $ lift (doubleOnHeads 1)
32
-- λ> getSample $ lift (doubleOnHeads 1)
4
-- λ> getSample $ lift (doubleOnHeads 1)
2
```

This technique begins to look interesting when you realize that this technique allows you to take *anything* implemented as a `Functor` and supply an alternative execution method. Want to supply test values in your test instead of values from `IO`? This might just let you do that.

That's basically all for now, but I will leave you with a final example.

First, a function that makes all of this usable in practice; the `normalize` function takes a `Spread` and groups together repeats of the same outcome into a single value:

``` haskell
import qualified Data.HashMap.Strict as HM

normalize :: (Eq a, Hashable a) => Prob a -> Prob a
normalize =
  let spreadNorm (Spread xs) =
        Spread $
        HM.toList $ foldr (\(v, p) acc -> HM.insertWith (+) v p acc) HM.empty xs
   in lift . spreadNorm . retract
```

Then a model of an attack in Pathfinder (1st edition), modeling a strike with a weapon against a foe and building in things like critical hits:

``` haskell
import Probability -- the code from above
import Protolude

diceRoll :: Integer -> Prob Integer
diceRoll faces = ofList [1 .. faces]

d4 :: Prob Integer
d4 = diceRoll 4

d6 :: Prob Integer
d6 = diceRoll 6

d8 :: Prob Integer
d8 = diceRoll 8

d10 :: Prob Integer
d10 = diceRoll 10

d12 :: Prob Integer
d12 = diceRoll 12

d20 :: Prob Integer
d20 = diceRoll 20

roll :: Integer -> Prob Integer -> Integer -> Prob Integer
roll numDice dice mod' =
  normalize $ do
    dieRolls <- traverse identity (replicate (fromIntegral numDice) dice)
    pure $ sum dieRolls + mod'

data Attack = Attack
  { attackDamage :: Prob Integer
  , attackCritRange :: Integer
  , attackCritMult :: Integer
  , attackAccuracy :: Integer
  }

data Defense = Defense
  { armorClass :: Integer
  , damageReduction :: Integer
  }

longSword :: Integer -> Integer -> Attack
longSword accBonus damBonus =
  Attack
    { attackDamage = roll 1 d8 damBonus
    , attackCritRange = 19
    , attackCritMult = 2
    , attackAccuracy = accBonus
    }

data HitResult
  = Critical
  | Hit
  | Miss

isHit :: Attack -> Defense -> Prob HitResult
isHit attack defense = do
  let doesHit rollToHit =
        case rollToHit of
          1 -> False
          20 -> True
          x -> x + attackAccuracy attack > armorClass defense
  toHit <- roll 1 d20 0
  if doesHit toHit
    then do
      confirmCrit <- roll 1 d20 0
      if doesHit confirmCrit
        then pure Critical
        else pure Hit
    else pure Miss

resolveAttack :: Attack -> Defense -> Prob Integer
resolveAttack attack defense =
  normalize $ do
    hit <- isHit attack defense
    case hit of
      Miss -> pure 0
      Hit -> attackDamage attack
      Critical -> do
        damages <-
          traverse
            identity
            (replicate
               (fromIntegral $ attackCritMult attack)
               (attackDamage attack))
        pure $ max 0 (sum damages - damageReduction defense)
```

With some results:

``` haskell
-- λ> getSpread $ resolveAttack (longSword 5 2) (Defense 15 0)
Spread 
  [(0,1 % 2)
  ,(16,5 % 256)
  ,(17,1 % 64)
  ,(18,3 % 256)
  ,(3,1 % 32)
  ,(19,1 % 128)
  ,(4,1 % 32)
  ,(20,1 % 256)
  ,(5,1 % 32)
  ,(6,9 % 256)
  ,(7,5 % 128)
  ,(8,11 % 256)
  ,(9,3 % 64)
  ,(10,13 % 256)
  ,(11,3 % 128)
  ,(12,7 % 256)
  ,(13,1 % 32)
  ,(14,7 % 256)
  ,(15,3 % 128)
  ]

-- λ> getSample $ resolveAttack (longSword 5 2) (Defense 15 0)
12
-- λ> getSample $ resolveAttack (longSword 5 2) (Defense 15 0)
15
-- λ> getSample $ resolveAttack (longSword 5 2) (Defense 15 0)
0
-- λ> getSample $ resolveAttack (longSword 5 2) (Defense 15 0)
0
```

I hope you've enjoyed this brief visit to useful abstractions in Haskell; it's definitely a language where as you learn it you realise that you have great power, and great responsibility to the next maintainer!

  [1]: https://hoogle.haskell.org/?hoogle=Monad%20m%20%3D%3E%20(m%20(m%20a))%20-%3E%20m%20a
