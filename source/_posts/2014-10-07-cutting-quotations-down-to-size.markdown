---
layout: post
title: "Cutting Quotations Down to Size"
date: 2014-10-07 21:30:58 +0100
comments: true
categories: [fsharp, quotations]
---

> This is part 2 in my quotations series, following on from [Tap, Tap, Tapping on the Door](/tap/).

As promised in the first part of this series, here we're going to take a look at manipulating quotations. I mean, we've got this [AST](http://en.wikipedia.org/wiki/Abstract_syntax_tree) - now what are we going to do with it?

Let's start with something fairly straightforward; [boolean algebra](http://en.wikipedia.org/wiki/Boolean_algebra).

First, let's get a look at how some boolean expressions are represented in quotations.

Firing up F# Interactive, we'll feed a few in and see what happens:

```fsharp
<@@ true @@>;;
(* val it : Expr =
      Value (true)
        {CustomAttributes = [NewTuple (Value ("DebugRange"),
              NewTuple (Value ("stdin"), Value (4), Value (4), Value (4), Value (8)))];
         Type = System.Boolean;} *)
```

Hmm. That's... not as nice as we might want. The custom attributes are being added by F# interactive for debugging purposes, but hopefully the general shape is clear: our expression consists of a single value of ``true``.

I'll cut out the custom attributes from now on to make reading things a bit easier.

Next!

```fsharp
<@@ true && true @@>;;
(* val it : Expr =
      IfThenElse (Value (true), Value (true), Value (false))
        {CustomAttributes = ...;
         Type = System.Boolean;} *)
```

So. Looks like someone has decided to represent the ``&&`` operator with the expression tree of an ``if`` statement. Useful in some ways; after all, any logic we can apply to an ``&&`` operator will equally apply to a logically equivalent ``if`` statement. Checking the [MSDN documentation for Expr.IfThenElse](http://msdn.microsoft.com/en-us/library/ee370408.aspx) tells if that the 3 values above are ``guard``, ``thenExpr`` and ``elseExpr``. Which kind of makes sense; our ``<@@ true && true @@>`` is being turned (loosely) into ``if true then true else false`` - which is equivalent.

Let's put something other than plain boolean constants in to see if we can make it clearer.

```fsharp
<@@ "b" = "b" && "t" = "t" @@>;;
(* val it : Expr =
      IfThenElse (Call (None, op_Equality, [Value ("b"), Value ("b")]),
                Call (None, op_Equality, [Value ("t"), Value ("t")]), Value (false))
        {CustomAttributes = ...;
         Type = System.Boolean;} *)
```

Looks hopeful. As a last check, let's take advantage of the fact that quotations are structurally comparable to double check our understanding:

```fsharp
<@@ if "b" = "b" then "t" = "t" else false @@> = <@@ "b" = "b" && "t" = "t" @@>;;
(* val it : bool = true *)
```

Awesome!

I'm going to take a wild punt that the ``||`` operator does something similar:

```fsharp
<@@ if "b" = "t" then true else "t" = "b" @@> = <@@ "b" = "t" || "t" = "b" @@>;;
(* val it : bool = true *)
```

And it does. Excellent.

We've now got an idea what the expression trees are going to look like, but how do we go about manipulating them? The answer is the answer we always hope for when traversing data structure in F#: pattern matching.

The ``Expr`` types are all recognized by a set of [active patterns](http://msdn.microsoft.com/en-us/library/ee370259.aspx) in the ``Microsoft.FSharp.Quotations.Patterns`` module. The only problem is that there are about 40 cases in the active patterns, and at the moment we're only interested in one: the ``IfThenElse`` case.

That's sounding rather verbose for a language that's normally as succinct as F# and fortunately the language designers agreed. As well as the specific cases in the main ``Patterns`` module, there are a number of other modules under the ``Microsoft.FSharp.Quotations`` namespace that contain "broader" active patterns, and helper methods for rebuilding expressions.

Let's take the broadest set, from the ``ExprShape`` module, and have a look at a method that takes in an expression, recursively works it way through the tree, and rebuilds it exactly as it was before:

```fsharp
open Microsoft.FSharp.Quotations
open Microsoft.FSharp.Quotations.ExprShape

let rec id q =
    match q with
    | ShapeVar v -> Expr.Var v
    | ShapeLambda (v, e) -> Expr.Lambda(v, id e)
    | ShapeCombination (o, es) ->
        RebuildShapeCombination(o, es |> List.map id)
```

So, as we recurse down there are three possibilities for our expression on any one pass through the ``id`` function:

* We've hit a ``Var``: this is a leaf node holding a variable, we're done with this branch of the tree.
* We've hit a lambda function, with a variable being bound and an expression representing the body of the function. We apply ``id`` to the body to continue recursing down.
* We've hit something else; anything else. The ``ShapeCombination`` pattern knows how to take the structure apart, and the ``RebuildShapeCombination`` method from the same module knows how to use the object ``ShapeCombination`` spits to put it back together again. In the mean time, we still apply ``id`` to all the sub-expressions of the combination, whatever they may be.

(As an aside, don't actually call your functions ``id`` - there's already a function called that in the standard library.)

Of course, on it's own that's not very exciting. But how about if before moving onto these very broad shapes, we first check some specific cases?

Let's see if we can detect ``true`` literals within an expression.

```fsharp
open Microsoft.FSharp.Quotations
open Microsoft.FSharp.Quotations.ExprShape
open Microsoft.FSharp.Quotations.Patterns

let rec detectTrue q =
    match q with
    | Value (o, t) when t = typeof<bool> && (o :?> bool) = true ->
        true
    | ShapeVar _ ->
        false
    | ShapeLambda (_, e) ->
        detectTrue e
    | ShapeCombination (o, es) ->
        es
        |> List.map detectTrue
        |> List.fold (||) false
```

The ``Value`` pattern gives us an object representing a literal and it's type as a tuple. We'll add a guard condition to the pattern to specify that we're only interested when the type is ``bool`` and (taking advantage of short circuiting to make sure we don't try and cast if it's not a bool!) when the value is ``true``. After that, we move back to our broader patterns, but this time we're happy to throw away most of the information at each step as we're not interested in
reconstructing the tree afterwards.

Loading up the function in F# Interactive, we can feed it some test inputs and see how we're doing.

```fsharp
detectTrue <@@ fun x -> true @@>;;
(* val it : bool = true *)
detectTrue <@@ fun x -> false @@>;;
(* val it : bool = false *)
detectTrue <@@ fun x -> false || true @@>;;
(* val it : bool = true *)
detectTrue <@@ fun x y -> y || x true @@>;;
(* val it : bool = true *)
detectTrue <@@ fun x y -> y || x = true @@>;;
(* val it : bool = true *)
detectTrue <@@ "bob" @@>;;
(* val it : bool = false *)
```

Looking good.

Looks like we need just one final step before we start playing with the rules of boolean algebra; let's check we can detect the ``||`` and ``&&`` operators.

First, let's give ourselves some helper active patterns of our own to detect literal ``true`` and ``false`` values:

```fsharp
open Microsoft.FSharp.Quotations
open Microsoft.FSharp.Quotations.ExprShape
open Microsoft.FSharp.Quotations.Patterns


let (|True'|_|) expr =
    match expr with
    | Value (o, t) when t = typeof<bool> && (o :?> bool) = true ->
        Some expr
    | _ ->
        None

let (|False'|_|) expr =
    match expr with
    | Value (o, t) when t = typeof<bool> && (o :?> bool) = false ->
        Some expr
    | _ ->
        None
```

Now, let's add some more for ``||`` and ``&&``:

```fsharp
let (|Or'|_|) expr =
    match expr with
    | IfThenElse (left, True' _, right) ->
        Some (left, right)
    | _ ->
        None

let (|And'|_|) expr =
    match expr with
    | IfThenElse (left, right, False' _) ->
        Some (left, right)
    | _ ->
        None
```

Because you can nest patterns within a pattern match, here we're only matching ``IfThenElse`` expressions where the 'then' clause (``||``) is always ``true`` or the 'else' clause (``&&``) is always ``false``.

And now, with all our pieces in place, let's pick one of the rules of boolean algebra and see if we can apply it. Commutativity sounds like it's probably the simplest:

```fsharp
let commute quote =
    match quote with
    | Or' (left, right) ->
        <@@ %%right || %%left @@>
    | And' (left, right) ->
        <@@ %%right && %%left @@>
    | _ ->
        quote
```

Pretty simple: if we see a ``&&`` or a ``||`` as the top expression in a quotation, swap the arguments. There's no recursion, so we won't go through the tree swapping every ``&&`` or ``||`` expression, although we could if we wanted...

We example:

```fsharp
// basic usage
<@@ true || false @@> = commute <@@ false || true @@>;;
(* val it : bool = true *)
<@@ "bob" = "fred" || "fred" = "bob" @@> = commute <@@ "fred" = "bob" || "bob" = "fred" @@>;;
(* val it : bool = true *)

// only operates at the top level though
<@@ fun x -> true || false @@> = commute <@@ fun x -> false || true @@>;;
(* val it : bool = false *)
```

A nice simple function, to apply a nice simple rule. Generally you'll want to choose when to apply something like the ``commute`` function, hence not making it recursive. But what about something like the identity law?

The identity law states that ``true && x = x`` and ``false || x = x`` for all x. This looks like it might allow us to remove redundant statements from our boolean expressions without changing the logical result, and if we're interested in carrying out this operation at all we almost certainly want to apply it recursively down through the expression.

Time to break out our broad ``ExprShape`` patterns again:

```fsharp
let identity quote =
    let rec transform q =
        match q with
        | And' (True' _, p)
        | And' (p, True' _)
        | Or' (False' _, p) 
        | Or' (p, False' _)
            -> transform p
        | ShapeVar v -> Expr.Var v
        | ShapeLambda (v, e) -> Expr.Lambda(v, transform e)
        | ShapeCombination (o, es) ->
            RebuildShapeCombination(o, es |> List.map transform)
    transform quote
```

Firstly, we check if the top of the quotation matches any of the four relevant conditions for the identity law. If any of them do, we bind the proposition that we're reducing to to the name ``p``, and then we carry on recursing down the tree.

Otherwise, we're back to the ``id`` function above: a ``Var`` is a leaf node, we ``transform`` the body of any lambdas and if we hit a combination we ``transform`` all of it's constituent expressions.

This is starting to reach the stage it's worth unit testing, so let's break out xUnit and add some "facts" (you'll need to reference xUnit manually or via NuGet to build the tests.)

```fsharp
open Algebra.Boolean
open Xunit

[<Fact>]
let ``Identity reduction &&`` () =
    Assert.Equal (<@@ false @@>, identity <@@ true && false @@>)

[<Fact>]
let ``Identity reduction ||`` () =
    Assert.Equal (<@@ true @@>, identity <@@ true || false @@>)

[<Fact>]
let ``Identity reduction recurses`` () =
    Assert.Equal (<@@ true @@>, identity <@@ (true || false) && true @@>)

[<Fact>]
let ``Identity reduction recurses with none boolean`` () =
    Assert.Equal (<@@ "bob" = "fred" @@>, identity <@@ ("bob" = "fred" || false) && true @@>)

[<Fact>]
let ``Identity reduction recurses with none boolean 2`` () =
    Assert.Equal (<@@ "bob" = "fred" @@>, identity <@@ (false || "bob" = "fred") && true @@>)
```

And there you have it, a function that takes an expression tree and manipulates it in a potentially useful fashion.

Why did we go to all this trouble? Well, I'm afraid for that, dear reader, you'll have to either wait for the next installment or come along to my session at [Progressive F# London 2014](https://skillsmatter.com/conferences/1926-progressive-f-tutorials-2014#program) where we look at translating quotations into other languages.

If you want to look into this further yourself in the mean time, an implementation of all of the rules of boolean algebra and a basic test suite can be found in a [gist on github](https://gist.github.com/mavnn/9acfb52c8c311879266b).

If you're feeling really brave, I also highly recommend looking into "A Practical Theory of Language-Integrated Query":

* [Talk by Philip Wadler](https://skillsmatter.com/skillscasts/4486-a-practical-theory-of-language-integrated-query)
* [Academic paper describing the techniques](http://homepages.inf.ed.ac.uk/slindley/papers/practical-theory-of-linq.pdf) - the first few sections are very readable even without a background in programming language research, and definitely worth looking at before you get to...
* [The practical implementation](https://github.com/fsprojects/FSharp.Linq.ComposableQuery) - if you want to watch people much cleverer than me **really** apply some of these principles.

That's all till next time, and I hope your brains recover sooner than mine.
