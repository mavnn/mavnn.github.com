---
layout: post
title: "Shake: The Intro"
date: 2019-09-09 15:00:00 +0100
comments: true
categories: [haskell, shake]
---
At [NoRedInk](http://noredink.com) we've been looking into using [Shake](https://shakebuild.com/) to incrementally build large polyglot projects. In general, it's been a great tool to work with, but there were a few things that caught us out, so I wanted to capture some of that learning before it got lost.

Shake is basically a domain specific language built on top of Haskell, so knowing Haskell can definitely help you unlock it's full power. But you can get a long way for basic builds by just working with some simple building blocks. You will have to jump through some extra hoops to get it installed and write your scripts with editor support if you're not using Haskell anyway - but we are, so that wasn't much of an obstacle for us!

I'm not going to go into the really basic ideas behind Shake: the main website (linked above) has a good introductory demo, and Neil Mitchell (who wrote Shake) has given numerous (very well done) talks on the ideas behind it. What I'm going to do over a few posts is look at some of the things which caught us out, and what you can do about them. I'll try and remember to link each post here as it comes out!

<!-- more -->

In this introduction, I'm going to show you the mini-example project that we'll be using in each of the following blog posts. All of the examples can be seen in full (with runnable code!) at [https://github.com/mavnn/shake-examples](https://github.com/mavnn/shake-examples), but if you want just want to follow along you can pretend and just read the Shake files here.

Our "base" Shake file just knows how to build a Haskell project from a group of "*.hs" files in the `src` directory - everything else will build up from there! This is our starter `Shakefile.hs`:

``` haskell
module Shakefile
  ( main
  )
where

import Development.Shake
import Development.Shake.FilePath

main :: IO ()
main =
  shakeArgs
    shakeOptions
      { shakeFiles = "_build"
      , shakeChange = ChangeModtimeAndDigest
      , shakeColor = True
      , shakeThreads = 4 -- default to multicore!
      } $ do
    want
      [ "_build" </> "main" <.> exe
      ]
    rules

rules :: Rules ()
rules = do
  -- Clean build artifacts (including shake history)
  phony "clean" $ do
    putNormal "Cleaning _build"
    removeFilesAfter "_build" ["//*"]
  -- Build our Haskell application
  "_build" </> "main" <.> exe %> \out -> do
    src <- getDirectoryFiles "" ["src//*.hs"]
    need src
    cmd_
      "ghc"
      ("src" </> "main.hs")
      "-isrc"
      "-outputdir"
      "_build"
      "-o"
      out
```

What does this do? Well, there's a bit of boilerplate to import the `Shake` libraries and configure Shake. We also set the wanted output of a default build in this `main` function: in this case an executable called `main` in the `_build` directory (or `main.exe` on Windows).

Then we have two rules:

- one 'phony' rule (it doesn't create a file) that knows how to delete our build artifacts
- a rule that knows how to build the desired output file

This second rule goes through a few steps:

- It calls `getDirectoryFiles` to get *and depend on* the list of "*.hs" files in the src directory. If any *.hs files are added or removed, the rule will be re-run.
- It `need`s all of the *.hs files it found. This means that if the content of any of those files changes, the rule will be re-run.
- Finally, it calls `ghc`, a Haskell compiler, telling it to put all of it's build artifacts and the output file in the `_build` directory.

Now: let's start looking at how to build in some more troublesome (or at least, less obvious) functionality you might want in a larger project.

1. [Linting And Formatting](/shake-linting)
1. [Generated Files](/shake-generated-files/)
