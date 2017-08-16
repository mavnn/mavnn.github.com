---
layout: post
title: "Trying .NET Core 2.0 with F# Today"
date: 2017-08-16 11:15:20 +0100
comments: true
categories: ['fsharp']
---
Yesterday, I tried to use .NET Core for F# on day zero. A bit <s>brave</s>foolish, I know, but v2 was supposed to be the one with all the bugs ironed out.

Short version: it's a lot better, but it's still easy to hit rough edges.

Longer version: be very careful that you don't hit issues with versions. On MacOSX, I hit a series of road blocks which made yesterday much more painful than it should have been.

* If you're on a Mac, you'll need to update All The Things&trade; to get a reliable experience. And I don't just mean all the .NET Core things - full system update and ``brew upgrade`` are your friends
* Don't use templates. Not many of them have been updated to 2.0 yet, you get no warnings about the ones which haven't, and enough has changed that it is very hard to update them manually unless you are a .NET Core expert already. (If you are, I suspect you're not reading this guide).
* Don't try and update projects unless you know what you're doing; it cost me a lot of pain yesterday including bizarre internal compiler errors. On the happy news front, just copying across your actual code files works just fine.
* Don't try and use Visual Studio (yet) - I'm not going to go into this one as I'm mainly talking to Mac users, but there has been issues there.

With all that said and done, if I skipped using any templates and stuck exclusively to the bundled project options, the actual experience of using ``dotnet`` is very pleasant.

For example, setting up a brand new solution with library and test project looks something like below:

``` sh
# Create solution file Project.New.sln in current directory
dotnet new sln -n Project.New

# Create library project in directory Project.New.Library
# Default proj name is Project.New.Library.fsproj
dotnet new classlib -o Project.New.Library --lang f#

# And again for test library
dotnet new console -o Project.New.Library.Tests --lang f#

# Add projects to solution (can combine to a single line)
dotnet sln add Project.New.Library/Project.New.Library.fsproj
dotnet sln add Project.New.Library.Tests/Project.New.Library.Tests.fsproj

# Set up test console app
cd Project.New.Library.Tests
dotnet add reference ../Project.New.Library/Project.New.Library.fsproj
dotnet add package Expecto
# Update Program.fs to run tests (see https://github.com/haf/expecto#testing-hello-world)
```

At this point, running ``dotnet run`` in the test directory should run your example test, and running ``dotnet build`` from the solution directory should successfully build your nice, portable, shiny, .NET Core 2.0 code.

Enjoy, and remember this post has a shelf life: hopefully issues like the template woes I had should disappear quickly as the eco-system catches up with the latest release.
