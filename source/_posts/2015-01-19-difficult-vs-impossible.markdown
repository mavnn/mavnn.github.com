---
layout: post
title: "Difficult vs Impossible"
date: 2015-01-20 15:40:57 +0000
comments: true
categories: [programming]
---
Although [programming is young](/keeping-up-with-the-latest-hammer/) and we often don't know much about the "best" way to do things, we're not totally shooting in the dark.

Every so often, you come up against problems that people have investigated in detail, and given programming's mathematical roots this even leads on occasion to a proof about a certain type of system. It would be impossible to keep up with all of the research; but there are a few places where it's very helpful to know about general results.

I'm going to claim here that it makes a big difference to how you handle feature requests both as a developer, and as a business, when you're asked to produce systems which are actually impossible.

Let's take the one that comes up most often in my experience... Consistency in distributed systems.

So - this comes up the moment that somebody (customer, internal stakeholder, whatever) declares that having just a single service running on a single server is just not reliable enough. At some point, something will go wrong - and when it does, the service is a SPOF (single point of failure) and your processes which use it stop.

> Unacceptable!
>
> <cite>Every product owner, ever</cite>

"We must have a cluster!" the service developer is told. "Load balancing!"

"Hmmmm." says the developer to themselves. "Distributed computing. That can get a little tricky. Let's see if I can nail down the actual requirements a bit more."

The Q&A session goes something a bit like this:

* Dev: So... Let's start easy and assume two nodes for now. How important is it that **every** write is replicated to both nodes before it's readable?
* PO: Critical!
* Dev: And... How important is it that the system stays available when one node is down?
* PO: Critical!
* Dev *pausing*: Ah... We won't be able to replicate writes at that point - the second node is down.
* PO: Oh. Right, makes sense - read availability is critical though.
* Dev: It would make life easier if writes can only be made to one of the two nodes - let's call it master. That OK?
* PO *thinks for while*: OK. It's not ideal, but we've got a deadline. Go for it.
* Dev: How about consistency - if Bob writes to the first node, and then immediately reads from the second, is it okay if he gets slightly out of date data?
* PO: Absolutely not.
* Dev: OK. Give me a moment.
* PO: Just a moment - one last thing! This has to be super user friendly to use. So make sure it's completely transparent to the client consumer that they're talking to a cluster.
* Dev: ...right.

Little known to our PO, their requirements are at this point strictly impossible. The impossibility here is a particular edge case; what happens if the "master" node receives a write, sends it to the "slave" to replicate, but then **never gets a response**. What does it do? Return an error to the client? Well - no. If the slave comes back up, and the replication had been successful before the slave became unavailable, then we'd have an inconsistent history between slave and master.

Does it return a success? Well - no. In that case, we're violating our restriction that every write is replicated before it's considered available to read.

So it has to return something else - a "pending", "this write will probably be replicated some day" response. But that violates the restriction that it shouldn't add any complexity to the consumer. We now have a corner case that the server can't handle, so it has to be passed back to the client.

After this first write, we do have a little bit more flexibility - we can stop accepting new writes until we've heard from the slave that it's back up and available and just throw an error. But we're still left with that first, awkward write to deal with. (Perceptive readers will also realise that this set up actually leaves us less reliable for writes than a single node solution - proofs left as an exercise to the reader).

In reality, this impossibility is a subset of the more widely know CAP theorem: a distributed system cannot be always "Consistent" and always "Available" and still behave predictably under network "Partitions". The three terms in CAP have pretty specific meanings - check out a nice introduction at [You Can't Sacrifice Partition Tolerance](http://codahale.com/you-cant-sacrifice-partition-tolerance/).

This is the point where reality diverges, Sliding Doors style, depending on what the developer does next. The branches are numerous, but let's have a look at some of the most common. As an aside, I've fallen into pretty much all of these categories at different points.

### Option 1: The developer doesn't know this is impossible either

At this point, we end up with a response that goes something along the lines of: "Well - I can do you a temporary solution where we return a pending result in situation x. Bit of a pain; put it on the technical debt register, and we'll sort it out when we have a bit more time."

Or: "I can't think of a completely fool proof solution right now; how about in situation x we return a failure for now. It'll be a bit confusing when a user gets told the write failed, and then it shows up later - but we'll get it sorted before the final release."

Neither of these solutions are wrong, as such: but the building of impossible expectations will inevitably sour the relationship between product owner and developer, and can cause serious business issues if an external customer has been promised impossible results. There may even be direct financial penalty clauses involved.

### Option 2: The developer knows it's impossible, and thinks the product owner does too

Here the developer **says** "Well, I can return a pending result..." and the PO adds mentally "...which is a OK stop gap measure, I'll schedule some time to clean it up later."

This leads to pretty much the same outcomes as "Option 1", except the developer gets an unhealthy injection of smug self-righteousness for knowing that he never promised the impossible. In general, this is not helpful.

### Option 3: The developer knows it's impossible, tries to explain... And fails

This is very similar in outcome to Options 1 & 2. Just more frustrating to the developer, especially if the product owner then claims the developer is "negative" or "incompetent".

### Option 4: The developer knows it's impossible and explains to the product owner how and why

This is hard on two levels. On the first: the proof of why something can't be done might be genuinely difficult to understand.  On the second: it can be hard to work out if you've avoided Option 3, or if people are just nodding and smiling.

We nearly hit one of these scenarios this week; fortunately our QA department spotted the mismatch in expectations (yay QA!). Where things got a bit strange is that it was raised as Option 3: "hey! Can we put a bit more effort in, and make this nicer to use?" At the QAT phase this much easier to deal with though - you don't have angry customers, commercial agreements and these other bits hanging over your heads (well - not if you're writing an internal service anyway).

## What can we take away from all of this?

A few things.

### Developers

1. As a developer, you must know the basics of the domain you're working in. Keep on learning, folks.
2. You must be able to communicate as a developer. A lot of developers are introverts, myself included. This is not an excuse. Introvert means that you can't recharge around other people, not that you can't talk to them.
3. You cannot remove your developers from your customer communications, or completely separate commercial proposals and technical evaluation. You must have technical input into your business process, because sometimes its isn't a question of how much time you spend, how well you design or how skilled a developer you assign to the problem: it might just be impossible.

### "Product Owners" (whatever your actual job title is)

1. Listen to your developers, and pay attention to the wording. If they say something is impossible (not hard, not delayed) check you understand why.
2. Be careful how you define the business problem to your developers. You may end up specifying a problem that is unsolvable if you end up layering up too many technical restrictions - while your developer may be able to suggest something that meets the business criteria without falling foul of technical (or more importantly mathematical) limitations to what is possible.
3. If you place a technical requirement ("it must be clustered - no single points of failure!") make sure you understand the technical trade offs that you are imposing. This may take a long time. Alternatively, and preferably, rephrase your requirement to be your actual business requirement ("We promised 98% uptime - what's your design to make sure it happens?").
4. You must be able and willing to say "no" to a customer when they ask for something impossible. You can offer alternatives, work arounds - but don't promise the impossible. It will come back, and it will hurt you.
