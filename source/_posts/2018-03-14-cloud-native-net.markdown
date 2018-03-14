---
layout: post
title: "Cloud Native .NET"
date: 2018-03-14 11:28:03 +0000
comments: true
categories: []
---
We're launching a new two day course this April (26th/27th), called "Cloud Native .NET". Despite the slightly pretentious name the industry has come up with, what we're really talking about here are the core engineering skills of building code that can be scaled and maintained. This course is a practical workshop using .NET Core and Kuberenetes so we can see what it all looks like in practice.

Full details below!

<h1>Cloud Native .NET</h1>
<h2 id="orgb18d510">Or "Writing Maintainable Systems in .NET"</h2>
<div class="outline-text-2" id="text-orgb18d510">
<p>
.NET was first created in a world of monolithic enterprise deployments installed on physical servers, and desktop applications distributed via CD.
</p>

<p>
Now the world has moved on, and so have our expectations. The new normal has become:
</p>

<ul class="org-ul">
<li>Rapid, continuous updates of services</li>
<li>Zero down time deployments</li>
<li>Horizontally scalable web applications with 24 hour access</li>
</ul>

<p>
The term "Cloud Native" has been used to describe code that is designed to live in this brave new world of automated deployments and cheap virtual infrastructure. We'll examine some of the principles and techniques underpinning the design of automatically deployable, trivially scalable, reliable, and easily maintainable software systems built with .NET.
</p>

<p>
All with the logging, monitoring, and metrics you need to know what's really happening in production.
</p>

<p>
We'll use Kubernetes to define a multi-service system, digging into how and why the overall system has been designed the way it has. Finally, we'll put it all together, creating new functionality by adding .NET Core services to our system.
</p>
</div>
</div>

<div id="outline-container-org29dfcb5" class="outline-2">
<h2 id="org29dfcb5">What you know already:</h2>
<div class="outline-text-2" id="text-org29dfcb5">
<ul class="org-ul">
<li>How to read and write C# or F#</li>
<li>Basic command line skills</li>
</ul>
</div>
</div>

<div id="outline-container-org08375ab" class="outline-2">
<h2 id="org08375ab">We'll cover:</h2>
<div class="outline-text-2" id="text-org08375ab">
<ul class="org-ul">
<li>An introduction to Kubernetes/Docker</li>
<li>Applying SOLID principles to system design</li>
<li>What is a cloud native application anyway?</li>
<li>12 Factor Applications
<ul class="org-ul">
<li>What are the 12 factors?</li>
<li>How do they help us write better software?</li>
</ul></li>
<li>Writing .NET 12 Factor Applications</li>
<li>How to instrument distributed services</li>
<li>Running distributed systems in development</li>
<li>Continuous Integration &amp; Deployment</li>
<li>Continuous Improvement
<ul class="org-ul">
<li>Property based testing</li>
<li>Performance measurement</li>
</ul></li>
</ul>
</div>
</div>

<div id="outline-container-org47ccf78" class="outline-2">
<h2 id="org47ccf78">Before you come:</h2>
<div class="outline-text-2" id="text-org47ccf78">
<p>
You'll need a laptop with:
</p>

<ul class="org-ul">
<li>.NET Core SDK 2.x</li>
<li>A C# or F# editor</li>
<li><a href="https://github.com/kubernetes/minikube">minikube</a></li>
<li><a href="https://kubernetes.io/docs/tasks/tools/install-kubectl/">kubectl</a></li>
<li><a href="https://git-scm.com/">git</a></li>
</ul>

<p>
Before arriving, it would be really helpful to run the command <code>minikube start --memory 4096 --cpus 3</code>; on first run minikube downloads its own dependencies.
</p>
</div>
</div>


<div id="outline-container-org0644f3a" class="outline-2">
<h2 id="org0644f3a">You'll come away with:</h2>
<div class="outline-text-2" id="text-org0644f3a">
<p>
A git repository of your completed work, which will include:
</p>

<ul class="org-ul">
<li>Nicely instrumented, benchmarked and unit tested .NET services</li>
<li>A declarative deployment for the overall distributed system</li>
<li>Real time centralized logging, metrics and health feedback from the system, whether running on the dev machine or in production</li>
<li>Working zero down time continuous deployment</li>

<h2>Where will the course happen?</h2>

<p>At <a href="http://www.theskiff.org">The Skiff</a>, right next to Brighton Station (good links to London and Gatwick Airport).</p>

<h2>
What other people say about our courses:
</h2>

<blockquote>
<p>"I felt there was a gap between my good understanding of the language and actually applying it on bigger “real” projects.

Michael’s great training skills have enabled me to quickly practice some advanced topics I was less familiar with.

With my newly acquired knowledge, I’m confident I will be able achieve some great (and fun) development."</p> - Hassan Ezzahir, Lead developer (Contractor) at BNP Paribas
</blockquote>

<blockquote>
<p>"Huge thanks to @mavnn for coming from London to @Safe_Banking Atlanta and giving an All-Week #fsharp Training Session to our Dev Team. By all accounts it was a great time and everyone learned quite a lot. His approach is very practical and use case oriented, highly recommended."</p> - Richard Minerich, CTO Safe Banking Systems
</blockquote>

<blockquote>
<p>"Thanks to @mavnn for an excellent “Building Solid Systems in F#” workshop in London last week. Really enjoyed the course material and meeting everybody (Also I’ve been inspired to teach myself Emacs :)"</p> - Kevin Knoop, AutoTask
</blockquote>

<h2>Where can I buy tickets?</h2>

<p>
Right here! There's an early bird discount which runs to the end of March, and if you're a user group member ping me (or get your user group to do so!) and we'll work something out. If the form below doesn't work for you, you can also get them <a href="https://www.eventbrite.co.uk/e/cloud-native-net-tickets-44179209204">direct on EventBrite</a>.
</p>

<div id="eventbrite-widget-container-44179209204"></div>

<script src="https://www.eventbrite.co.uk/static/widgets/eb_widgets.js"></script>

<script type="text/javascript">
    var exampleCallback = function() {
        console.log('Order complete!');
    };

    window.EBWidgets.createWidget({
        // Required
        widgetType: 'checkout',
        eventId: '44179209204',
        iframeContainerId: 'eventbrite-widget-container-44179209204',

        // Optional
        iframeContainerHeight: 425,  // Widget height in pixels. Defaults to a minimum of 425px if not provided
        onOrderComplete: exampleCallback  // Method called when an order has successfully completed
    });
</script>
