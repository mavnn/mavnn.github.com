---
layout: post
title: "Shake: Linting And Formatting"
date: 2019-09-09 16:00:00 +0100
comments: true
categories: [haskell, shake]
---
> This post is part of a series! If you haven't already, check out [the introduction](/shake-the-intro/) so you know what's going on.

There's a bunch of nice tools out there these days that operate on your source code itself, such as auto-formatting and linting tools.

How to configure rules for this kind of thing in Shake isn't immediately obvious when you're new to using it. The first time I did it, I ended up with something that looked like this (only showing relevant rules):

``` haskell
  "_build" </> "main" <.> exe %> \out -> do
    src <- getDirectoryFiles "" ["src//*.hs"]
    cmd_
      "hlint"
      src
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

Which at first glance looks great! I've made sure that I find and run `hlint` (a Haskell linting tool) on the source files before I "need" them - remember, once a file has been "needed" in Shake it should not be changed. The code is simple and easy to read. `hlint` gets efficiently run on the whole list of source files all at once.

What's not to like?

<!-- More -->

Well: there can be a couple of issues here. One (doesn't happen often in Haskell, but happens a lot in dynamic languages!) is that several targets could all depend on the same source file. Do all of the targets run the formatter? Who gets there first?

The other problem is that if any source file changes, the command has to be re-run on all of them: if you have a lot of source files and a slow linter or formatter, that's a big problem. In fact, avoiding that kind of thing is the reason most people start using Shake in the first place!

So we need to move the formatting/linting into the rule for the source file itself: this is the only way to guarantee that whoever uses the file, whenever they use it in the build process, the file will already be formatted before it's read.

Version two of my code ends up looking like this:

``` haskell
  -- actually build the executable
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
  -- nicely format and lint all our source files
  "//*.hs" %> \out -> do
    disableHistory
    cmd_ "ormolu" "-m" "inplace" out
    cmd_ "hlint" out
```

This is Shake at its best: super explicit, clear and easy to read. The only slightly quirky thing here is the call to `disableHistory`; rules where the output and the input are the same file don't play nicely with Shake's optional caching system (`shakeShare` and in the future `shakeCloud`) so we specify that this rule shouldn't try and use cached results.

Unfortunately, we do still have a problem: formatting/linting software is often very fast per file, but normally has a short start up time. When you're starting to format 1,000s of files, that start up time becomes a problem. So now we have technically correct, but unusable code.

Fortunately, the authors of Shake have come across this issue before, and included the amazingly useful `batch` helpers.

To use `batch` we need a few things:

- a maximum batch size
- a "match" function to specify which files this batch handles
- a "preparation" function that carries out any actions that should be run on the files individually (`a -> Action b`)
- a "batch" function to process a batch of outputs from the preparation function (`[b] -> Action a`)

Behind the scenes, the first time that Shake finds that a target is supplied by a batch function, it doesn't queue building that target immediately. Instead, it runs any preparation steps and then punts the batch to the end of the queue. It keeps on doing this until it either a) runs out of work to do that isn't in the batch (at which point it will start with whatever size batch it has) or b) the maximum batch size has been queued. Then it will run the batch command.

It looks like this:

``` haskell
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
  -- Format and lint our source files
  batch 10 ("//*.hs" %>)
    ( \out -> do
      historyDisable
      -- called per file as ormolu
      -- processes files one at a time
      cmd_ "ormolu" "-m" "inplace" out
      pure out
    )
    -- lint all the files in batches
    (cmd_ "hlint")
```

Voilà! Correct, fast code.

Of course, engineering reality is full of trade offs, and we have made one here. Because the `batch` action is run on a list of files, that means that if any one file fails the batch, the entire batch is counted as failing. This is also true if an other rule fails while a batch is processing and Shake cancels the batch.

So while it might be tempting to just turn the batch number up and run the whole lot at once, it might be a better idea to spend a little time tuning the numbers to match the size of your code base and the speed of each batch.

Next up: working with [generated files](/shake-generated-files/).
