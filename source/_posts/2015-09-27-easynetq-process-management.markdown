---
layout: post
title: "EasyNetQ Process Management"
date: 2015-10-05 12:23:02 +0100
comments: true
categories: [programming,easynetq]
---

# Obsolete blog post warning!

Since this blog post has been written, I've been working on [RouteMaster](/routemaster-master-your-messaging-routes/). It's much better than what's described here, and you should check it out.

...and now, back to your original blog post.

> TL;DR: I wrote a EasyNetQ aware process manager library. Read down for some examples, and leave feedback if you think anything should change before it's released.

[EasyNetQ](http://easynetq.com/) is a nice little .net client library for RabbitMQ. Originally designed for introducing Rabbit (and the concepts of a bus based architecture)
to a company and programmers who hadn't previously used them before, it uses conventions to set up exchanges and queues - basing them on the names of the .net types that are
being sent and subscribe to.

For example (from the EasyNetQ homepage):

``` csharp
bus.Publish<MyMessage>(message);
```

Will publish a message of type "MyMessage". Generally there's no need to actually specify the type here, C# will infer it for you, but it makes the example clearer.

Other services can subscribe to "MyMessage" like so:

``` csharp
bus.Subscribe<MyMessage>("my_subscription_id", msg => 
      Console.WriteLine(msg.Text));
```

<!-- more -->

If multiple services use the same subscription id, they will all connect to the same queue on the Rabbit server. This means in practice they will round-robin receipt of
messages, allowing for easy horizontal scalability. Subscribers with a different subscription ID will create a new queue behind the scenes and so a copy of the message will
be routed to both subscription IDs.

At this point, the only real point of coupling between subscribers and publishers is the need to share a dll with your "contract types" - the types that are going to be
used for publishing and subscribing.

This immediately gives you a lot of the ground work you need to start creating a message based system. But there is one big hole, which it's harder to fill than you might
think.

The hole is that at some point you're going to want to start building processes on top of your message based services which glue together some kind of long running
work flow which requires information from several other components.

Let's start with a simple example - we'll assume we have a email sending system. It has a bus based service that knows how to grab some data from somewhere;
a service that stores email templates; a service that knows how to render the data and template together; and finally an email sender.

Triggering the services might look a bit like this (if you're working in F#):

``` fsharp
bus.Publish { StoreModel.CorrelationId = Guid.NewGuid(); Model = model }
bus.Publish { StoreTemplate.CorrelationId = Guid.NewGuid(); Name = "mytemplate"; Template = template }
bus.Publish { RequestRender.CorrelationId = Guid.NewGuid(); TemplateId = 1; ModelId = 4 }
bus.Publish { SendEmail.CorrelationId = Guid.NewGuid(); Content = "Hello world!"; EmailAddress = "me@example.com" }
```

That's fantastic; only, you'll notice the values for each step are hard coded. Obviously, we need to subscribe to the messages we're expecting to be published in response
to these commands. We'd better subscribe to the responses - in fact, we'd better subscribe to everything before we start publishing, otherwise we might start getting responses
back before we're listening for them:

``` fsharp
// Subscribers
bus.Subscribe<RenderComplete> ("Process", fun r -> printfn "%A" r) |> ignore
bus.Subscribe<ModelStored> ("Process", fun ms -> printfn "%A" ms) |> ignore
bus.Subscribe<TemplateStored> ("Process", fun ts -> printfn "%A" ts) |> ignore
bus.Subscribe<EmailSent> ("Process", fun es -> printfn "%A" es) |> ignore

// Senders
bus.Publish { StoreModel.CorrelationId = Guid.NewGuid(); Model = model }
bus.Publish { StoreTemplate.CorrelationId = Guid.NewGuid(); Name = "mytemplate"; Template = template }
bus.Publish { RequestRender.CorrelationId = Guid.NewGuid(); TemplateId = 1; ModelId = 4 }
bus.Publish { SendEmail.CorrelationId = Guid.NewGuid(); Content = "Hello world!"; EmailAddress = "me@example.com" }
```

So, that's great. What now?

Well: as is common in a message based system we're passing a correlation ID into the service we're sending a request to, and part of the contract is that the triggered response will
have the same correlation ID. So we need some way to link a correlation ID back to a specific business process - a state store. But that needs to be safe for horizontal scaling.
We also need to wire up all the various stages in our process to know which other message to publish next. And it would be good if storing the template and model data happened concurrently,
because we're message based and why not? And finally, the client only wants the email sent if we can generate it within 15 seconds. Did we not mention that?

EasyNetQ provides one way of dealing with this, by allowing for what it calls a request/response pattern. But we found out the hard way that this still suffers from a few problems:
at a practical level, it doesn't scale very well for services that need to handle a lot of requests. On a conceptual level it assumes that the service that issued the request will
be around to process the response. That's an assumption that we really don't want if we're using a message bus to help us provide high availability.

So after several rounds of consultation within the company, I've written a library to help write process managers over the top of EasyNetQ, following the EasyNetQ conventions but
meeting the needs we've discovered.

The code is available on github at https://github.com/15below/EasyNetQ.ProcessManager ; if you want to run the examples you'll need a few db bits set up (see the README) and a
SMTP server (I recommend the excellent [PaperCut](https://papercut.codeplex.com/) as a simple and convenient development SMTP server).

> Please note: if you've looked at this article before, the code below has changed after a [a colleague of mine](https://twitter.com/BlythMeister) suggested much better method names for certain operations...

Back to the world of C#; first we'll need an actual ProcessManager object:

``` csharp
var rabbitConnString = ConfigurationManager.AppSettings["rabbit connection"];
var sqlConnString = ConfigurationManager.AppSettings["sql connection"];
var bus = RabbitHutch.CreateBus(rabbitConnString);
var active = new SqlActiveStore(sqlConnString);
var store = new SqlStateStore(sqlConnString, new Serializer());
var pm = new ProcessManager(new EasyNetQPMBus(bus), "Process", active, store);
Workflow.Configure(pm);
```

Obviously, most of this would normally be covered with an IoC container. So, the bus is probably pretty obvious, and ``"Process"`` is our subscription ID for any subscriptions we make
- but what are the ``SqlActiveStore`` and ``SqlStateStore``?

The active store is a component that will store the list of correlation IDs a process is waiting for, and which handlers to connect them to. Out of the box you get a
memory based version (fast, good for testing, not horizontally scalable for hopefully obvious reasons) and an SQL Server based version.

The state store, as you might have guessed, stores state for your workflow. Again both memory and SQL based implementations are provided, with the SQL implementation guaranteed to be not
just thread safe, but "process safe". One thing you do have to provide yourself is a serializer that knows how to serialize any work flow state objects you want stored.

Finally, and most interesting: let's see what's in ``Workflow.Configure(pm)``. Let's take the file that actually configures our workflow, and break it down into sections (I'll chop some boilerplate out, full file at the end).

``` csharp
using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using EasyNetQ.ProcessManager;
using Messenger.Messages.Email;
using Messenger.Messages.Render;
using Messenger.Messages.Store;
```

All the standard bits - we'll need access to the various message types and the ProcessManager name space.

``` csharp
[DataContract]
public class WorkflowState
{
    public WorkflowState() { }

    public WorkflowState(int? modelId, int? contentTemplateId, string emailContent, string emailAddress, int? addressTemplateId)
    {
        ModelId = modelId;
        ContentTemplateId = contentTemplateId;
        EmailContent = emailContent;
        EmailAddress = emailAddress;
        AddressTemplateId = addressTemplateId;
    }

    [DataMember]
    public int? ModelId { get; set; }
    [DataMember]
    public int? ContentTemplateId { get; set; }
    [DataMember]
    public int? AddressTemplateId { get; set; }
    [DataMember]
    public string EmailContent { get; set; }
    [DataMember]
    public string EmailAddress { get; set; }
}
```

This object will store the state of our work flow. As you might guess, it starts off empty and steps in the work flow will gradually fill in the gaps as
they receive information back from the remote services. The basic flow of the process we're creating is to store a model (piece of data), an address template
and a content template. We'll render an address once we have both address template and model IDs, and the content once we have both content template and model ID.

After both rendering jobs have finished, we'll send an email to the address, with the content. Note that our object does *not* need any awareness of which
instance of the work flow it's storing information for - the ProcessManager will handle that for us.

``` csharp
public class Workflow
{
```

Let's have a class to group all of our work flow logic together in one place. This isn't in anyway required by ProcessManager, but it's definitely recommended to
allow people to work out what on earth your project manager actually does.

``` csharp
private const string ModelStoredCheckRenderContentKey = "ModelStoredCheckRenderContentKey";
private const string ModelStoredCheckRenderAddressKey = "ModelStoredCheckRenderAddress";
private const string ContentTemplateStoredCheckRenderContentKey = "ContentTemplateStoredCheckRenderContent";
private const string AddressTemplateStoredCheckRenderAddressKey = "AddressTemplateStoredCheckRenderAddress";
private const string ContentRenderedCheckSendEmailKey = "ContentRenderedCheckSendEmail";
private const string AddressRenderedCheckSendEmailKey = "AddressRenderedCheckSendEmail";
```

We'll be specifying in each of our work flow steps which callbacks we're expecting to be fired when response messages are received. Because these callbacks may not
happen in the same process (ProcessManager is horizontally scalable by design), callbacks are referred to by a string mapping. These get used in several places, so
it's probably worth recording them all as ``const``s to avoid typos.

``` csharp
public static Out Start(IDictionary<string, object> model, string contentTemplate, string addressTemplate)
{
    var modelCid = Guid.NewGuid();
    var contentCid = Guid.NewGuid();
    var addressCid = Guid.NewGuid();
    return
        Out.Empty
            .Send(new StoreModel(modelCid, model), TimeSpan.FromSeconds(4))
            .Expect<ModelStored>(modelCid.ToString(),
                ModelStoredCheckRenderContentKey, TimeSpan.FromSeconds(5), "TimeOut")
            .Expect<ModelStored>(modelCid.ToString(),
                ModelStoredCheckRenderAddressKey, TimeSpan.FromSeconds(5), "TimeOut")
            .Send(new StoreTemplate(contentCid, "content template",
                contentTemplate), TimeSpan.FromSeconds(4))
            .Expect<TemplateStored>(contentCid.ToString(),
                ContentTemplateStoredCheckRenderContentKey, TimeSpan.FromSeconds(5),
                "TimeOut")
            .Send(new StoreTemplate(addressCid, "address template",
                addressTemplate), TimeSpan.FromSeconds(4))
            .Expect<TemplateStored>(addressCid.ToString(),
                AddressTemplateStoredCheckRenderAddressKey, TimeSpan.FromSeconds(5),
                "TimeOut");
}
```

So: our ``Start`` method is where the real fun starts. It's ``static``, as an instance of the work flow class makes very little sense as all state will be stored in the
state store. And basically all it does is set up our first set of expected requests (to ``Send``) and continuations (to ``Expect``).

All functions within a work flow must return an ``Out`` object. Here, we create our Out using its fluent builder API; first adding a request to send a ``StoreModel``,
then hooking up two handlers to the response message we expect the store to send when it's done storing the model (there's no requirement for a specific message to trigger
only one continuation). But what are these ``TimeSpan``s floating around everywhere?

Well, it turns out that RabbitMQ implements the idea of expiring messages. ProcessManager forces you to choose how long a message should stay available for before expiring,
to avoid creating situations where you build up unbounded backlogs of ancient messages that no longer have any relevance. For time critical processes such as ours, it also
means that we can put expectations on how long we expect a step to take. Here, we're saying: "if the store doesn't accept the store model request within 4 seconds, do not
deliver it."

In a similar way, we must choose a timespan to process continuations within. Network issues or overloading of the ProcessManager itself might mean that the request is processed,
but by the time the continuation trigger message returns we've already missed our processing window. In this example, we're specifying: "if we don't receive a model stored message
within 5 seconds, do not process the continuation when (or if) it arrives; also, publish a time out message to be processed by a handler named TimeOut."

The rest of the method follows a similar pattern, setting up the requests to store content and address templates respectively, with the expected continuations.

``` csharp
private static Out RenderContentIfReady(WorkflowState state)
{
    if (!state.ModelId.HasValue || !state.ContentTemplateId.HasValue) return Out.Ignore;
    var cid = Guid.NewGuid();
    var renderContent =
        new RequestRender(cid, state.ContentTemplateId.Value, state.ModelId.Value);
    return
        Out.Empty
            .Send(renderContent, TimeSpan.FromSeconds(4))
            .Expect<RenderComplete>(cid.ToString(), ContentRenderedCheckSendEmailKey, TimeSpan.FromSeconds(5),
                "TimeOut");
}

private static Out RenderAddressIfReady(WorkflowState state)
{
    if (!state.ModelId.HasValue || !state.AddressTemplateId.HasValue) return Out.Ignore;
    var cid = Guid.NewGuid();
    var renderContent =
        new RequestRender(cid, state.AddressTemplateId.Value, state.ModelId.Value);
    return Out.Empty.Send(renderContent, TimeSpan.FromSeconds(4))
        .Expect<RenderComplete>(cid.ToString(), AddressRenderedCheckSendEmailKey, TimeSpan.FromSeconds(5),
            "TimeOut");
}
```

Next up: a couple of private helper methods. These take our ``WorkflowState`` object from above and know whether we can start the two rendering processes yet.

Note the use of ``Out.Ignore`` if the state is not yet ready to trigger the next part of the work flow. ``Ignore`` is basically a way of marking this branch of the
work flow complete. This is different to ``Out.End``, which we'll have a look at a bit later - and which ends all branches of the work flow.

``` csharp
public static Out ModelStoredCheckRenderContent(ModelStored ms, IState state)
{
    var ws = state.AddOrUpdate(new WorkflowState {ModelId = ms.ModelId}, existing =>
    {
        existing.ModelId = ms.ModelId;
        return existing;
    });
    return RenderContentIfReady(ws);
}

public static Out ModelStoredCheckRenderAddress(ModelStored ms, IState state)
{
    var ws = state.AddOrUpdate(new WorkflowState {ModelId = ms.ModelId}, existing =>
    {
        existing.ModelId = ms.ModelId;
        return existing;
    });
    return RenderAddressIfReady(ws);
}

public static Out ContentTemplateStoredCheckRenderContent(TemplateStored ts, IState state)
{
    var ws = state.AddOrUpdate(new WorkflowState {ContentTemplateId = ts.TemplateId}, existing =>
    {
        existing.ContentTemplateId = ts.TemplateId;
        return existing;
    });
    return RenderContentIfReady(ws);
}

public static Out AddressTemplateStoredCheckRenderAddress(TemplateStored ts, IState state)
{
    var ws = state.AddOrUpdate(new WorkflowState {AddressTemplateId = ts.TemplateId}, existing =>
    {
        existing.AddressTemplateId = ts.TemplateId;
        return existing;
    });
    return RenderAddressIfReady(ws);
}
```

These four methods will be wired up to handle the four continuation options we created in our ``Start`` method.
Each is very similar: it is passed the triggering message and the state of *this* work flow, updates or creates the
state with the data it has received back, and then runs one of the private helpers we defined above.

Why can we not just Add, or just Update the state? Well - we published 3 requests which are being handled by 4
continuations. There are no guarantees what order these will be triggered in or that they won't be triggered simultaneously
on different threads or even on different machines. ``AddOrUpdate`` acts as a synchronization point for our work flow,
guaranteeing that the operation happening within it will be atomic.

We can apply similar logic to waiting for our two rendering jobs:

``` csharp
private static Out SendEmailIfReady(WorkflowState state)
{
    if (state.EmailAddress == null || state.EmailContent == null) return Out.Ignore;
    var cid = Guid.NewGuid();
    var sendEmail =
        new SendEmail(cid, state.EmailAddress, state.EmailContent);
    return Out.Empty.Send(sendEmail, TimeSpan.FromSeconds(4))
        .Expect<EmailSent>(cid.ToString(), "EmailSent", TimeSpan.FromSeconds(5), "TimeOut");
}

public static Out AddressRenderedCheckSendEmail(RenderComplete rc, IState state)
{
    var ws = state.AddOrUpdate(new WorkflowState {EmailAddress = rc.Content}, existing =>
    {
        existing.EmailAddress = rc.Content;
        return existing;
    });
    return SendEmailIfReady(ws);
}

public static Out ContentRenderedCheckSendEmail(RenderComplete rc, IState state)
{
    var ws = state.AddOrUpdate(new WorkflowState {EmailContent = rc.Content}, existing =>
    {
        existing.EmailContent = rc.Content;
        return existing;
    });
    return SendEmailIfReady(ws);
}
```

Once they have both finished, and only once they have both finished, ``SendEmailIfReady`` will fire off a ``SendEmail`` request.

``` csharp
public static Out EmailSent(EmailSent es, IState state)
{
    var ws = state.Get<WorkflowState>().Value;
    Console.WriteLine("Email send success: {0}\nAddress: {1}\nContent: {2}", es.Successful, ws.EmailAddress, ws.EmailContent);
    return Out.End;
}
```

Finally on our happy path, we're informed that an email has been sent. Here we mark the work flow as ended using ``Out.End``. This will cancel
any outstanding continuations and remove the work flow state from the state store. ProcessManager *will not retain any information*
about the running of a work flow. If you require (and you probably do) any kind of logging or auditing it is your responsibility to
cover that within the handlers you write.

But all this only covers the happy path. What happens if we hit one of those time outs we've been talking about?

``` csharp
public static Out TimeOut(TimeOutMessage to, IState state)
{
    Console.WriteLine("Time out waiting for: {0}", to.TimedOutStep);
    return Out.End;
}
```

Well, in that case a ``TimeOutMessage`` will be published, and we can handle it appropriately. In this case, just printing out the fact the job timed out, and which step it was that didn't complete (one of the fields on the ``TimeOutMessage`` object).
As above, we explicitly ``End`` the work flow. No further continuations will be triggered beyond this point. One thing to bear in mind though: while a continuation
timeout guarantees the continuation will not fire after the ``TimeSpan`` has expired, there is **no** guarantee that the ``TimeOutMessage`` will be either published
or handled in any particular timescale. For example, if all your ProcessManager nodes go down; well you won't be publishing/handling any time outs until they're running
again.

Now we're ready to write our ``Configure`` method. Let's wire everything up:

``` csharp
public static void Configure(ProcessManager pm)
{
    pm.AddProcessor(stored => stored.CorrelationId.ToString(), new []
    {
        new Mapping<ModelStored>(ModelStoredCheckRenderContentKey, ModelStoredCheckRenderContent),
        new Mapping<ModelStored>(ModelStoredCheckRenderAddressKey, ModelStoredCheckRenderAddress)
    });

    pm.AddProcessor(stored => stored.CorrelationId.ToString(), new[]
    {
        new Mapping<TemplateStored>(ContentTemplateStoredCheckRenderContentKey,
            ContentTemplateStoredCheckRenderContent),
        new Mapping<TemplateStored>(AddressTemplateStoredCheckRenderAddressKey,
            AddressTemplateStoredCheckRenderAddress)
    });

    pm.AddProcessor(complete => complete.CorrelationId.ToString(), new []
    {
        new Mapping<RenderComplete>(AddressRenderedCheckSendEmailKey, AddressRenderedCheckSendEmail),
        new Mapping<RenderComplete>(ContentRenderedCheckSendEmailKey, ContentRenderedCheckSendEmail)
    });

    pm.AddProcessor(sent => sent.CorrelationId.ToString(), new Mapping<EmailSent>("EmailSent", EmailSent));

    pm.AddProcessor(to => to.CorrelationId.ToString(), new Mapping<TimeOutMessage>("TimeOut", TimeOut));
}
```

The method takes our ProcessManager and starts adding processors to it. A processor knows how to extract a correlation ID from a specific message type, and an ``IEnumerable`` of mappings.
Each mapping tells the ProcessManager which method to fire based on a string Key (remember our ``const``s from above?).

So, there you have it; a complete managed work flow on top of EasyNetQ with split and merge and time outs. The full work flow code file with out my commentary is below for those of you
who find that easier!

``` csharp
using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using EasyNetQ.ProcessManager;
using Messenger.Messages.Email;
using Messenger.Messages.Render;
using Messenger.Messages.Store;

namespace Process3
{
    [DataContract]
    public class WorkflowState
    {
        public WorkflowState() { }

        public WorkflowState(int? modelId, int? contentTemplateId, string emailContent, string emailAddress, int? addressTemplateId)
        {
            ModelId = modelId;
            ContentTemplateId = contentTemplateId;
            EmailContent = emailContent;
            EmailAddress = emailAddress;
            AddressTemplateId = addressTemplateId;
        }

        [DataMember]
        public int? ModelId { get; set; }
        [DataMember]
        public int? ContentTemplateId { get; set; }
        [DataMember]
        public int? AddressTemplateId { get; set; }
        [DataMember]
        public string EmailContent { get; set; }
        [DataMember]
        public string EmailAddress { get; set; }
    }

    public class Workflow
    {
        // Callback keys
        private const string ModelStoredCheckRenderContentKey = "ModelStoredCheckRenderContentKey";
        private const string ModelStoredCheckRenderAddressKey = "ModelStoredCheckRenderAddress";
        private const string ContentTemplateStoredCheckRenderContentKey = "ContentTemplateStoredCheckRenderContent";
        private const string AddressTemplateStoredCheckRenderAddressKey = "AddressTemplateStoredCheckRenderAddress";
        private const string ContentRenderedCheckSendEmailKey = "ContentRenderedCheckSendEmail";
        private const string AddressRenderedCheckSendEmailKey = "AddressRenderedCheckSendEmail";

        public static Out Start(IDictionary<string, object> model, string contentTemplate, string addressTemplate)
        {
            var modelCid = Guid.NewGuid();
            var contentCid = Guid.NewGuid();
            var addressCid = Guid.NewGuid();
            return
                Out.Empty
                    .Send(new StoreModel(modelCid, model), TimeSpan.FromSeconds(4))
                    .Expect<ModelStored>(modelCid.ToString(), ModelStoredCheckRenderContentKey, TimeSpan.FromSeconds(5), "TimeOut")
                    .Expect<ModelStored>(modelCid.ToString(), ModelStoredCheckRenderAddressKey, TimeSpan.FromSeconds(5), "TimeOut")
                    .Send(new StoreTemplate(contentCid, "content template", contentTemplate), TimeSpan.FromSeconds(4))
                    .Expect<TemplateStored>(contentCid.ToString(), ContentTemplateStoredCheckRenderContentKey, TimeSpan.FromSeconds(5),
                        "TimeOut")
                    .Send(new StoreTemplate(addressCid, "address template", addressTemplate), TimeSpan.FromSeconds(4))
                    .Expect<TemplateStored>(addressCid.ToString(), AddressTemplateStoredCheckRenderAddressKey, TimeSpan.FromSeconds(5),
                        "TimeOut");
        }

        private static Out RenderContentIfReady(WorkflowState state)
        {
            if (!state.ModelId.HasValue || !state.ContentTemplateId.HasValue) return Out.Ignore;
            var cid = Guid.NewGuid();
            var renderContent =
                new RequestRender(cid, state.ContentTemplateId.Value, state.ModelId.Value);
            return
                Out.Empty
                    .Send(renderContent, TimeSpan.FromSeconds(4))
                    .Expect<RenderComplete>(cid.ToString(), ContentRenderedCheckSendEmailKey, TimeSpan.FromSeconds(5),
                        "TimeOut");
        }

        private static Out RenderAddressIfReady(WorkflowState state)
        {
            if (!state.ModelId.HasValue || !state.AddressTemplateId.HasValue) return Out.Ignore;
            var cid = Guid.NewGuid();
            var renderContent =
                new RequestRender(cid, state.AddressTemplateId.Value, state.ModelId.Value);
            return Out.Empty.Send(renderContent, TimeSpan.FromSeconds(4))
                .Expect<RenderComplete>(cid.ToString(), AddressRenderedCheckSendEmailKey, TimeSpan.FromSeconds(5),
                    "TimeOut");
        }

        public static Out ModelStoredCheckRenderContent(ModelStored ms, IState state)
        {
            var ws = state.AddOrUpdate(new WorkflowState {ModelId = ms.ModelId}, existing =>
            {
                existing.ModelId = ms.ModelId;
                return existing;
            });
            return RenderContentIfReady(ws);
        }

        public static Out ModelStoredCheckRenderAddress(ModelStored ms, IState state)
        {
            var ws = state.AddOrUpdate(new WorkflowState {ModelId = ms.ModelId}, existing =>
            {
                existing.ModelId = ms.ModelId;
                return existing;
            });
            return RenderAddressIfReady(ws);
        }

        public static Out ContentTemplateStoredCheckRenderContent(TemplateStored ts, IState state)
        {
            var ws = state.AddOrUpdate(new WorkflowState {ContentTemplateId = ts.TemplateId}, existing =>
            {
                existing.ContentTemplateId = ts.TemplateId;
                return existing;
            });
            return RenderContentIfReady(ws);
        }

        public static Out AddressTemplateStoredCheckRenderAddress(TemplateStored ts, IState state)
        {
            var ws = state.AddOrUpdate(new WorkflowState {AddressTemplateId = ts.TemplateId}, existing =>
            {
                existing.AddressTemplateId = ts.TemplateId;
                return existing;
            });
            return RenderAddressIfReady(ws);
        }

        private static Out SendEmailIfReady(WorkflowState state)
        {
            if (state.EmailAddress == null || state.EmailContent == null) return Out.Ignore;
            var cid = Guid.NewGuid();
            var sendEmail =
                new SendEmail(cid, state.EmailAddress, state.EmailContent);
            return Out.Empty.Send(sendEmail, TimeSpan.FromSeconds(4))
                .Expect<EmailSent>(cid.ToString(), "EmailSent", TimeSpan.FromSeconds(5), "TimeOut");
        }

        public static Out AddressRenderedCheckSendEmail(RenderComplete rc, IState state)
        {
            var ws = state.AddOrUpdate(new WorkflowState {EmailAddress = rc.Content}, existing =>
            {
                existing.EmailAddress = rc.Content;
                return existing;
            });
            return SendEmailIfReady(ws);
        }

        public static Out ContentRenderedCheckSendEmail(RenderComplete rc, IState state)
        {
            var ws = state.AddOrUpdate(new WorkflowState {EmailContent = rc.Content}, existing =>
            {
                existing.EmailContent = rc.Content;
                return existing;
            });
            return SendEmailIfReady(ws);
        }

        public static Out EmailSent(EmailSent es, IState state)
        {
            var ws = state.Get<WorkflowState>().Value;
            Console.WriteLine("Email send success: {0}\nAddress: {1}\nContent: {2}", es.Successful, ws.EmailAddress, ws.EmailContent);
            return Out.End;
        }

        public static Out TimeOut(TimeOutMessage to, IState state)
        {
            Console.WriteLine("Time out waiting for: {0}", to.TimedOutStep);
            return Out.End;
        }

        public static void Configure(ProcessManager pm)
        {
            pm.AddProcessor(stored => stored.CorrelationId.ToString(), new []
            {
                new Mapping<ModelStored>(ModelStoredCheckRenderContentKey, ModelStoredCheckRenderContent),
                new Mapping<ModelStored>(ModelStoredCheckRenderAddressKey, ModelStoredCheckRenderAddress)
            });

            pm.AddProcessor(stored => stored.CorrelationId.ToString(), new[]
            {
                new Mapping<TemplateStored>(ContentTemplateStoredCheckRenderContentKey,
                    ContentTemplateStoredCheckRenderContent),
                new Mapping<TemplateStored>(AddressTemplateStoredCheckRenderAddressKey,
                    AddressTemplateStoredCheckRenderAddress)
            });

            pm.AddProcessor(complete => complete.CorrelationId.ToString(), new []
            {
                new Mapping<RenderComplete>(AddressRenderedCheckSendEmailKey, AddressRenderedCheckSendEmail),
                new Mapping<RenderComplete>(ContentRenderedCheckSendEmailKey, ContentRenderedCheckSendEmail)
            });

            pm.AddProcessor(sent => sent.CorrelationId.ToString(), new Mapping<EmailSent>("EmailSent", EmailSent));

            pm.AddProcessor(to => to.CorrelationId.ToString(), new Mapping<TimeOutMessage>("TimeOut", TimeOut));
        }
    }
}
```

Suggestions, additions and questions welcome.
