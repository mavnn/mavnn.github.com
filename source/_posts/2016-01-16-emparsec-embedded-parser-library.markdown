---
layout: post
title: "EmParsec Embedded Parser Library"
date: 2016-01-18 12:53:11 +0000
comments: true
categories: [fsharp, programming, typeprovider, logibit]
---
> You can find EmParsec on GitHub: https://github.com/mavnn/EmParsec 

Type providers, by their very nature, tend to access data external to the .net ecosystem. It can also be very awkward technically to make use of dependencies during the actual type generation process.

This is rather a pity, because accessing all of that external data is much nicer and easier when you have a decent parser to do it with. And F# has very, very nice parser support via the [FParsec](http://www.quanttec.com/fparsec/) library. Instead, many (most?) type providers end up creating mini-one shot parsers which can be a bit slow to write and don't tend to have features that come for free in a more complete solution such as nice error reporting.

Writing yet an other parser (YAOP) this week I decided that enough was enough. What I needed was a shared resource that people could pool improvements for that could be easily embedded in projects like type providers were it isn't desirable (or sometimes possible) to take external binary dependencies.

So I built it.

<!-- more -->

EmParsec is a single file parser combinator "library", inspired by both FParsec library and [Scott's excellent series on building parser combinators](http://fsharpforfunandprofit.com/posts/understanding-parser-combinators/).

It consists of a single fs file that can be loaded in the editor of your choice without any requirement for a project file or similar. When you want to use it, you can just reference it as a [Paket GitHub dependency](https://fsprojects.github.io/Paket/github-dependencies.html) (which you'll be wanting to do for the ProvidedTypes.fs file if you're creating a type provider anyway) or even just copy the file across.

If you are compiling EmParsec into a larger project, it marks itself as "internal" so that you don't pollute the end users name space, and so that if two projects you reference have embedded different versions of EmParsec there are no collisions.

## How do I use it?

So, you've added EmParsec.fs to your project (manually or with Paket) and now you're wondering how to use it. Let's build some simple examples.

### Matching an exact string

Let's start with something simple: what if I just want to match a string?

Parser combinator libraries allow you to combine parsers from simpler parsers (hence the name), but in this case ``pstring`` (the 'p' is there to avoid clashing with the existing ``string`` function) is provided for us by EmParsec.

Let's try it out!

``` fsharp
open EmParsec

let thingParser = pstring "thing"
// When you enter this line, F# give a "Value restriction" error.
// You can either mark thingParser as type UParser<string>, or
// use the parser with run as below and the error will disappear.

run thingParser "thing"
// val it : Choice<string,string> = Choice1Of2 "thing"

run thingParser "th1ng"
// val it : Choice<string,string> =
//   Choice2Of2
//     "Parser <string thing> failed at line 0 column 2
// Unexpected ['1']
// th1ng
//   ^"
```

Not bad! It even marks the unexpected character in the error output.

Unfortunately:

``` fsharp
run thingParser "thing and more"
// val it : Choice<string,string> = Choice1Of2 "thing"
```

That probably isn't the behaviour you were hoping for. There's still input left after the parser has finished, but that isn't being seen as an error. EmParsec includes the ``eof`` parser for just this type of occasion - a parser that checks the input is exhausted.

So we want a parser that parses "thing" and then ends.

Let's go:

``` fsharp
let thingParser2 = andThen (pstring "thing") eof
// normally written
let thingParser2' = pstring "thing" .>>. eof

run thingParser2 "thing"
// val it : Choice<(string * unit),string> = Choice1Of2 ("thing", null)

run thingParser2 "th1ng"
// val it : Choice<(string * unit),string> =
//   Choice2Of2
//     "Parser (<string thing> andThen <end>) failed at line 0 column 2
// Unexpected ['1']
// th1ng
//   ^"

run thingParser2 "thing and more"
// val it : Choice<(string * unit),string> =
//   Choice2Of2
//     "Parser (<string thing> andThen <end>) failed at line 0 column 5
// Unexpected input remaining ' and more'
// thing and more
//      ^"
```

That's more like it. The only issue now is that we've combined two parser, so we're getting back a tuple of two results.

A simple tweak tells EmParsec to throw away the unit result returned by ``eof``.

``` fsharp
let improvedThingParser = pstring "thing" .>> eof

run improvedThingParser "thing"
// val it : Choice<string,string> = Choice1Of2 "thing"
```

"Impressive," I hear you say: "You can parse static strings!"

### Parsing a simple template language

You have a point. Let's tackle a simple template language. You know the kind of thing:

``Welcome {name}! Please spend money here.``

That kind of thing. I'm going to start building up a set of helper parsers for this, applying some type annotations both to make the example code clearer and to avoid the value restriction errors that crop up until you actually use the parsers (those occur because these parsers can carry generic user state, but we're not going to go into using that here).

We have two "types" of token that can exist in our template language: values to be replaced, and text to be preserved. Let's start by creating a union type to contain our parse results:

``` fsharp
type TemplatePart =
  | Text of string
  | Value of string
```

Then, we'll have a parser that will parse individual characters which are *not* an opening bracket:

``` fsharp
let notOpenBracket : UParser<char> =
  satisfy (fun c -> c <> char '{') "not open bracket"
```

``satisfy`` is a function built into EmParsec which takes a predicate for whether or not it will consume the next character in the input stream. The final string argument is a name for the parser, which will be used in error messages.

Then we'll use that parser to create one that consumes as many "not open bracket" characters as it can, combines them into a string and then counts that string as a ``Text`` part.

``` fsharp
let textParser : UParser<TemplatePart> =
  many1 notOpenBracket
  |>> (fun charList ->
         charList
         |> List.map string
         |> String.concat ""
         |> Text)
  <?> "<text parser>"
```

There's a new function here and a couple of new operators (all taken from FParsec, by the way). ``|>>`` is a map operator; it allows you to transform the result of a parser and then rewrap everything back up into a new parser. This is really at the heart of the power of parser combinator libraries.

The ``<?>`` operator is much simpler: it allows you to name a parser rather than its name being some combination of the parsers it's built of.

The ``many1`` function says "match one or more instances of the parser that follows". There is also a ``many``, which matches 0 or more repeats.

So that's good - we can capture the text in between our replacable values. Let's go with a parser for the bracketed value names next!

``` fsharp
let valueName : UParser<string> =
  many1 (satisfy (fun c -> c <> '}' && (not <| System.Char.IsWhiteSpace c)) "")
  |>> (fun charList -> charList |> List.map string |> String.concat "")

let openValue : UParser<unit> =
  pchar '{' .>>. spaces
  |>> ignore

let closeValue : UParser<unit> =
  spaces .>>. pchar '}'
  |>> ignore

let value : UParser<TemplatePart> =
  between openValue closeValue valueName
  |>> Value
  <?> "<value parser>"
```

So we now have parsers for white space and our "valueName" (which we are saying must be at least one character long, and can consist of any character which is not whitespace or a closing curly bracket). We can then use pchar ("parse char") and whitespace to allow for minor variations in syntax (some people like ``{name}``, others like ``{ name }``).

Finally we build our value parser, using the ``between`` function, which does pretty much what you'd expect: it takes an opening parser, a closing parser, and captures what's in between with third parser.

Our final step is just to combine our parsers for value and text sections. We want to capture "many" of one or the other, until we run out of input. We'll put an explicit ``eof`` on there as well, otherwise things like (for example) an unclosed ``}`` at the end of the string will not show up as an error - the parser will just stop at the character before the opening ``{`` as the last matching input.

Our final parser introduces the ``<|>`` (orElse) operator, and looks like this:

``` fsharp
let template : UParser<TemplatePart list> =
  many (value <|> textParser)
  .>> eof
  <?> "<template parser>"
```

Let's try it out!

``` fsharp
open System.Text

let showTemplate values parts =
  let folder (sb : StringBuilder) part =
    match part with
    | Text s ->
      sb.Append s
    | Value v ->
      defaultArg (Map.tryFind v values) ""
      |> sb.Append
  let sb = List.fold folder (StringBuilder()) parts
  sb.ToString()

let values = Map [ "name", "bob" ]

let run' parser str =
  run parser str
  |> function
     | Choice1Of2 success -> showTemplate values success
     | Choice2Of2 fail -> failwithf "Parsing failed!\n%s" fail
```

A couple of helpers: ``showTemplate`` knows how to build up a string from a list of template parts and a value map, ``run'`` is just a simple wrapper around ``run`` that throws if parsing is not successful.

``` fsharp
let ex1 = "Welcome {name}! Please spend money here!"
let ex2 = "hello { name } thing"

run' template ex1
// val it : string = "Welcome bob! Please spend money here!"

run' template ex2
// val it : string = "hello bob thing"

let ex3 = "Hello, { name }! How about {
 date:alreadyrendered?
}? <- That should be left blank, but parse as valid."

run' template ex3
// val it : string =
//   "Hello, bob! How about ? <- That should be left blank, but parse as valid."
```

And finally our templates in action. You can see that even with a simple parser like this, it's already reaching a complexity that would be painful to match with a hand rolled creation.

If you want to know more about parser combinators, and especially how to use them to create recursive grammars, do check out the [FParsec documentation](http://www.quanttec.com/fparsec/) which is excellent. It is also more complete and *much* more performant than EmParsec.

But if you need a small, single file parser where performance is not the primary concern - maybe EmParsec is your friend. Anyone who wants to join in making it better is more than welcome! Of particular note is that EmParsec does not yet support controlling when backtracking does or doesn't happen (it will always backtrack) which can make for some pretty confusing error messages.
