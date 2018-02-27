---
layout: post
title: "Internal Training Deep Dive"
date: 2018-02-27 11:43:22 +0000
comments: true
categories: ["fsharp", "training"]
---
I sometimes get asked what I actually do when I go to companies. The answer is, it varies a lot - but hopefully this post will give you some idea.

A few months back, [Rick Minerich](https://twitter.com/rickasaurus) noticed I was running an [F# course](https://blog.mavnn.co.uk/building-solid-systems-in-f-number/) in the UK, and mentioned that he had a team of developers that were hoping to take their F# skills to the next level.

There were only two problems: the team is based in Atlanta, Georgia. And the course focused on writing distributed systems, which isn't the current problem space the team is working in.

I had several rounds of conversation with Rick to sort out exactly what it was that the team needed, and we worked together to form a syllabus for a week of internal training. 

Each time I've done this the result has been very different; in this case the level of experience also varied across the team so I was asked for clear prerequisite criteria to allow people to choose relevant sessions to come along to.

The five days ended up looking like this:

<!-- more -->

Monday AM: SOLID to Functional
==============================

Objective
---------

Understand and recognize some of the basic functional programming
techniques which take the place of SOLID principles in object oriented
code.

Session Outline
---------------

We'll start with a analyzing a simple but carefully written object
oriented data processing application. Step by step we'll take examples
of SOLID principles from the code base (like Single Responsibility and
Dependency Inversion) and convert our service to use equivalent
functional techniques.

Prerequisites
-------------

None

Monday PM: Responding to Real Time Input
========================================

Objective
---------

Learn the differences between "pure" and "impure" code and learn how
to interact with external inputs (user actions, incoming network
connections) in real time while keeping your core logic pure.

Session Outline
---------------

Working through guided examples we'll explore how our application logic
can treat both incoming events and outgoing data as "lazily evaluated
sequences" manipulated by "pure" functions.

This will enable us to separate the "impure" input and output code we
use to interact with the outside world from our "pure" internal logic,
increasing readability and ease of testing.

Prerequisites
-------------

None

Tuesday AM: Pipelines Beyond the "Happy Path"
===============================================

Objective
---------

Learn to use and recognize functional techniques for handling errors and
disposable resources, especially within "pipeline" applications.

Session Outline
---------------

Basic pipeline logic in F# is easy to write, easy to reason about and
expresses intent clearly. Unfortunately, how you handle exceptional
circumstances such as disposable resources and errors is not always
obvious.

We'll take our functional pipeline application from Monday morning and
start adding:

-   error handling
-   asynchronous IO
-   handling of disposable resources
-   logging

Prerequisites
-------------

Basic handling of sequences and lists via the Seq and List modules.

Tuesday PM: Computational Expressions and Bind
==============================================

Objective
---------

Understand how "Computational Expressions" work and become confident
in their use.

Session Outline
---------------

In C#, async/await is a compiler construct. In F#, async is
implemented as a "Computational Expression" - and you can define your
own. In this session we'll cover the basics of what computational
expressions are, how to define them, and how to use them with
confidence.

Prerequisites
-------------

Understanding of "bind" functions of the shape
`T<'a> -> ('a -> T<'b>) -> T<'b>` (as covered Tuesday AM).

Wednesday AM: Breaking Your Code in New and Unusual Ways
========================================================

Objective
---------

Discover how to use property based testing and BenchmarkDotNet to help
build correct and high performance code.

Session Outline
---------------

Beyond the basics of unit testing we can also test code's
**performance** and whether it obeys defined **properties**.

In this unit we'll take several different implementations of the same
logic and find out how to test it to destruction with FsCheck, and how
to choose the most performant version with BenchmarkDotNet.

Prerequisites
-------------

Confident use of computational expressions (for property based testing).

Wednesday PM: Useful F# Tricks and Tips
========================================

Objective
---------

Use Active Patterns to partition data with clean, readable code.
Depending on timings, learn how to write highly generic and reusable
library code with "member constraints".

Session Outline
---------------

We'll work through a series of examples of using some of F#'s most
unusual features: active patterns and member constraints.

Active patterns allow us to use custom logic in pattern matching; for
example dividing strings into valid and invalid phone numbers using a
pattern match statement.

Member constraints (sometimes referred to as "type safe duck typing")
allow us to build highly generic code which will accept any type which
implements a member with matching name and signature - even types which
are not available at compile time to your code. This technique is used
by the F# core libraries in places, and can allow the writing of type
safe code that would other wise be impossible within the F# type
system.

Prerequisites
-------------

None

Thursday (all day): Presenting Your Data to the User
====================================================

Objective
---------

Create user interfaces which are efficient, look good and use the same
principles (and in some cases underlying code) as the functional
services they sit on top of.

Session Outline
---------------

Fable is a F# to JavaScript compiler designed to allow easy interop
with "raw" JavaScript and typed F# code which can be used on both
server and client.

Elmish is a UI library which sits on top of Fable (inspired by the Elm
programming language), which can create both SPAs (Single Page
Application websites) and native applications via React and React Native
respectively. It models the user interface as a "state" (what you wish
to display) updated by an incoming stream of "events" which are
treated as a sequence.

Here we will experience how the basic functional concepts of processing
sequences of data can be applied even to interactive domains.

Prerequisites
-------------

Good understanding of writing F# code with sequence combinators (see
the course sections for Monday afternoon and Tuesday all day).

Friday AM: Building a Domain Description With Types
===================================================

Objective
---------

Learn to model a business process in the F# type system, to help
building code where the links between actual business terms and pieces
of code are made obvious.

Session Outline
---------------

F# gives us a very concise way of capturing the structure of a business
process via the use of records and union types. In this session we'll
delve into translating "how we talk about a business process as
humans" into "how we talk about a business process to the compiler".
Done well, this allows for code which is easier to test, maintain and
understand because it is easier to map from what the business thinks
should happen to the actual code in your editor.

We'll explore how it's useful to model a process by capturing several
distinct categories of types:

-   Commands which can be sent to a system
-   Events which occur within a system (normally in response to
    Commands)
-   Data which the system must be able to understand

Prerequisites
-------------

Knowing something about a business process. No coding knowledge at all
is required, and non-coders would be welcome to take part in the
exercise (it would even be helpful).

Friday PM: Building Logic Around Your Types
===========================================

Objective
---------

Construct the basic structure of an application around a well defined
domain captured in the type system.

Session Outline
---------------

Taking the types from Friday morning (whether you were at the session or
not) we'll experiment with how to turn them into a code base which
knows about the gory details of computers (IO/networking/parsing/etc) -
without losing the visibility of the underlying business process.

Prerequisites
-------------

Good understanding of writing F# code with sequence combinators (see
the course sections for Monday afternoon and Tuesday all day).
