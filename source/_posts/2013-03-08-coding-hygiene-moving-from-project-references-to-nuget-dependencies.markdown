---
layout: post
title: "Coding Hygiene: Moving from project references to NuGet dependencies"
date: 2013-03-08 17:08
comments: true
categories:
- 15below
- fake
- fsharp
- programming
---
So, first post with the new blogging engine. Let's see how it goes.

Our code base at [15below](http://15below.com) started it's life a fair
while ago, well before any form of .NET package management became
practical. Because of that, we ended up building a lot of code in
'lockstep' with project references in code as there was no sensible way
of taking versioned binary dependencies.

That's fine and all, but it encourages bad code hygiene: rather than
having sharply defined contracts between components, if you've got them
all open in the same solution it becomes far too tempting to just nudge
changes around as it's convenient at the time. Changes can infect other
pieces of code, and the power of automatic refactoring across the entire
solution becomes intoxicating.

The result? It becomes very hard to do incremental builds (or
deployments, for that matter). This in turn makes for a long feed back
cycle between making a change, and being able to see it rolled out to a
testing environment.

So as part of the ongoing refactoring that any long lived code base needs to
keep it maintainable and under control, we've embarked on the process of
splitting our code down into more logically separated repositories that
reference each other via NuGet. This will require us to start being much
more disciplined in our [semantic versioning](http://semver.org) than we
have been in the past, but will also allow us to build and deploy
incrementally and massively reduce our feed back times.

As part of splitting out the first logical division (I'd like to say
[domain](http://en.wikipedia.org/wiki/Domain-driven_design) but we're
not there yet!), I created the new repository and got the included
assemblies up and building on TeamCity. It was only then (stupidly) that
I realised that we had several hundred project references to these
assemblies in our code. There was no way I was going to update them all
by hand, so after a few hours development we now have a script for
idempotently updating a project reference in a [cs|vb|fs]proj file to a
NuGet reference. It does require you to do one update manually first;
especially with assemblies that are strongly signed, I chickened out of
trying to generate the reference nodes that needed to be added
automatically. The script also makes sure that you end up with a
packages.config file with the project that includes the new dependency.

It should be noted that this script has only seen minimal testing, was
coded up for one time use and does not come with a warranty of any kind!
Use at your own risk, and once you understand what it's doing. But for
all that, I hope you find it useful.

{% gist 5983379 %}
