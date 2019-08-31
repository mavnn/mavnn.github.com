---
layout: post
title: "Shake: Linting"
date: 2019-08-28 19:26:09 +0100
comments: true
categories: [haskell, shake]
---
Especially when you're working with dynamic languages, linting can be a real life saver. We're also big fans of automated source formatting on team projects, which can be a very low effort way of encouraging a recognisable "look and feel" across a whole project with out everyone having to learn all the niggles of the company style guide by hand.

How to configure rules for this kind of thing in Shake isn't immediately obvious when you're new to using it. The first time I did it, I ended up with something that looked like this:

``` haskell
    "endpoint.js" %> \out -> do
        srcFiles <- findElmDependencies out
        cmd_ "elm-format" srcFiles
        need srcFiles
        cmd_ "jetpack" out
```

Which at first glance looks great! I've made sure that I find and run `elm-format` on the source files before I "need" them (remember, once a file has been "needed" in Shake it should not be changed). The code is simple and easy to read. `elm-format` gets efficiently run on the whole list of source files all at once.

What's not to like?

Well... the problem comes when there's more than one end point:

``` haskell
    "endpoints/*.js" %> \out -> do
        srcFiles <- findElmDependencies out
        cmd_ "elm-format" srcFiles
        need srcFiles
        cmd_ "jetpack" out
```

If `findElmDependencies` reports overlapping lists of source files (i.e. any shared code between your projects), all of those files will have `elm-format` run on them multiple times. Even worse, if in some other rule we `need` an Elm file before an endpoint using it has compiled, we risk changing the Elm file in this endpoint rule after it's been used somewhere else. In Shake terms, this breaks all of our dependency tracking and incremental build guarantees, so we want to avoid that.

So we need to move the formatting into the rule for the Elm file itself: this is the only way to guarantee that whoever uses the file, whenever they use it in the build process, the file will already be formatted before it's read.

Version two of our code ends up looking like this:

``` haskell
    "//*.elm" %> \out -> do
        cmd_ "elm-format" out

    "endpoints/*.js" %> \out -> do
        srcFiles <- findElmDependencies out
        need srcFiles
        cmd_ "jetpack" out
```

This is Shake at its best: super explicit, clear and easy to read. Unfortunately, we have a new problem: `elm-format` is very fast per file, but has a short start up time. When you're starting to format 1,000s of files, that start up time becomes a problem. So now we have technically correct, but unusable code.

Fortunately, the authors of Shake have come across this issue before, and included the amazingly useful `batch` helpers.

To use `batch` we need a few things:

- a maximum batch size
- a "match" function to specify which files this batch handles
- a "preparation" function that carries out any actions that should be run on the files individually (`a -> Action b`)
- a "batch" function to process a batch of outputs from the preparation function (`[b] -> Action a`)

Behind the scenes, the first time that Shake finds that a target is supplied by a batch function, it doesn't queue building that target immediately. Instead, it runs any preparation steps and then punts the batch to the end of the queue. It keeps on doing this until it either a) runs out of work to do that isn't in the batch (at which point it will start with whatever size batch it has) or b) the maximum batch size has been queued. Then it will run the batch command.

It looks like this, in the simplest case where there's no preparation needed:

``` haskell
    batch
      100 -- maximum number of files per batch
      ("//*.elm" %>) -- match all elm files
      return -- don't do any logic/actions on the individual files
      cmd_ "elm-format" fileNames -- format the batch

    "endpoints/*.js" %> \out -> do
        srcFiles <- findElmDependencies out
        need srcFiles
        cmd_ "jetpack" out
```

Voilà! Correct, fast code.

Of course, engineering reality is full of trade offs, and we have made one here. Because the `batch` action is run on a list of files, that means that if any one file fails the batch, the entire batch is counted as failing. This is also true if an other rule fails while a batch is processing and Shake cancels the batch.

So while it might be tempting to just turn the batch number up and run the whole lot at once, it might be a better idea to spend a little time tuning the numbers to match the size of your code base and the speed of each batch.
