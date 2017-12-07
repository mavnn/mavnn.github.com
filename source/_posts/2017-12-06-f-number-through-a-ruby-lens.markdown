---
layout: post
title: "F# Through a Ruby Lens"
date: 2017-12-07 21:00:00 +0000
comments: true
categories: [fsharp, training]
---
I spent last week delivering a five day deep dive into F# for a group of (mostly) Ruby developers in Munich, and wanted to capture some of my thoughts before I lost them as well as give people an idea of the types of things internal training can give you.

I won't be mentioning personal, company or exact team names here as I've not been given explicit permission to do so; if the people who were on the course want to chime in I'll add their comments.

## The background

Although mostly a Ruby on Rails shop, this company also relies on machine learning and expert systems to deliver some of its core services. The R&D department (who build the models) settled on F# for development as a good balance between:

- familiarity of syntax (most have a background in Python and/or a ML language)
- performance (Ruby had struggled here)
- type safety
- good "production" library support (logging, etc)

Having examined the available options in depth, they decided on a standard stack for creating F# microservices of:

- Freya on Kestrel via .NET Core
- Chiron for type safe JSON serialization/deserialization

They wanted to investigate the use of Hephaestus as a rules engine (Freya uses Hephaestus to process HTTP requests). Many of their machine learning models only work with quite constrained ranges of input values, and Hephaestus as a rules engine looked an effective way of routing decisions to the "correct" machine learning algorithm for a particular input range. This in turn would allow for the models to stay reasonably simple and testable.

## The brief

Having made these decisions, the company needed to bring the production services team up to speed on what R&D were going to produce, especially because production had expressed an interest in having F# as an extra potential tool for their own projects.

My brief was to create 5 days of training, after which production needed to know enough about the F# libraries in use that they could work out what R&D's code was doing, and enough about running .NET code in production to feel confident adding error handling, logging, metrics, tests and all the rest of the "engineering" side of development which is not about the programming language but the surrounding ecosystem.

## What we did

I knew that I had a lot of ground to cover in just 5 days, so there was no way that the team was going to come away with all of the new knowledge absorbed and at their finger tips. At the same time, it couldn't be an overwhelming flood of information.

I decided to split the training time between a deep dive in understanding a few key areas in depth (Freya's design, optics and testing), and providing worked examples for the rest which could be referred back to when they became needed. Although I had relevant training material on several of the areas already, it was all tailored in this course to fit a single theme: over the course of a week, we were going to build a microservice that did just one thing, and we were going to test the heck out of it.

The timetable ended up looking like this:

- Monday AM: Introductions
  - high level microservice design
  - check everyone had all the software they needed installed
- Monday PM: Freya overview
  - install the template
  - modify the hello world service to accept POSTs with a name
- Tuesday AM: Optics
  - Chiron, Freya and Hephaestus all make heavy use of "Optics"
  - What are they?
  - Building our own
- Tuesday PM: Handling external data
  - Using Chiron for translation, version handling and API design (using our new found knowledge of optics)
- Wednesday AM: Start our actual microservice as a real project
  - how .NET solutions are (normally) laid out
  - using Paket for package management
  - add a test project with [this set of property based tests](/going-down-the-property-based-testing-rabbit-hole/)
  - write our first bit of domain logic to pass these tests, and plug it into the Freya API
- Wednesday PM: Start making our service production worthy
  - Spin up a docker "infrastructure" with Kibana and ElasticSearch
  - Adding logging to our service, plugged into Freya to automatically capture context like request IDs
  - Health endpoint
  - How to capture metrics
- Thursday AM: interesting bits & answers to questions asked
  - How do computational expressions work?
  - How would I structure a functional UI?
- Thursday PM: flexible rules engines with Hephaestus
  - rebuilt the logic from Wednesday AM reusing the same property tests
  - looked at how we can splice Hephaestus rules graphs together
- Friday AM: BenchmarkDotNet
  - now we know it's correct - is it fast?
  - benchmarked our two implementations of the same logic together
- Friday PM: Using it all in real life
  - code review of pieces of the existing code base, looking at adding what we'd learned
  
## How it went

Overall the course seemed to go really well. At the end of it, the delegates were confident about the basics of building HTTP resources with Freya and Chiron, and happily building benchmarks and tests for their existing code base. For other areas (the boiler plate for plugging logging into Kestrel and Freya, for example) they understood the concepts and felt the course notes were sufficiently detailed they that could make use of them in other situations as needed. That was incredibly pleasing to hear from my point of view, as the course notes for these sessions are by far the most time consuming part of the process to create.

Although they missed some of the features of Ruby when writing F#, pattern matching with discriminated unions was a big hit and they liked the enforced discipline of Freya that required separating the logic of the various stages of handling an HTTP request - and how reusable that made components for handling concerns such as authentication.

Finally, all 3 of the core participants (there were other people around for certain parts of the course) came away saying that they'd really enjoyed it and found it interesting throughout - so that's a big win right there!

## Can you do this for us?

Yes; this particular course was tailored for the specific circumstances, but I've also provided training on the more conceptual side (functional programming concepts) through to the gritty detail of DevOps (with both new and existing code bases).

We can also tailor delivery to match your availability; for this course I traveled to Munich to deliver it, and so it was delivered in a single 5 day unit. For other clients we can arrange regular shorter sessions or even remote workshops (group or individual) with tools such as Zoom.

And if you just want to turn up at a venue and get trained, check out [Building Solid Systems in F#](/building-solid-systems-in-f-number/) happening 31st Jan-1st Feb 2018 in London.

Get in touch with us at <a href="us@mavnn.co.uk">us@mavnn.co.uk</a> if you have any ideas.
