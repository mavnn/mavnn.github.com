---
layout: post
title: "RX Solutions"
date: 2015-02-09 14:15:45 +0000
comments: true
categories: [programming, 15below, practical]
---
This post contains solutions to the [Reactive Extensions practical](/exploring-reactive-extensions/) post.

<!--more-->

The base program looks like this (as in the previous post):

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

None of the teams bothered with helper methods or anything refined like that - they only had about 40 minutes to produce anything it all. So, in each of the following cases, replace line 50 in the original code block with the submitted solution.

### Attempt 1:

Simple, readable and minimalistic, our first contenders went with this.

``` csharp
obs.Where(t=>t.Item2 == "StaffOnly!" || t.Item2 == "Change!").Select(t => t.Item1).Subscribe(guid => staffSender.Send(guid));

obs.Where(t=>t.Item2 == "CustomerOnly!" || t.Item2 == "Change!").Delay(TimeSpan.FromSeconds(5)).Select(t => t.Item1).Subscribe(guid => customerSender.Send(guid));
```

As you can see, staff are notified immediately on either a ``StaffOnly!`` or ``Change!`` event - while customer events are delayed 5 seconds.

### Attempt 2:

Group 2 played with RX's ``GroupBy`` method, which creates an Observable of Observables - each one of which only gets events that match the partitioning function.

Interesting stuff, although probably slightly overkill with 4 pre-known options.

```csharp
obs.GroupBy(x => x.Item2)
    .Subscribe(o =>
    {
        o.Where(x => x.Item2 == "StaffOnly!" || x.Item2 == "Change!")
            .Select(x => x.Item1)
            .Subscribe(staffSender.Send);
        o.Where(x => x.Item2 == "CustomerOnly!" || x.Item2 == "Change!")
            .Select(t => t.Item1)
            .Delay(TimeSpan.FromSeconds(6))
            .Subscribe(customerSender.Send);
    });
```

It also still does the job fine.

### Attempt 3:

With high points on pragmatism and clarity, group 3 just went with the absolute simplest solution. Just have 4 separate observables:

``` csharp
obs.Where(t => t.Item2.Equals("StaffOnly!")).Subscribe(staffOnly => staffSender.Send(staffOnly.Item1));
obs.Where(t => t.Item2.Equals("CustomerOnly!")).Delay(TimeSpan.FromSeconds(5)).Subscribe(customerOnly => customerSender.Send(customerOnly.Item1));
obs.Where(t => t.Item2.Equals("Change!")).Delay(TimeSpan.FromSeconds(5)).Subscribe(s => customerSender.Send(s.Item1));
obs.Where(t => t.Item2.Equals("Change!")).Subscribe(s => staffSender.Send(s.Item1));
```

There's obviously much more to RX than you can learn in a single 1 hour practical session, but hopefully this gives you a feel and (if you followed along) takes away some of the fear of trying out this useful part of the .net ecosystem.
