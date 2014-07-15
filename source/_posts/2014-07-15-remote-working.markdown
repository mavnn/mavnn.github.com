---
layout: post
title: "If I Ruled the World... Remote Working"
date: 2014-07-15 20:43:06 +0100
comments: true
categories: ["Rule the world"]
---
Welcome to a new category of posts for my blog. It's the "Rule the World" category, where I spout opinions on a subject with gay abandon, even if I can't actually offer that much beyond anecdotal evidence to back the opinion up.

On this occasion I even feel justified as someone has actively asked my opinion about something.

Well, that was foolish now, wasn't it?

<!-- more -->

## In the Blue Corner

These questions are coming from a friend who is heading up the development team of a small but reasonably established start up in London. Hiring is competitive, wages are high, and all of their production services are running in a remote data center somewhere else anyway.

He'd also like to be able to go surfing before work some mornings, which is hard in central London.

All of this has lead to an interest in both remote working and working from home.

## In the Red Corner

I've never been a fully remote worker, but for family reasons I've been working somewhere between one and two days a week from home for about 6 years now. I've also worked occasional periods of a week or two completely remotely. I've therefore lived one of the scenarios that is concern to my surfing friend: can you mix and match remote/home working and office based workers, or do you have to really go the whole hog and be a fully distributed company if you want to open up the
option at all?

## Let's get started!

The questions were originally sent to me by email, which I asked for permission to reproduce here, slightly reformatted and with a few bits redacted to protect the potentially innocent:

> At [our company] the "default" is very much in the office. I want to actively encourage/enable people to work remotely without it evolving into a "second class" citizen? Partly because I think it's a "good" thing, and so we can genuinely hire the best possible talent. And the longer the company exists the harder it will be to establish that culture. I for one would like to try surfing in the morning and working later... and I can't do that in London!

> Current tools/workflow:

> - We all use [chat software] already - I *think* we'll just need more discipline to ensure as much chat as possible is on [chat software] even if it's discussed in the office. 
> - All dev goes through pull requests, which should work fine remotely too. We've experimented with ScreenHero for pair programming, which in theory would work though haven't tried more than once or twice.

> Current unknowns:

> - Are we talking working remotely, but commutable in to the office, or genuinely distributed team? Pros/cons.
> - Core working hours? How do we deal with non-devs and ensuring we have customer support covered as a company?
> - More ad-hoc catch ups? How to deal with weekly planning/priorities?
> - What kinds of machines do we buy people? Currently they're fast desktops, but you won't get the same spec on a laptop unless it's a brick. Jon is experimenting with top of the range 15" macbook, but personally I wouldn't want to lug that to the office either.
> - Web cams / other things like Sqwiggle? Do we care?

There's a fair amount of stuff there, so let's start knocking questions out :).

Starting with the easy ones first...

## Kit

> - What kinds of machines do we buy people? Currently they're fast desktops, but you won't get the same spec on a laptop unless it's a brick. Jon is experimenting with top of the range 15" macbook, but personally I wouldn't want to lug that to the office either.
> - Web cams / other things like Sqwiggle? Do we care?

I do a fair amount of heavy dev work as part of my current job. My working from home kit? A [Yoga IdeaPad](http://shop.lenovo.com/gb/en/laptops/lenovo/yoga/yoga-13/#tab-tech_specs) and a headset. It's a relatively high end model, and I'd probably recommend the ThinkPad version now it exists, but really - it's good enough.

Between having an SSD and 8gb of RAM, you can easily run several copies of Visual Studio, a couple of virtual machines and all your normal background apps (email, chat, browser, etc) without noticeable slow down. It's light weight, has a long battery life and is comfortable to use on the move. I'm with Hanselman - [the ultrabook has arrived](http://www.hanselman.com/blog/MyNextPCWillBeAnUltrabook.aspx) as a development environment, and that was two years ago.

Is it slower than the desktop the guy next to me uses? Yes. Do I notice in day to day, even heavy weight development? No.

As a bonus, most ultrabooks also have a web cam built in. But you want the headset. Oh, yes. You want the headset.

For small groups at least, Google Hangouts or Skype appear to work pretty well. I've not had reason to try anything heavier weight, although I could see some of the pair programming tools being helpful.

## Core working hours

> - Core working hours? How do we deal with non-devs and ensuring we have customer support covered as a company?

**...rant mode: on...**

So: [you](http://heeris.id.au/2013/this-is-why-you-shouldnt-interrupt-a-programmer/) [shouldn't](http://lifehacker.com/how-to-stay-productive-in-an-open-working-environment-1443536319) [interrupt](http://mattrogish.com/blog/2012/03/17/open-plan-offices-must-die/) [programmers](http://www.thesoundagency.com/2011/sound-news/more-damaging-evidence-on-open-plan-offices/). Those are just the first few results on Google, I haven't even started digging into the actual
scientific references.

**...rant mode: off...**

Given that you're not interrupting your programmers, what do you want? Well - you want asynchronous communication channels (chat, email) for when your programmer choose to interrupt themselves and you want at least each person to have at least one time a day when they're online with a group simultaneously. I was going to say when you have everyone on at the same time, but I'm not actually sure that's a prerequisite.

One thing I've often felt working from home in an environment where it isn't the norm is the pressure to "appear to be online" in the same way that there's the pressure to be "sitting at the desk" when you're in the office. In reality, both are stupid; you'll get better code out of me between 8pm and 10pm if I've taken 3pm-5pm off to pick up my son from school and spend some time with him. In the same way, you'll get better code out of me after I've nipped out of
the office to get a coffee than if I sit at my desk pretending to be productive when I'm stuck on a difficult mental problem.

It's hard to judge how much of this pressure is real, and how much is in my head. But if I ruled the world, er, company, the lack of core hours would be explicit.

Are there exceptions to this? Yes, especially during planning phases of projects where it's helpful to have more people on at the same time more often. Also, as mentioned above, support isn't something you can turn on and off depending who happens to be online. You might not be able to allow unpredictable working hours; but that doesn't mean everyone has to have the same working hours.

## There isn't a water cooler!

> - More ad-hoc catch ups? How to deal with weekly planning/priorities?

Ok, so I miss white boards when I'm not in the office.

Having said that, because we don't like interrupting each other too much, in practice the teams I've worked best with have done a great deal of their catching up via chat *even when they've all been sitting next to each other*. Why? No interruptions, instant record of decisions.

When I'm in the office, I do take advantage of being able to call someone over and point at the screen. It's a genuine downside of not being physically present that you can't do that when you're working remotely, but screen sharing tech covers most of the same ground.

## How does it work?

> - Are we talking working remotely, but commutable in to the office, or genuinely distributed team? Pros/cons.

I've deliberately left the most interesting question till last.

All of the places where I've regularly worked from home have been primarily office based organisations (two have been local councils). This has had some consequences on occasion.

Most importantly, if you want fully remote workers and you want them to feel involved my experience suggests you will have to work **hard** at it to make it work. As someone who works from home some of the time, I often find I've missed things when I've been out of the office because they didn't make it onto chat or email but I then spot them when I come back in. But for me, that's a delay of just a day or two. For a fully remote worker, that content is just lost. The exchange
is that on the days I'm out of the office I feel I get a lot more done, especially if I'm working on heavily conceptual problems, and it adds an extra flexibility to the home work balance exchange that makes it massively easier to stay sane. In fact, at times (with a young child and a wife who was suffering from a chronic health condition) it has been the only way I could work full time hours. The overhead of the commute and more fixed working times would have left me unable to
get close to full time otherwise.

This might make it sound like I'm claiming that the ideal is people who regularly commute into the office, and regularly work from home. And we'll just ignore all those hard issues with fully remote workers and building in all that deliberate extra communication.

But actually, I'm not convinced.

Why not?

1) *That extra communication is useful anyway.* A lot of this stuff is things that should really, **really** be written down regardless, but we're human so we don't bother if there isn't an immediate reason.

2) *There is a high possibility you'll end up with fully remote workers anyway.* I nearly moved to Italy this year to help look after my elderly parents-in-law. If I had, I wouldn't have wanted to stop working for my current employer, and they didn't really want to let me go. And then you have the whole 24 hour support question - doesn't just setting up an Australian office make more sense? (Which is, in fact, what the current company have ended up doing.)

3) *You're already paying for the infrastructure - but not getting the cost benefits.* If you want to allow people to work from home, there are some cost implications. You'll probably want a VPN, possibly phone forwarding, etc. But you're still paying everyone a full London salary. And you've still got as many desks as you used to. You're not getting all the pain, but you're not getting all the benefits either.

4) *Talent.* Not all the clever people live in [substitute your town/country here]. Most programming communities are full of online, highly English literate people (almost by definition) who *do not live where you do*. Why waste the opportunity?

On a more general note, things that have helped or hurt my remote working:

* A sensible VPN set up is great; don't make me bounce Spotify over *your* bandwidth.
* Speaking of which: a basic build shouldn't require you to be on the VPN. Some of the integration tests may need it, but a basic build shouldn't. An unreliable VPN connection should be a minor inconvenience, not a reason to pack up and play tennis.
* Video chat is sometimes nice - text based chat is invaluable. Text based chat **should not go through the VPN**. It's how you tell people the VPN isn't working. You might think I've experienced some VPN issues over the years, I couldn't possibly comment.
* If there are a group based in an office, it's worth investing in some kit. Having tried it, trying to have a multi-party video chat with headsets where two or more people are in the same room is painful. Get the group microphone/speaker with noise cancellation, it's worth it.

## So - if I ruled the world...

I'd be looking at making sure that my company was fully remote worker friendly, even if I didn't have remote workers yet. And I'd be doing it as early as possible.

YMMV :)

(especially if you're not running a software house, which I've kind of assumed here)
