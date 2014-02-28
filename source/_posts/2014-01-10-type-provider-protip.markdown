---
layout: post
title: "Type Provider ProTip"
date: 2014-01-10 12:15:15 +0000
comments: true
categories: [fsharp, programming, typeprovider, tpProTip]
---
While type providers are incredibly powerful, the ProvidedTypes api for creating them is sometimes a bit rough around the edges. And not always as functional as you might hope.

At some point I'd like to do something about that, but for the moment I'm just going to collect a few helpful tips and hints (mostly for own reference).

Tip one is in the case where you have XmlDocs to add to ProvidedTypes, ProvidedMethods and ProvidedProperties; in our case we have an optional description field in our metadata and the boiler plate was getting tiresome.

``` fsharp
let inline addDoc (desc : Descriptor) def =
    match desc.Description with
    | Some d ->
        (^T : (member AddXmlDoc : string -> unit) (def, d))
    | None -> ()
```

This function takes a `Descriptor` with a `string option` Description field and any `def` with an AddXmlDoc member with the noted signature - and adds description as the xml doc if it exists.

