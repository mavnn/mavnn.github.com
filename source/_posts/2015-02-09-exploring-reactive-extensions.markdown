---
layout: post
title: "Exploring Reactive Extensions"
date: 2015-02-09 13:01:36 +0000
comments: true
categories: [programming,15below,practical]
---
The [Reactive Extensions](http://rx.codeplex.com/) project is "a library for composing asynchronous and event-based programs using observable sequences and LINQ-style query operators". That doesn't immediately give most people an intuitive grasp of exactly what it is - but it's a useful addition to the toolset so we put together a practical for people to experiment with.

At it's simplest, RX (as it's called... the Nuget package you're looking for is [Rx-Main](https://www.nuget.org/packages/Rx-Main), obviously!) allows you to create an ``IObservable`` object which you can then... erm... observe.

<!--more-->

``IObservable`` objects can, in turn, be observed by other ``IObservable``s via a series of extension methods, and they will react when the original observable publishes a change. Hence "Reactive Extensions". These extensions include all the normal Linq like things you've come to know and expect in .net (``.Where`` for filtering, ``.Select`` for mapping, etc) and also a selection of time based extensions which are the real meat of the reactive programming model. Things like ``.Delay``, which
holds changes for a period of time before passing them on to subscribers. Or ``.Throttle``, which throttles how quickly events can be passed through, and throws away events that are occurring too rapidly.

The best explanation of the various methods I've seen is actually the [reactivex.io javadocs](http://reactivex.io/RxJava/javadoc/), which have diagram pictorially depicting the effect of each method. Although it's for Java, the method names are the same. For example, the [sample method](http://reactivex.io/RxJava/javadoc/) comes with the following diagram:

![Sample method image](https://raw.githubusercontent.com/wiki/ReactiveX/RxJava/images/rx-operators/sample.s.png)

It shows quite nicely that sample will pick the last event of each interval (if there are any), and publish on only that.

The final part of the puzzle, once you've done all your filtering, mapping, delaying and sampling is to hook up a Publish callback on your final ``IObservable``.

Let's get to the example code!

### The scenario

``` csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Reactive;
using System.Reactive.Linq;
using ReactiveTester.Shared;

namespace EventTester
{
    class Program
    {
        static void Handler(Tuple<Guid, string> tuple)
        {
            Console.WriteLine("{0} - {1}", tuple.Item1, tuple.Item2);
        }

        static void Error(Exception e)
        {
            var err = Console.OpenStandardError();
            using (var writer = new System.IO.StreamWriter(err, Console.OutputEncoding))
            {
                writer.WriteLine("{0}", e);
            }
        }

        static void Main(string[] args)
        {
            // Nice docs (although Java): http://reactivex.io/RxJava/javadoc/rx/Observable.html
            // The challenge:
            // The ChangeReceiver will fire an event every time a change is received.
            // Events can be:
            // "Ignore!" -> don't do anything
            // "Change!" -> send notification to staff and customers
            // "StaffOnly!" -> send notification to staff
            // "CustomerOnly!" -> send notification to customer only
            //
            // Staff must be notified within 3 seconds.
            // Customers most be notified between 5 and 7 seconds.
            using(var pub = new ChangeReceiver("tcp://*:5555"))
            {
                Console.WriteLine("Listening...");

                var staffSender = new NotificationSender("tcp://localhost:5556");
                var customerSender = new NotificationSender("tcp://localhost:5557");

                var obs = Observable.FromEventPattern<Tuple<Guid, string>>(pub, "ChangeRecieved").Select(ep => ep.EventArgs);
                obs.Subscribe<Tuple<Guid, string>>(Handler);
                obs.Select(t => t.Item1).Subscribe(guid => customerSender.Send(guid));

                //var err = Observable.FromEventPattern<Exception>(pub, "OnError").Select(ep => ep.EventArgs);
                //err.Subscribe<Exception>(Error);

                pub.Start();
                Console.ReadLine();
                Console.WriteLine("Closing down.");
            }
        }
    }
}
```

The challenge was to complete the C# program above.

Want to follow along at home? The [example code is on github](https://github.com/mavnn/RX-Practical). Mind out - it's a bit big, as I included all of the binaries to get people going faster. The file in question is in the ``EventTester`` project as ``Program.cs``.

The other program in the project (``ReactiveTester``) is test server. Right click on the solution, "Set StartUp projects" to run both on start up and hit ``F5``. You should get two consoles pop up, something like this:

![/images/Reactive1.PNG](/images/Reactive1.PNG)

What's going on here? Well, as company [15below](http://15below.com) deal with travel passenger communications, so the example stays close to home. The "server" (ReactiveTester, on the right) is masquerading as both an IROP (irregular operations, i.e. your flight has been cancelled due to insufficient chicken sarnies) system and as the staff and travellers who need to be told about events that are happening.

We're skipping any business logic identifying event types here, so for our purposes there are 4 types of events the system can issue.

* "Ignore!" -> we don't care about these
* "Change!" -> both staff and travellers should be told about these
* "StaffOnly!" -> only staff need to know about these ones
* "CustomerOnly!" -> staff don't care about these, only tell the customer

Our C# program then has a ``ChangeReceiver`` type that fires an event when a change is received, and a ``NotificationSender`` type it can use to send notifications out with. In reality, these go back to ``ReactiveTester`` that will then tell you if the notification arrived within the allowed window for either customer or staff.

The practical kicked off with the code at the state above. As you can see at line 48 we've hooked up an observable object to the ChangeReceiver's ChangeReceived event - now we can observe events. We've then hooked up a subscriber that fires the ``Handler`` method (line 14) which prints all changes to the command line. And a second subscriber that first maps the identifier/message tuple to the identifier and then sends a customer notification.

But wait...! Our test server keeps on saying "Customer: early"? And "No guid xxx found"? What gives?

Well... most travel companies are very keen for their staff to know about service alterations before customers. So the requirements we've been given are that staff should be notified within 3 seconds - but customers only between 5 and 7 seconds. (In real life, these timings would probably be in minutes, obviously).

And the missing guid warnings are because the customers only care about some of the event types (see above). And, of course, the staff aren't getting any notifications at all, so their always complaining about them being late.

Your mission, should you choose to accept it: make everyone happy!

We had 3 teams take up the challenge; I've posted their solutions in [a separate solutions post](/rx-solutions/) to avoid accidental spoilers :)

P.S. A couple of people were interested in how the server worked. It's my very first attempt at writing both [Hopac](https://github.com/Hopac/Hopac) and [fszmq](https://github.com/zeromq/fszmq) (an F# zeromq wrapper library). I'm hugely impressed by both, but wouldn't recommend my code in that repository as an introduction to either!
