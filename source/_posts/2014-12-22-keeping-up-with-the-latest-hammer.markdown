---
layout: post
title: "Keeping Up with the Latest Hammer"
date: 2014-12-22 12:07:02 +0000
comments: true
categories: [programming,15below]
---
## Making Sure Your Developers Keep Developing

Software development is a strange profession, mostly because it's so young and because the tools are changing so fast. I've not been an established enough craftsman in any other trade to know whether other professions are moving as quickly these days, but at least in my imagination once a carpenter learns to use a hammer, it doesn't get discontinued after 2 years and the hammer taken off the market. Or a new hammer released that hammers nails ten times as fast, but has a different
shaped handle and you have to hammer sideways instead of down.

We don't even seem to be able to decide whether it's a craft or a science. You can earn Computer Science degrees - but then well known software professionals choose titles like [Software Craftsman](https://twitter.com/unclebobmartin).

Despite all of our claims of best practice and shared knowledge, it largely boils down to: developers don't know what they're doing yet. We're a new profession, and we're still learning - not just as individuals, but as a profession.

This means that both as an individual developers, and as software houses - if we stop learning, we sink. The competitive advantage of keeping up with what's happening in the industry so outweighs the cost of doing the research that it would be foolish not to. Because while we might not yet know the *right* way to do things, we're still definitely finding *better* ways to do things.

So: how do we do keep up to date, as [individuals](/keeping-up-with-the-latest-hammer/#individuals) and as [companies](/keeping-up-with-the-latest-hammer/#companies)?

<!-- More -->

## <a name="individuals"></a> As individuals

### Books and Blogs

Firstly of course, you need to read. Technical books are still excellent when you need a deep dive into a specific subject, but in general a lot of the information is now becoming available in blog posts which seem to be developers main method of swapping information, ideas, and "best practice". In general, if you need a deep dive into an established technology or you need to read up on a subject at a conceptual level (Test Driven Development, Functional Programming, etc.)
then a book can be very helpful. If you're looking into something new, or very specific (AngularJS, a particular unit testing framework) then it's time to hit google and read up on some blog posts. Otherwise you'll just have a stack of dead trees to be taking to the recycling center every six months.

### Conferences

Sometimes, there's nothing like seeing somebody do something. Or hearing from someone who's actually done the thing you're thinking of doing.

Conferences come into their own in these situations; large conferences can be nice because of the big name speakers and the wide range of subjects but in my experience small specialist conferences have two big advantages. They give you much more access to the speakers outside the sessions, and they tend to be much cheaper!

Speaking at conferences is a great way to attend them cheaply, and is also a great way of ending up at things like speaker's dinners and making some contacts as well as learning the particular skill you went for. If you or your company is doing something well - pretty much anything well - get yourself out there. It provides great opportunities for you, and other people's gratefulness is a currency you can't buy with money.

And... ssssh, don't tell everyone: it's actually really easy to get speaking gigs at specialist conferences if you know about a relevant specialist subject. Why? Because people like you don't bother applying, and so the organisers tend to be a bit desperate. Yes, you'll need to do some public speaking - but that's not exactly a bad skill to have under your belt anyway, is it now?

### Research Papers

Keeping up with computer science research would be a more than full time job in its own right - but the research that is turning out to have practical applications is often referenced in talks and blog posts by the people who are basing projects off it. If the project looks interesting to you, don't be afraid to go back and read the original research papers! There's generally more in there than the current project needs which might help you even further - and they are often
surprisingly readable.

### Training Courses

And for some skills, you just need the hands on training. It can be expensive, but on occasion its worth it to pay your money and actually be taught to do something.

### Discernment

It's not a word that comes up very often, but discernment is critical to software developers. Remember what I was saying above about it being a new profession? Well, one of the side effects of that is we're still learning from our mistakes and we're still repeating them. Not everything that people say is new is actually new - try and check back in the (relatively short) history of computer science to see if it's already been tried and failed.

A classic example of this is distributed computing; making lots of computers do lots of things at the same time is actually pretty hard to get right. A lot of the "new" solutions to the problem you see being suggested are actually ideas that people have already tried and do not work; if you need to work with distributed systems it's worth doing enough background research to have a hope of spotting these issues.

This doesn't necessarily mean you have to be an expert on everything you consider touching. It does mean you'll have to do enough research to discover the people who *are* experts so that you can get well thought out feedback about the ideas you're considering using.

This extends even to things like choosing which blogs to follow. You won't be able to follow all of them, so if you can find a "core" of people whose opinion you value they can act as a pre-filter for you on interesting new ideas, with out you trying to track all of their sources independently.

## <a name="companies"></a> As a Company

This is all great - but all of these things give knowledge to an individual. How do you share the learning around?

Some of these things carry across directly, of course: you should have a conference budget. You should have a training budget, too - and you should almost certainly be providing in house training for your own in house tools and procedures.

But that only really helps for the things that people know they don't know; when they've realised they've hit a problem and they need some knowledge. How do you share the more nebulous things? No one is going to wake up one morning and realise that the problem they're currently tackling would be better solved by a functional programming technique if they don't know what functional programming *is*.

[Mike Hadlow](https://mikehadlow.com) came up with a solution for this years ago that he implemented at [15below](http://15below.com) which we're still using.

His proposal was deceptive simple: one hour a week is spent on group "Developer Education." Someone prepares a topic and promises to provide notes (or a recording) afterwards - everyone else just turns up. We call them DevEds, and they run every Friday morning at 9:00am.

It doesn't sound much, does it? But actually, it's had a huge impact in the company. And we keep on getting asked how we do it, and how it works, so I'm going to try and explain!

### What subjects?

We're not completely random in subject choices - but we are deliberately broad. Basically, the subjects fall into three main categories:

1) Communication of internal changes

A team releases a new service for our core product. A new internal code review process is put in place. For these kind of events, we use the DevEd as a vehicle for communication to developers within the company, making sure everyone is aware of the change and allowing people to ask questions. Sometimes we'll put a requirement on a DevEd of this type that at least one developer from each team needs to be there (DevEds are not compulsory - just highly recommended).

2) Things we could be using already

We use Microsoft's .net languages for development, so (for example) we run sessions on the new features in the latest version of C# each time we upgrade. These are things that developers can go back out into the office and use today; also in this category are things like open source libraries we're already using.

3) Potential new tools and general programming knowledge

[SOLID](http://en.wikipedia.org/wiki/SOLID_%28object-oriented_design%29) programming. Why you shouldn't do thread management by hand. [Property based testing](https//blog.mavnn.co.uk/property-checking-start-challenge/) (that link is a write up of an actual DevEd session, if you're interested). This is where we try and introduce people to ideas they should be aware of, introduce new tools and languages that we are considering using but aren't yet or try and teach people how to *think* about development rather than how to *do* development. We also
tend to throw some fairly odd ball things into this category to keep people thinking, and to avoid people only knowing about things within "our expertise." For example, although we're a Windows .net programming house we've run sessions on using Emacs and Vim. Why? Because a lot of programmers use these tools, and get a great deal of value from them. Which means they probably have things to teach us if we care to learn. And yes - this blog post was written in Vim!

The idea in this category is not normally that a person will come out of the session being able to use something straight away - but they should now be aware it exists, and know what to look up if they do need to use it.

### But I don't learn listening to lectures!

Different people learn in different ways. So we try and teach in different ways: most of our sessions are live coding demos, but some are straight up presentations; others are white board round table discussions (thrown Lego pieces optional); and we're trying to build in more and more practical sessions as we go forward, with groups of two or three people (preferably from different teams) working together to explore the 'thing' we're looking at.

### The benefits

What does all this buy us?

Well: a few things. The benefits of having a built in internal comms session is a big benefit in it's own right. Breaking changes to our auto-deploy system can be announced up front in a format that has more impact than any email would ever had. We don't always have the luxury (or remember to use it!) but when we have, it's worked well.

For keeping people up to date on the technologies and techniques within the company, I count it as invaluable. For an old-ish code base, you'll find C# 5.0 async/await, F# code, LINQ usage in our core product... all the types of shiny new things that save bucket loads of time when you're coding, but a lot of "enterprise" development houses will tell you not to use in case 'not everyone can understand and maintain the code'. For us, this is much less of a problem: if a DevEd has already happened, you've
either been exposed to the concepts or you can look up the presenter and, hey presto, you have an expert to ask. If there hasn't been one, you just ask for it - and you're guaranteed to have a suitable expert to deliver the session (the author of the code in question).

The blue sky sessions sound the least practical, but I suspect they actually have the largest impact. As software houses, we tend to specialise: a particular programming language, a particular operating system, preferred libraries, preferred database server, the list goes on. On the one hand, this is good: you *must* be expert in the tools of your trade. On the other hand, this can be crippling: if you stop evaluating the new things that come along, you'll go out of date. This
causes two big problems: firstly, you're no longer using the best tools for the job. Secondly, the staff you want most will leave.

They will. The people who you really want building your code will be doing all of the things from the first half of this post *in their own time anyway*. That means they'll know that the grass is greener. That there's a better way to do things. That there's already a respected open source project that does the thing you've asked them to create on a shoe string time and testing budget. They'll know, they'll skill up, and they'll leave. This doesn't mean you should always be using the
latest "new and shiny" just because it is "new and shiny" - but it does mean that if one of your developers comes to you and says 'there is a better way!', you really should listen and find out if there is. And then tell the rest of the developers, so they stay excited about staying too.

### Preparation time

Ok, so if you're a manager this has probably all sounded great up until this point. I mean, an hour on Friday morning when the Developers are still normally rubbing the sleep out of their eyes anyway? Good deal!

Let's hit pause for a moment.

These sessions are something we take reasonably seriously; some of them get more prep than others, but I can safely say that a lot of them take a full working day between preparation and post session write up (or recording upload etc). That's a lot of time.

I've had a lot of questions about how we make this work, and frankly the answer is mostly me. Not me, the individual person. But me, my role: having a person who has as a serious job priority internal technical training and communication. It's not my only responsibility, but it's up there on my list in a way that it isn't for our other developers. This means that I have a back up session planned most of the time for if an other developer has to drop doing a session because a
project is running late. I make sure (most of the time!) that there are a few future sessions planned in. I provide support for people who know a subject but aren't comfortable presenting to do their first sessions.

I do end up also delivering the majority of the sessions; I've a fairly broad range of background knowledge and as I'm not generally running on a project critical path I'm the "goto" guy if no one else is available. But that's not the most important thing I provide: it's the ongoing push to make sure these sessions don't just happen this week, but that they keep on happening in the future. Which means I'm not doing other things for the company.

So I suppose the final message here is: if you're in a company where this isn't happening, and you have time/resource allocation responsibilities... read the benefits section again and ask yourself how your company is meeting those needs. If you're a developer in a company where this kind of thing or an equivalent doesn't happen, you pretty much only have two choices: make it happen yourself with "brown bag" sessions and lunch breaks - being aware that you're basically training yourself, and
others, to be ready to leave. Or try and convince the decision makers that keeping the business up to date is worth it. I hope this post helps.

If you are already doing something: awesome! Tell us about it in the comments. We like what we've got, but we're not above stealing better ideas.

## Appendix

Whenever I get asked about this whole process over a conference beer, the follow up is always: what subjects have you covered?

In terms of what the output looks like, [this blog's achieves will give you a selection of DevEd write ups](https//blog.mavnn.co.uk/blog/categories/15below/).

More generally, here's a selection of session titles from the last few years (with purely internal communication subjects removed, obviously):

* GitFlow Intro

* Database Normalisation

* SQL Server Storage and IO

* Error handling with Choice

* Introduction to NodaTime And Humanizer

* Text Editing with vim & emacs

* Functionally SOLID

* Influx

* WebSQL

* Intro to Threading

* FsUnit and TickSpec

* Mobile apps using PhoneGap

* Adaptive Programming to Reduce Config

* What is a Reverse Proxy

* Meet EmoteBot - C# Async and Await

* SemVers and Nuget

* AOP - Aspect Oriented Programming

* How To Write Scalable Services

* A refactoring example

* DDD 2 - Applying Strategic Design

* DDD Strategic Design

* Introduction to F#

* What is REST

* The basics of TCP/IP

* RabbitMQ

* LINQ To Objects from scratch

* Estimation game

* Real world SRP

* Approval Tests

* Web API

* Octopus and Teamcity

* Solid

* Safe Refactoring
