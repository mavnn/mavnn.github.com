---
layout: post
title: "Good Developer CVs (Résumés)"
date: 2015-02-12 15:31:49 +0000
comments: true
categories:
---
I've been reviewing a number of CVs from developers of varying experience recently, and wanted to get a few notes out there about what to do (and **not** do) on your CV if you want to get noticed.

Well, by me at least. Your mileage may vary with other reviewers! But - remember that you're interviewing the company as much as they're interviewing you. Hopefully this advice will get you more interest from the kind of companies you **want** to work for, even if it doesn't get you through the enterprise HR screen quite as often.

I'll start with the postives, and then go onto some things it's best to avoid.

### Make yourself stand out!

Looking from the outside (at least, from the job descriptions!), [15below](http://15below.com) probably looks like a Microsoft shop. That's because it is - all of our new code is written in MS supported .net languages, we use SQL Server as our primary data store, WebApi, ASP.net MVC, etc.

But! One of the things that makes us who we are is that we've deliberately hired outside the box, especially for senior developer roles. I have professional Python experience, use F# by preference and run my personal computers on Linux. Three of us use Vim (or at least VsVim). One of us used to write C++ code for nuclear reactors (the testing is strong in that one). My colleagues tweet about Erlang, code for fun in Idris and steal ideas liberally from all these places to make 15below
the kind of place it is. Not all of it makes it into production code, but even there you'll find technologies like RabbitMQ that don't show up that often in the Microsoft world.

If you tailor your CV to what it looks like we prefer, you immediately sink to almost invisibility. "Oh, an other developer with 5+ years C# experience who knows T-SQL and knows to buzzword Scrum onto the CV." To be clear: that's not a bad thing to have on your CV. It shouldn't be the only thing on your CV.

### Show me the codez

This isn't essential, and you may not be able to depending on your previous employment. But if you can link to some previous code you've written (even a website where you can say "I wrote the JavaScript for this one") you'll immediately gain a boost towards an interview. We'll still give you the technical test, because unfortunately there are people who are stupid enough to try and pass off others work as their own (and it is stupid - you will get yourself burnt trying that). But
you're
much more likely to get to the interview stage. This is a particularly useful piece of advice for those of you just coming out of university. Can you link to your final year project? A hobby project? Your github account? If the code is good, you're instantly up there competing with candidates who on paper have years of experience over you.

Whether you show us code in advance or not, we will ask you to write something trivial during the interview. We'll make it as unscary as we can, but unfortunately enough people have come to us who cannot actually write code that we feel we have very little choice about this step. If you're nervous about this kind of thing, I would seriously suggest getting in a practice session or two with friends before getting to an interview for a development post. And be very, very wary of a company that
doesn't ask you to demonstrate you can actually code.

### Don't bother me with trivia, especially if it makes you look bad

Been out of school for more than 5 years? I couldn't give two figs about your grades. Unless you explicitly list the fact that you achieved a C and 3 E's at AS level. That gives me pause for thought. It's not a make or break thing, but no need to cut your own chances.

### Don't fluff up your management skills (unless you want to be a manager)

We've been very borderline about interviewing several candidates because it was completely unclear from their CVs whether they actually *write any code*. Oh, it says "experienced C# software engineer" at the top of the CV, but if you look at the description of their last job it's all about "Team Leader", "Mentor", "SCRUM master"... Again, none of that's bad (well - maybe SCRUM master is a bit dubious) but we're not a Local Council where the only way of being "Senior" is to have
management responsibility. We're hiring developers, and while we'll expect a senior developer to be a good communicator we're not expecting them to be graduates of Atlassian University. If you want to get into people management, it's a fine career path. If you want to be a developer, highlight your development skills.

### Don't give in depth technical examples that give me the fear

We got a CV from someone who had recently written a desktop application that used every multithreading techniques. Really? All of them? In one app? An interesting design decision.

Fortunately for my curiosity, he proceeded to list every multithreading techniques:

* ManualResetEvent
* BackgroundWorker
* Manual Dispatch

In 2015 this is not the way to highlight your expertise in writing asynchronous and concurrent reliable, maintainable code. If someone wrote code like this within the company, the code review would immediately result in some pair programming on "here's all the easier, more reliable ways you could have done this." From an applicant applying for a senior role it's an instant fail.

The problem is not here that someone didn't know how to write concurrent code: not every developer has reason to have learnt those skills. The problem is using a subject where you have very little expertise to try and boost your technical credentials.

Three things to take away here:

1. Don't claim to be an expert on something unless you're certain that you actually are.
2. Did something in a previous job in a way you wouldn't now? List the result, not the detail of the technique
3. If you need ManualResetEvent you're probably doing something very wrong

### Don't try and out Agile us

Yes, yes, we say we're an agile company. But frankly, a lot of stuff that people call agile is a complete waste of time, and other things we just can't do because we spend a lot of time working with customers who are *not* agile. At all. So, we do 15below agile. It's a nice shorthand to give you a good idea of how we generally work. And agile being as dispersed an idea as it is, that's going to be true of pretty much any company that says it's agile.

So be wary getting too carried away on your "agility". Again, don't claim to be expert if you're not: "we had a morning meeting everyday", as one of our candidates noted in his agile experience. And you're going to make me very wary if you try and come across as being an agile zealot - not because agile is bad, but because whatever it is you're a zealot about, it's not going to be "15below agile". And life's too short for getting into arguments about that kind of thing.

------

So, there you have. My own personal list of things that increase or decrease your chances that I'll recommend you're interviewed.

If you think that you'd be interested in working for the type of company that uses this type of criteria... well, oddly enough we're hiring at the moment. Ping me or drop a note through to jobs@15below.com.
