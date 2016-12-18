---
layout: post
title: "Xenogloss: Speaking to the World"
date: 2016-07-15 16:39:13 +0100
comments: true
published: false
categories: [fsharp, typeproviders]
---
The world is an increasingly international place, and whether you're writing services or applications it's often a requirement to localise it. But that can be a painful experience, especially if your localisation needs to account for dynamic information.

Xenogloss sets out to make your life easier if you're creating localised F# code. It makes use of the F# compilers type provider mechanism to provide you with two main features: type safe dynamic messages, and automatically updated translation files. It also tries to make use of existing standards to allow you to plug into the translation software tooling that already exists out there.

Staying close to the source
---------------------------

As part of the [Qvitoo](https://qvitoo.com) project we're making use of the [React Intl](https://github.com/yahoo/react-intl) library created by Yahoo. It has several features we decided we wanted to... er... be inspired by, the first of which is that you define the translatable message at point of use.

Some people like this, and some don't, but for us it makes sense: the person who knows most about what the message should be is the person trying to consume it.

So in Xenogloss, you create messages in your code:

``` fsharp
open Xenogloss

// a message context is a logical group of messages - could be
// per dll, or per module
// The first parameter sets the default culture for messages in
// this context (if no translation is available in the user's culture,
// this culture will be used)
type messageContext = MessageContext<"en", "My.Logical.Boundary.Name">

let hello =
  // A message with the id "hello", and content "Hello world" in the default language
  messageContext.Create<"hello", "Hello world">()

let myFunctionThatSendsTextToAUser userContext =
  hello.show userContext 
```

This is even more useful in place where you need to supply parameters to a message:

``` fsharp
let greeting =
  messageContext.Create<"greeting", "Hello { name }">()
  
let greetBob userContext =
  // returns "Hello Bob"
  greeting.show "Bob" userContext
  
let greetPerson name userContext =
  // name is of type string here
  greeting.show name userContext
```

Use the standards, Luke
-----------------------

Obviously the ``{ name }`` is some way of defining a parameter. Following (again) the example of React Intl, we decided to stick with [ICU Message Syntax](http://formatjs.io/guides/message-syntax/).

Built into the syntax are various clues as to the type of parameter expected, which we make use of:

``` fsharp
let checkAge =
  messageContext.Create<"number", "{0}, are you {1,number} years old?">()
  
let confirmAgeOfBob name age userContext =
  checkAge.show "Bob" 10.0M userContext
```
