---
layout: post
title: "Implementing classic OO style code in F#"
date: 2013-09-24 14:21
comments: true
categories: 
- Programming
- FSharp
---
As part of writing up notes for introducing F# as a programming language to experienced C# devs, I realised that I'd written at least one suitable example myself.

In the [NuGetPlus project]("https://github.com/mavnn/NuGetPlus") I needed to implement a ProjectSystem class as the version in that was almost a direct copy of the MSBuildProjectSystem in the NuGet commandline client.

So without further ado!

The [ProjectSystem class from NuGetPlus]("https://github.com/mavnn/NuGetPlus/blob/master/NuGetPlus.Core/ProjectSystem.fs"):

{% gist 6684569 fsharp.fs %}

And the [MSBuildProjectSystem class from NuGet]("http://nuget.codeplex.com/SourceControl/latest#src/CommandLine/Common/MSBuildProjectSystem.cs")

{% gist 6684569 csharp.cs %}

I can't honestly remember if they do exactly the same thing, but they are pretty similar and implement the same interfaces and inheritance. As you can see, while F#'s focus is being functional it will support OO code just fine, which is very useful indeed when you need to interop with .NET code from other languages and coding styles.
