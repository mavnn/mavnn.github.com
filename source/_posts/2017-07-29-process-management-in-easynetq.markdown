---
layout: post
title: "Process Management in EasyNetQ"
date: 2017-07-29 12:34:03 +0100
comments: true
categories: [easynetq]
---
Back in 2015, I wrote about a [process manager](https://blog.mavnn.co.uk/easynetq-process-management/) I'd written over
the top of [EasyNetQ](http://easynetq.com/). At the time it was released as open
source, and I was pretty pleased with it. It allowed you to fairly quickly string
together a managed work flow of services steps with built in state management for
each work flow, and avoided many of the potential pitfalls of trying to build
a request/response based system in situations where it isn't appropriate.

Two years on, I've learnt a lot about distributed system design and a lot about
composing logic (*cough* monads *cough*) - and the original source is no longer
available from my previous employers where it was written.

Despite that, I've had a lot of interest in the library in between, so I'm
embarking on a full, clean room, rewrite incorporating everything I've learnt.
This will also allow me to take advantage of the (very) recent move of EasyNetQ
to be .netcore compatible to build the library against .NET Standard, providing
a fully portable solution out of the box.

As with EasyNetQ itself, the major focus of this project will be providing the
best possible developer experience. This means that it will provide sensible
defaults and will be opinionated in places.

Where do you come into all of this? Well, we're looking for corporate sponsorship
to help accelerate the development process and we're looking for testers to help
build products with pre-release versions. In both cases you get to help to drive
which opinions the library settles on, and as a corporate sponsor we'll also help
you get up and running. Whether you're sponsoring or not, we'd love you to get involved.

And on a more general note, if you find you're pushing the boundaries of EasyNetQ
in any way and you'd like some help, I'd be happy to set up training or consultancy
for a bespoke solution for you as well. Drop a note to [us@mavnn.co.uk](mailto://us@mavnn.co.uk).
