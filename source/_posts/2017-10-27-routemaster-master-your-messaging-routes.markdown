---
layout: post
title: "RouteMaster : Master Your Messaging Routes"
date: 2017-10-27 16:25:53 +0100
comments: true
categories: [EasyNetQ, RouteMaster]
---
I'm very pleased to announce the release of an initial alpha of [RouteMaster](https://github.com/RouteMasterIntegration/RouteMaster).

What is it? Well, I'll let the README speak for itself:

> RouteMaster is a .NET library for writing stateful workflows on top of a message bus. It exists to make the implementation of long running business processes easy in event driven systems.

There is also example code in the repository so you can see what things are starting to look like.

For those of you following along, this will sound awfully familiar; that's because RouteMaster is the outcome of my decision to rebuild a [Process Manager](/process-management-in-easynetq/) for EasyNetQ. The first cut of that was imaginatively called "EasyNetQ.ProcessManager", but I decided to rename it for three main reasons:

* On re-reading [Enterprise Integration Patterns](http://www.enterpriseintegrationpatterns.com/), it occurred to me that RouteMaster was an enabler for many of the other patterns as well as the "Process Manager"
* The message bus RouteMaster uses is provided as an interface; the main dll has no dependency on EasyNetQ at all
* The previous EasyNetQ.ProcessManager is still available as a Nuget package supplied by my previous employer, and they have both the moral and legal rights to the package given I wrote the original on their time

A pre-emptive few FAQs:

### Is this ready to use?

No, not yet. I'm out of time I can afford to spend on it right now, get in touch if you can/want to fund future development.

If you want to play, the code as provided does run and all of the process tests pass.

### Urgh! All the examples are F#!?

Yes, but there is a C# friendly API in the works. See the first question :)

### What infrastructure do I need to run this?

At the moment, I'm using EasyNetQ (over RabbitMQ) and PostgreSQL (via Marten) for transport and storage respectively.

### What about things like NServiceBus and MassTransit?

In some ways they fall in a similar space to RouteMaster, but with a different philosophy. Just as EasyNetQ is a focused library that supplies only part of the functionality you'd find in these larger solutions, RouteMaster is designed to work with your chosen transport abstraction not replace it.

## Ask not what your RouteMaster can do for you, but what you can do for your RouteMaster!

I'd really like feedback, ideas, use cases and suggestions - leave comments here or ping an issue onto the repository. If you're feeling really brave and can try and actually experiment with it, but at the moment I'm mostly hoping for concrete use cases and, well, funding.

Quite a few people over the years have hit my website searching for an EasyNetQ process manager, and others have asked me if it's still available. I'd like to hear from as many of you as possible to build the tightest, simplest solution which will do the job.
