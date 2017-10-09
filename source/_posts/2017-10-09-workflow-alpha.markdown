---
layout: post
title: "Workflow Alpha"
date: 2017-10-09 21:33:36 +0100
comments: true
categories: [fsharp, programming, easynetq]
---
![Log of workflow test running](/images/WorkflowAlpha.png)

**It's alive!** The process manager code I've been reconstructing (see [Intro](/process-management-in-easynetq/) and the [in memory test bus](/an-in-memory-message-bus-in-100-lines-or-less/)) is slowly starting to take some shape.

As you can see, it comes with nice ([no dependency](https://github.com/logary/logary#using-logary-in-a-library)) logging out of the box and it is async all the way down to the underlying transport.

This is still at the underlying plumbing phase in many ways: the code to construct a workflow like this is currently a boilerplate covered ugly mess - but it's all boilerplate which has been deliberately designed to allow powerful APIs to be built over the top.

Next up: a nice sleek API for creating "pipeline" workflows more easily. Then the real fun starts - pleasant to use abstractions over fork/join semantics...

*Interested in seeing faster progress on this project? Drop [us@mavnn.co.uk](mailto://us@mavnn.co.uk) a line to talk sponsership.*
