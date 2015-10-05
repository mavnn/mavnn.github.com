---
layout: post
title: "Extracting Information from MsBuild"
date: 2015-08-07 14:45:28 +0100
comments: true
categories: [programming]
---
Recently as part of some research into making a large (very large) solution build more efficient, I started looking into whether there's anyway of getting MsBuild to do
some of the donkey work for you. This is especially important in situations where you want to know what's being used/produced with this particular set of parameters.

Obviously dealing with every possible custom build target is out of scope, but you can get a surprisingly long way by taking advantage of some of the intermediate build
targets used within the MsBuild Common targets files (imported into every *proj file created by Visual Studio).

Create yourself a little file called something like ``Analyse.proj``, and put the following in it:

``` xml
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="12.0" DefaultTargets="WriteStuff" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(TargetProject)"/>
  <Target Name="WriteStuff" DependsOnTargets="ResolveReferences">
    <Message Importance="high" Text="References::@(ReferencePath)"/>
    <Message Importance="high" Text="Compiles::@(BeforeCompile);@(Compile);@(AfterCompile)"/>
    <Message Importance="high" Text="Output::$(OutputPath)"/>
  </Target>
</Project>
```

This is a mini-MsBuild project that imports an other project - the project you want to analyse. You can "build" this project like so:

```
PS C:\DirectoryWithProj> & 'C:\Program Files (x86)\MSBuild\12.0\Bin\SBuild' .\Analyse.proj /nologo /p:TargetProject=./Fake.Shake.fsproj
Build started 07/08/2015 15:05:27.
Project "C:\DirectoryWithProj\Analyse.proj" on node 1 (default targ ets).
WriteStuff:
  References::C:\rip\Fake.Shake\packages\FAKE.Lib\lib\net451\FakeLib.dll;C:\rip
  \Fake.Shake\packages\FSharp.Core\lib\net40\FSharp.Core.dll;C:\rip\Fake.Shake\
  packages\FsPickler\lib\net45\FsPickler.dll;C:\rip\Fake.Shake\packages\Hopac\l
  ib\net45\Hopac.Core.dll;C:\rip\Fake.Shake\packages\Hopac\lib\net45\Hopac.dll;
  C:\rip\Fake.Shake\packages\Hopac\lib\net45\Hopac.Platform.dll;C:\Program File
  s (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.5.1\mscorli
  b.dll;C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFra
  mework\v4.5.1\System.Core.dll;C:\Program Files (x86)\Reference Assemblies\Mic
  rosoft\Framework\.NETFramework\v4.5.1\System.dll;C:\Program Files (x86)\Refer
  ence Assemblies\Microsoft\Framework\.NETFramework\v4.5.1\System.Numerics.dll;
  C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework
  \v4.5.1\System.Runtime.Serialization.dll;C:\Program Files (x86)\Reference Ass
  emblies\Microsoft\Framework\.NETFramework\v4.5.1\System.Xml.dll
  Compiles::;Fake.Shake.Core.fs;Fake.Shake.Control.fs;Fake.Shake.DefaultRules.f
  s;Fake.Shake.fs;
  Output::bin\Debug\
Done Building Project "C:\DirectoryWithProj\Analyse.proj" (default
targets).


Build succeeded.
    0 Warning(s)
    0 Error(s)

Time Elapsed 00:00:00.12
```

And as you can see, whilst it's a bit ugly it generates a whole load of useful information for you about how *this* build with *these* properties will be built.

That's all for now!
