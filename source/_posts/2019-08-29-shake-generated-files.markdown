---
layout: post
title: "Shake: Generated Files"
date: 2019-09-09 17:00:00 +0100
comments: true
categories: [haskell, shake]
---
> This post is part of a series! If you haven't already, check out [the introduction](/shake-the-intro/) so you know what's going on.

It's fairly obvious how dependencies work in Shake when all of the files are known while you're writing your rules.

And if a build rule creates a single file matching a pattern, or even a known set of files based on a pattern: that's pretty simple too. Just add a rule ([%>](https://hackage.haskell.org/package/shake-0.17.1/docs/Development-Shake.html#v:-37--62-) for building a single file, [&%>](https://hackage.haskell.org/package/shake-0.17.1/docs/Development-Shake.html#v:-38--37--62-) for a list) and then when you `need` one of the outputs Shake knows how to make sure it's up to date.

Life becomes a little more interesting when you have a rule that takes multiple inputs (detected at run time) and creates multiple outputs (depending on what was found).

Let's look at an example. We're writing a computer game, and the game designers want to be able to quickly specify new types of characters that can exist. The designers and developers settle on a compromise; they'll use Yaml with a few simple type names the developers will teach the designers.

So the designers start churning out character types, which look like this:

``` yaml
name: Fighter
insaneToughness: Integer
ridiculousStrength: Integer
```

or this:

``` yaml
name: Rogue
sneakyTricks: "[String]"
```

The developers, on the other hand, want to be able to consume nice safe Haskell types like so:

``` haskell
import Generated.Fighter
import Names

main :: IO ()
main = do
  putStrLn $ "Hello, " ++ world ++ "!"
  print
    ( Fighter
      { insaneToughness = 5
      , ridiculousStrength = 10
      }
    )
```

And we want our code to break at compile time if, for any reason, the Yaml files get changed and we start relying on things that no longer exist. So we're going to set up a build rule that builds a directory full of nice type safe code from a directory full of nice concise and easy to edit Yaml.

<!-- More -->

Let's see what we can come up to build this safely. Our first shot at a replacement build `Rule` looks like this:

``` haskell
  "_build" </> "main" <.> exe %> \out -> do
    src <- getDirectoryFiles "" ["src//*.hs"]
    -- depend on the generated Haskell as well
    -- as hand written files
    need ["_build/haskell_generation.log"]
    generated <- getDirectoryFiles "" ["src" </> "Generated//*.hs"]
    need $ src ++ generated
    cmd_
      "ghc"
      ("src" </> "main.hs")
      "-isrc"
      "-outputdir"
      "_build"
      "-o"
      out
```

This looks very similar to the previous build rule, with just the addition of a few lines to account for the generated files. The only slightly quirky moment is `need ["_build/haskell_generation.log"]`; we need this because Shake has no concept of a rule for a directory. So the rule for `_build/haskell_generation.log` creates all of our generated files, so that we can then "get" them on the line below.

We also need to add the rules for `_build/haskell_generation.log` and for files in the generated directory, to make sure they're generated before they are used.

``` haskell
  -- Make sure if a generated file is needed, it has been
  -- created
  priority 2 $ "src" </> "Generated//*.hs" %> \_ ->
    need ["_build/haskell_generation.log"]
  -- Target ensures all haskell files are built
  "_build/haskell_generation.log" %> \out -> do
    yamlFiles <- getDirectoryFiles "" ["yaml_types//*.yaml"]
    need yamlFiles
    createHaskellFiles yamlFiles
    writeFileLines out yamlFiles
    -- Make sure we rerun if the list of files in src/Generated
    -- changes
    _ <- getDirectoryFiles "" ["src" </> "Generated//*.hs"]
    pure ()
```

`createHaskellFiles` here is the logic that writes the Generated files, but it could easily be some external tool being called via a script.

Then you run shake, and ... the code works! Awesome, we're done, right?

Well, maybe not. The first sign something might be wrong is in the docs. The docs for [getDirectoryFiles](http://hackage.haskell.org/package/shake-0.17.3/docs/Development-Shake.html#v:getDirectoryFiles) state: "As a consequence of being tracked, if the contents change during the build (e.g. you are generating .c files in this directory) then the build not reach a stable point, which is an error - detected by running with --lint. You should normally only call this function returning source files."

That doesn't sound good. Maybe we should check the behaviour of our code.

Let's delete one of the generated files, and run Shake again to check it detects that:

``` sh
$ rm src/Generated/rogue.hs
$ shake
Formatting build files
# ormolu (for src/Generated/rogue.hs)
# ghc (for _build/main)
Build completed in 0.51s
```

Whew! Maybe we're okay. We'll just run it once more:

``` sh
$ shake
Formatting build files
# ghc (for _build/main)
Build completed in 0.23s
```

Oh. That's not good: nothing has changed, so why have we invoked `ghc`?

Here we hit something very, very, important to understand about `getDirectoryFiles` (and other Shake Rules and Oracles): they only run once per invocation of Shake.

Let's step through the implications of what this means on each of the build runs.

### Run 1 (from clean)

- We ask for the `_build/main` executable to be built; it doesn't exist, so the `Action` in the `Rule` runs
- Among other things, we ask for `_build/haskell_generation.log`; it also doesn't exist, so we run it's `Action`. Several files (let's say, `fighter.hs` and `rogue.hs`) get written to the generated file directory
- We call `getDirectoryFiles`, telling Shake that we depend on the generated files directory having `fighter.hs` and `rogue.hs` and no other Haskell files
- We need the content of all the source files and build the executable.

### Run 2 (deleted `rogue.hs`)

- We ask for the `_build/main` executable to be built; it exists, so Shake starts checking if it's dependencies have changed
- Among other things, it call `getDirectoryFiles` on the generated file directory, and records that there's now only `fighter.hs` in there: the file list has changed
- `_build/main` has changed dependencies so we run it's `Action`
- During that action, `getDirectoryFiles` is called on the Generated file directory. It has already been run (see above) so Shake does not run it again: it records that only `fighter.hs` is depended on _even though `rogue.hs` has now been recreated_
- We build the executable

### Run 3 (no change)

- We ask for the `_build/main` executable to be built; it exists, so Shake starts checking if it's dependencies have changed
- Among other things, it call `getDirectoryFiles` on the generated file directory, and records that there's now both `fighter.hs` and `rogue.hs` in there: the file list has changed again!
- `_build/main` has changed dependencies so we run it's `Action`

In fact, it turns out that if we turn on linting in Shake it will tell us about this problem:

``` sh
$ shake --lint
# ormolu (for src/Generated/fighter.hs)
# ghc (for _build/main)
[2 of 3] Compiling Generated.Fighter ( src/Generated/Fighter.hs, _build/Generated/Fighter.o )
Linking _build/main ...
Lint checking error - value has changed since being depended upon:
  Key:  getDirectoryFiles  [src//*.hs]
  Old:  (src/Names.hs src/main.hs src/Generated/rogue.hs,"")
  New:  src/Names.hs src/main.hs src/Generated/fighter.hs src/Generated/rogue.hs
```

## Back to the drawing board

So: what do we want from our rules here? Let's actually put down the end effect we're aiming for:

- If there are any Yaml files are added, removed or changed, we should regenerate
- If any of the Generated files have been removed or changed, we should regenerate
- If a generated file is `need`ed, we should check we have an up to date set of generated files
- If the input and output files are unchanged since the last run, we should not regenerate

We can't call `getDirectoryFiles` on the generated Haskell files, for the reason given above; and we can't call `need` on the Haskell files after generating them in the `_build/haskell_generation.log` to rebuild if they change, because they themselves `need` the Haskell generation.

We're going to have to break out some bigger guns.

Firstly, we're going to want to encode from custom logic for when to rebuild based on the environment. We model this is Shake by setting up an "Oracle"; this allows us to store a value in the Shake database, and if it changes between one run and the next anything which depends on it is considered dirty and needs rebuilding.

Secondly, `_build/haskell_generation.log` is going to stop being just a "stamp" file to get around the fact that Shake doesn't know about directories, and we're going to start storing some useful info in there.

Of course, we still need to be careful: just like running `getDirectoryFiles`, our Oracle is only going to be evaluated once for the whole run of Shake, and it will be evaluated to check dependencies before the actual rules which depend on it are run.

Let's go with a model where we assign each run of the generator a unique ID, which we'll use in our Oracle and stash in our output file so that we can return the same ID if nothing has changed on disk.

We'll create some reusable code to do this; we'll take a list of patterns for generated files this rule controls, an output file, and an action to generate the files. I'll show you the code in full, and there's some explanation underneath:

``` haskell
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

module Shakefiles.Generator
  ( generator
  , getGeneratedFiles
  , runIdOracle
  )
where

import Control.Applicative ()
import Data.Aeson
import qualified Data.ByteString.Lazy as B
import qualified Data.UUID as UUID
import Data.UUID.V4 (nextRandom)
import Development.Shake
import Development.Shake.Classes
import qualified System.Directory as Directory

newtype GetRunId
  = GetRunId (FilePath, [FilePattern])
  deriving (Show, Typeable, Eq, Hashable, Binary, NFData)

type instance RuleResult GetRunId = UUID.UUID

runIdOracle :: GetRunId -> Action UUID.UUID
runIdOracle (GetRunId (filePath, patterns)) = do
  recordExists <- liftIO $ Directory.doesFileExist filePath
  if recordExists
  then
    do
      recorded <- decode <$> liftIO (B.readFile filePath)
      case recorded of
        Just (lastRunId, generatedFiles) -> do
          filesOnDisk <- liftIO $ getDirectoryFilesIO "" patterns
          if filesOnDisk /= generatedFiles
          then liftIO nextRandom
          else pure lastRunId
        Nothing ->
          liftIO nextRandom
  else liftIO nextRandom

recordGeneratedFiles :: UUID.UUID -> FilePath -> [FilePattern] -> Action ()
recordGeneratedFiles runId out patterns = do
  filesCreated <- liftIO $ getDirectoryFilesIO "" patterns
  liftIO $ B.writeFile out $ encode (runId, filesCreated)

generator :: FilePath -> [FilePattern] -> Action () -> Rules ()
generator out generatedPatterns generationCmd = do
  generatedPatterns |%> \_ -> need [out]
  out %> \_ -> do
    runId <- askOracle $ GetRunId (out, generatedPatterns)
    liftIO $ removeFiles "" generatedPatterns
    generationCmd
    recordGeneratedFiles runId out generatedPatterns

```

The file starts with some boiler plate code needed for storing the unique identifier in the shake database.

Then we have the logic for creating a run ID:

- Check if an output file already exists. 
- If it does:
  - we'll read the last UID and list of files created from it
  - We'll read the list of files that match the generated pattern 
  - If the two lists don't match, new UID is created
  - If they do, we return the same UID as last time
- If it doesn't, we'll create a new UID

That means that if the list of generated files has changed, we know we need to run the generator.

Then we have a rule that matches all of the patterns for files which will be generated, and depends on the output file.

Finally, we have the rule for the output file:

- this acquires a run ID
- deletes any files that match the generated patterns (this ensures that we don't end up with "stale" generated files that no longer have a creator)
- runs the generation Action the user provided
- and finally writes the output file with the run ID used and the list of files created

This completes the loop and lets us check next time around if the list of generated files has changed.

What does it look like to use? Something like this:

``` haskell
  -- This goes in our Shake Rules "do" block
  _ <- addOracle runIdOracle
  priority 2 $
    generator
      "_build/haskell_generation.log"
      ["src" </> "Generated//*.hs"]
      writeHaskellFiles
  where
    writeHaskellFiles = do
      yamlFiles <- getDirectoryFiles "" ["yaml_types//*.yaml"]
      need yamlFiles
      createHaskellFiles yamlFiles
```

We have to add the oracle to our rules (only once, not per generator). Then we just call our reusable code with specify the output file, the pattern of files out will be generated, and the logic to generate them (including specifying dependencies of the process). 

We're nearly there, but we still have a problem. We called `getDirectoryFiles` on the Haskell source files in our Haskell compile build rule! It turns out that it's not just in the Rules for the generated files themselves that you need to be careful: you just can't reliably call `getDirectoryFiles` on generated files anywhere in your build specification.

We can get around that in two ways. One is that we can separate depending on source files (call `getDirectoryFiles` with a pattern that doesn't include any of the generated files) from the generated files, and add a helper like the one below to get which files have been generated:

``` haskell
getGeneratedFiles :: FilePath -> Action [FilePath]
getGeneratedFiles out = do
  need [out]
  recordFile <- decode <$> liftIO (B.readFile out)
  case recordFile of
    Just (_ :: UUID.UUID, rf) ->
      pure rf
    Nothing ->
      fail ""
```

Usefully, this also ensures that if you ask for the list of generated files the file generation rule will be called!

Alternatively, if we're happy that all of our input files have now been created, we can often get our tools themselves to tell us what they used. Shake allows us to call the `needed` function here to record a dependency that we've already used. Be aware though that this will error if anything changes the `needed` file after you used it!

As an example, we can combine the use of `ghc`'s dependency generation flag and Shake's makefile parser to rewrite our Haskell rule to the following:

``` haskell
  "_build" </> "main" <.> exe %> \out -> do
    need ["_build/haskell_generation.log"]
    cmd_
      "ghc"
      ("src" </> "main.hs")
      "-isrc"
      "-dep-suffix hs"
      "-outputdir"
      "_build"
      "-o"
      out
    withTempFile
      ( \tmpFile -> do
        cmd_
          Shell
          "ghc"
          ("src" </> "main.hs")
          "-isrc"
          "-outputdir"
          "_build"
          "-o"
          out
          "-dep-makefile"
          tmpFile
          "-dep-suffix ''"
          "-M"
        makeStuff <- liftIO $ readFile tmpFile
        putNormal makeStuff
        neededMakefileDependencies tmpFile
      )
```

This runs the compile process, and then calls `ghc` telling it to write all of the dependencies it used to a temporary makefile. We then use `neededMakefileDependencies` to specify that we did use those files, even if we didn't know we were going to before building.

Just make sure that you've needed anything that the build system needs to create/update before you run your compile action though!
