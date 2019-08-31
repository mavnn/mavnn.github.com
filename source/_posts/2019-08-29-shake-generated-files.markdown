---
layout: post
title: "Shake: Generated Files"
date: 2019-08-29 12:35:31 +0100
comments: true
categories: [haskell, shake]
---
One thing which kept us going for a long time in Shake was how to deal with build steps which build a directory of files. For example, in our Elm code base we have a `generated` directory which contains Elm source files created by tools like [Elm GraphQL](https://github.com/dillonkearns/elm-graphql).

