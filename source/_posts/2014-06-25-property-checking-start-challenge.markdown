---
layout: post
title: "Property Checking Start Challenge"
date: 2014-06-25 12:25:17 +0100
comments: true
categories: [fsharp, csharp]
---

Almost a year ago now, I wrote up a [blog post](/fscheck-breaking-your-code-in-new-and-exciting-ways/) on using [FsCheck](https://github.com/fsharp/FsCheck). I still rate it as an excellent tool, but unfortunately we don't manage to use it that much. The reasons for this basically boil down to the fact that a) we tend to forget it exists and b) a good deal of our code is written in C# or VB.net, and the original API is not very friendly from those languages.

So as part of the [15below](http://15below.com/) developer education sessions we're going to try an exercise to see if we can bring a bit more property based testing into our code base!

<!-- more -->

## Never trust the user...

One of the things we do quite a lot of as a company is sending either automated voice calls or SMS messages. The phone number we're trying to contact is often free text provided by the customer, while the voice/SMS companies tend to be very keen on phone numbers that are in (something at least similar to) the [international E.164](http://en.wikipedia.org/wiki/E.164) phone number format.

Unfortunately, users don't tend to very good at sticking to standards in free text fields - so it some point your code needs to make the call about whether you're convinced the phone number you have is valid or not...

For the exercise, I've created idiomatic stubs of a ``PhoneNumber`` class in both F# and C# with methods for creating them that check if the input string is valid. The C# version uses ``PhoneNumber.TryParse``:

```csharp
using System;
using System.Linq;
using System.Text.RegularExpressions;

namespace CSharp.FsCheck
{
    public class PhoneNumber
    {
        public int CountryCode { get; private set; }
        public int IdentificationCode { get; private set; }
        public int SubscriberNumber { get; private set; }

        private PhoneNumber() { }

        private PhoneNumber(int countryCode, int identificationCode, int subscriberNumber)
        {
            CountryCode = countryCode;
            IdentificationCode = identificationCode;
            SubscriberNumber = subscriberNumber;
        }

        public static bool TryParse(string number, out PhoneNumber ph)
        {
            var reg = new Regex(@"\+(?<cc>\d+) (?<ic>\d+) (?<sn>\d+)");
            if (!reg.IsMatch(number))
            {
                ph = null;
                return false;
            }
            var match = reg.Match(number);
            var countryCode = int.Parse(match.Groups["cc"].Value);
            var identificationCode = int.Parse(match.Groups["ic"].Value);
            var subscriberNumber = int.Parse(match.Groups["sn"].Value);
            ph = new PhoneNumber(countryCode, identificationCode, subscriberNumber);
            return true;
        }
    }
}
```

Whilst the F# version uses a discriminated union:

```fsharp
module FSharp.FsCheck.PhoneNumber

open System.Text.RegularExpressions

type PossibleNumber = 
    { CountryCode : int
      IdentificationCode : int
      SubscriberNumber : int }
     
type PhoneNumber =
    | ValidPhoneNumber of PossibleNumber
    | InvalidPhoneNumber of string

// Shadow the name so that no one else
// can create "ValidPhoneNumber"
let ValidPhoneNumber input =
    let reg = Regex(@"\+(?<cc>\d+) (?<ic>\d+) (?<sn>\d+)")
    match reg.IsMatch(input) with
    | true ->
        let groups = reg.Match(input).Groups
        ValidPhoneNumber {
            CountryCode = groups.["cc"].Value |> int
            IdentificationCode = groups.["ic"].Value |> int
            SubscriberNumber = groups.["sn"].Value |> int
        }
    | false ->
        InvalidPhoneNumber "No good"
        
```

The challenge will be to use property checking to take the stub to a class that fulfils the following properties:

* Country code between 1 and 3 digits
* Identification code 4 or less digits (may be missing)
* Subscription number between 1 and (15 - country code - identification code) digits
* Less than 15 total digits

These all come straight from the specification - we're going to ignore country groups for now.

Each of the two projects also includes a PropertyChecks file that contains the skeleton of an NUnit based FsCheck test suite. We only have an hour for our DevEd sessions, so the project includes a reasonable amount to get you going. Each one has a "sanity check" test with a known good phone number, and property based checks for the length of the country code and whether all valid numbers are recognised as valid. To make the second property test work, they also both include a custom
generator for valid phone numbers.

The C# version ended up looking like this:

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using NUnit.Framework;
using FsCheck.Fluent;
using FsCheck;
using Microsoft.FSharp.Collections;

namespace CSharp.FsCheck
{
    [TestFixture]
    public class ManualChecks
    {
        [Test]
        public void SanityCheck()
        {
            PhoneNumber ph;
            PhoneNumber.TryParse("+44 123 456789", out ph);
            Assert.AreEqual(ph.CountryCode, 44);
            Assert.AreEqual(ph.IdentificationCode, 123);
            Assert.AreEqual(ph.SubscriberNumber, 456789);
        }
    }


    [TestFixture]
    public class PropertyChecks
    {
        public class GeneratedValidNumber {
            public int Country { get; private set; }
            public int? Identification { get; private set; }
            public int Subscriber { get; private set; }
            public string InputString { get; private set; }

            public GeneratedValidNumber(int country, int? identification, int subscriber)
            {
                Country = country;
                Identification = identification;
                Subscriber = subscriber;
                var idString =
                    identification.HasValue ? " " + identification.ToString() : "";
                InputString = "+" + country.ToString() + idString + " " + subscriber.ToString();
            }

            public override string ToString()
            {
                return "<" + InputString + ">";
            }
        }

        public Gen<GeneratedValidNumber> ValidPhoneNumberGenerator()
        {
            var nullableGen =
                from i in Any.IntBetween(1, 9999)
                select new Nullable<int>(i);
            var numberGen =
                from country in Any.IntBetween(1, 999)
                from identification in Any.GeneratorIn<int?>(nullableGen, Any.Value<int?>(null))
                from subscriber in Any.IntBetween(1, 99999999)
                select new GeneratedValidNumber(country, identification, subscriber);
            return numberGen;
        }


        [Test]
        public void CountryCodeLessThan4digits()
        {
            Spec.ForAny(
                (DontSize<uint> country) =>
                {
                    var cc = country.Item;
                    PhoneNumber ph;
                    var ec = PhoneNumber.TryParse("+" + cc.ToString() + " 1234 123456", out ph);
                    return ph.CountryCode < 1000;
                })
                .QuickCheckThrowOnFailure();
        }

        [Test]
        public void ValidNumbersAreRecognized()
        {
            Spec.For(ValidPhoneNumberGenerator(),
                (GeneratedValidNumber n) => {
                    PhoneNumber ph;
                    return PhoneNumber.TryParse(n.InputString, out ph);
                })
                .QuickCheckThrowOnFailure();
        }
    }
}
```

while the F# version looks like this:

```fsharp
module FSharp.FsCheck.PropertyChecks

open FsCheck
open NUnit.Framework
open PhoneNumber

type GeneratedValidNumber = 
    { Country : int
      Identifier : int option
      Subscriber : int
      InputString : string }

let validNumberGen = 
    gen { 
        let! c = Gen.choose (1, 999)
        let! i = Gen.oneof [ gen { let! i = Gen.choose (1, 9999)
                                   return (Some i) }
                             gen { return None } ]
        let maxSubLength = 
            float <| 15 - (c.ToString().Length) - (match i with
                                                   | None -> 0
                                                   | Some x -> x.ToString().Length)
        let! s = Gen.choose (1, (int <| 10. ** maxSubLength) - 1)
        return { Country = c
                 Identifier = i
                 Subscriber = s
                 InputString = 
                     sprintf "+%d%s %d" c (match i with
                                           | None -> ""
                                           | Some x -> sprintf " %d" x) s }
    }

type PhoneNumberGenerators =
    static member Valid() =
        { new Arbitrary<GeneratedValidNumber>() with
            override x.Generator = validNumberGen }

[<Test>]
let ``Sanity check``() = 
    match ValidPhoneNumber "+44 1234 123456" with
    | ValidPhoneNumber n -> 
        Assert.AreEqual(n.CountryCode, 44)
        Assert.AreEqual(n.IdentificationCode, 1234)
        Assert.AreEqual(n.SubscriberNumber, 123456)
    | InvalidPhoneNumber _ -> Assert.Fail()

[<Test>]
let ``Insanity check``() = 
    match ValidPhoneNumber "I'm not a phone number" with
    | ValidPhoneNumber n -> Assert.Fail()
    | InvalidPhoneNumber _ -> ()

[<Test>]
let ``Country code less than 4 digits``() = 
    let genNumber (DontSize(cc : uint32)) = 
        match ValidPhoneNumber("+" + cc.ToString() + " 1234 123456") with
        | ValidPhoneNumber n -> Assert.IsTrue(n.CountryCode.ToString().Length < 4)
        | InvalidPhoneNumber _ -> ()
    Check.QuickThrowOnFailure genNumber

[<Test>]
let ``Valid numbers are counted as valid`` () =
    Arb.register<PhoneNumberGenerators> () |> ignore
    Check.VerboseThrowOnFailure (
        fun (v:GeneratedValidNumber) ->
            match ValidPhoneNumber v.InputString with
            | ValidPhoneNumber _ -> true
            | InvalidPhoneNumber _ -> false)
```

These run fine as NUnit tests - apart from the fact that in true TDD style, they fail.

## The challenge!

So, the challenge (which is open to people outside 15below as well). Basically, fork the [git repository](https://github.com/mavnn/DevEd.PropertyChecks) and then check out locally. This contains everything, including both projects and the binaries of all their dependencies to avoid any NuGet issues. Within 15below, we'll be working in pairs - otherwise when you're sitting at your own computer with "real work" to do, it's very hard to actually take the hour out on the exercise.

In the order of your choice:

1. Add property checks for the missing properties above
2. Update the PhoneNumber class to pass all of the tests
3. *Extra credit*: Add a generator for local numbers from a known country (i.e. the UK) and property test your conversion method
4. *Extra credit 2*: complete any of all of the above in both F# and C#
5. *Completely carried away:* pick a real piece of production code and add a property test to it...

Once you've got as far as you're going to, commit your changes and push back up to GitHub, then send a pull request with progress back to the parent repository. I won't merge these, but the different implementations of both the phone number class and property tests will form the basis of the DevEd session the week after, possibly with votes for the most elegant/robust solutions. If you're not a member of staff here at 15below, I'll try and update your pull request with any
feedback from our discussions!
