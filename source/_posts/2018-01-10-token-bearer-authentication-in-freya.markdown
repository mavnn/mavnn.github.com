---
layout: post
title: "Token Bearer Authentication in Freya"
date: 2018-01-10 11:03:48 +0000
comments: true
categories: [fsharp, freya]
---
As part of my [Building Solid Systems](/building-solid-systems-in-f-number/) course, I'll be talking about authentication in distributed systems. I wanted a practical demonstration that people could play with, so I added token bearer authentication to a Freya API.

Here's how.

<!-- more -->

### System design

Over the years, I have become a big believer in using standards where standards exist (unless they're actively terrible); as such, for authentication we'll be assuming that our system includes an OAuth2 compliant authorization server. Depending on our needs, this might be an external service or a self hosted solution such as [IdentityServer](https://identityserver.io/).

We're going to set up an API which will use "token bearer" authentication. This means that the client is responsible for obtaining a valid token from our authorization server which includes a claim for access to the resource our API represents. How the client gets the token, we don't really care: there are several ways of obtaining a grant from an OAuth2 server and I won't be going too far down that rabbit hole here (although check the end of the article for an example).

### The code

Let's start coding, and add authentication to the "hello" endpoint of the Freya template project. Set up a new file for our `Auth` module, and open up everything we need.

``` fsharp
module Auth

open System
open Freya.Core
open Freya.Machines.Http
open Freya.Optics.Http
open Freya.Types.Http
open Hopac
open IdentityModel
open IdentityModel.Client
open Logging
```

Most of these should make sense; the additions are `IdentityModel` and a `Logging` module. IdentityModel is a NuGet package supplied by the IdentityServer project which implements the basics of the OAuth2 specification from a consumers point of view, and gives a nice client API over the top of the various endpoints an OAuth2 compliant server should implement.

The `Logging` module is the one from my [previous blog post](/logging-freya/); any logging here is optional, but in practice is *really very helpful* in an actual production distributed system.

The first thing we're going to do is create a `DiscoveryClient`. OAuth2 servers provide a discovery document which specifies things like it's public key and the locations of the other endpoints. In theory, this information can change over time - in this case I'm going to statically grab it on service start up.

``` fsharp
let discoClient =
    new DiscoveryClient("http://idserver:5000")

discoClient.Policy.RequireHttps <- false
discoClient.Policy.ValidateEndpoints <- false
discoClient.Policy.ValidateIssuerName <- false

let doc =
    discoClient.GetAsync()
    |> Async.AwaitTask
    |> Async.RunSynchronously
```

Your configuration here will vary considerably: I'm running within a kubernetes cluster using an internal DNS record, so I'm overriding the normal safety checks. If you are deploying a service which will be calling the identity server on an external network, you obviously shouldn't do this...

The `freyaMachine` has separate decision points for whether the request is `authorized` and whether it's `allowed`. Authorized is the simplest: a request is authorized if it has an authorization header. Let's build a method which checks that for us:

``` fsharp
let isAuthed =
    freya {
        let! hasHeader =
            Freya.Optic.get Request.Headers.authorization_
            |> Freya.map (fun opt -> opt.IsSome)
        if hasHeader then
            do! Log.message "Auth header found"
                |> Log.debug
        else
            do! Log.message "No auth header"
                |> Log.debug
        return hasHeader
    }
```

Most of the code here is actually logging - but you won't regret it when your customers ask you why they can't authenticate against your API.

Now we're onto the more interesting case; the caller has made an attempt to access a secured resource, and they've supplied some authentication to try and do so.

Let's check first if they've supplied a "Bearer" token; this is the only authentication style we're allowing at the moment.

``` fsharp
let token =
    freya {
        let! auth = Freya.Optic.get Request.Headers.authorization_
        match auth with
        | None ->
            // We should never reach this branch without an auth header -
            // it should be caught by the isAuthed check
            do! Log.message "No auth header found when checking authorization"
                |> Log.warn
            return None
        | Some a when not (a.StartsWith("Bearer ")) ->
            do! Log.message "Auth found, but not of type Bearer"
                |> Log.debug
            return None
        | Some a ->
            do! Log.message "Bearer token extracted"
                |> Log.debug
            return Some <| a.Substring(7)
    } |> Freya.memo
```

Now we can check the token to see if it is valid. If the token is a JWT token we could choose to check it locally; we have the public key of the issuer available. Here I've decided to go the route of checking each token with the issuer, as that means that we pick up things like token cancellation. Your strategy here will depend a lot on your use case, and `IdentityModel` also allows for caching to allow a good compromise.

Checking the token can be done via an asynchronous call with the `IntrospectionClient`. As I'm using Freya compiled against `Hopac` I'm wrapping it in a `job` - you could equally wrap it in an `async` block if you've using Async Freya.

``` fsharp
let checkToken apiName apiSecret t =
    job {
        use introClient =
            new IntrospectionClient(doc.IntrospectionEndpoint,
                                    apiName, apiSecret)
        return!
            introClient.SendAsync(IntrospectionRequest(Token = t))
            |> Hopac.Job.awaitTask
    }
```

And now the last step is to build a `allowed` decision point. Our decision point takes three parameters: the name of this API resource, as known to the identity server, the shared secret between resource and identity server, and the scope this particular resource within the API requires. Normally this will be something like `read` or `write`. An entire API will normally share a single name and secret, while each endpoint may require a different scope.

``` fsharp
let isAllowedFor apiName apiSecret scope =
    freya {
        let! token = token
        match token with
        | None ->
            return false
        | Some t ->
            let! resp =
                checkToken apiName apiSecret t
                |> Freya.fromJob
            let scopeMatch =
                resp.Claims
                |> Seq.exists (fun c -> c.Type = "scope" && c.Value = scope)
            let clientId =
                resp.Claims
                |> Seq.tryFind (fun c -> c.Type = "client_id")
            let isAllowed =
                resp.IsActive && scopeMatch && clientId.IsSome
            if isAllowed then
                do! Freya.Optic.set
                        Request.clientId_
                        (clientId |> Option.map (fun c -> c.Value))
                do! Log.message "Request allowed to scope {scope}"
                    |> Log.add scope
                    |> Log.info
            else
                do! Log.message "Invalid token supplied"
                    |> Log.debug
            return isAllowed
    } |> Freya.memo

let authMachine apiName apiSecret scope =
    freyaMachine {
        allowed (isAllowedFor apiName apiSecret scope)
        authorized isAuthed
        methods [GET; HEAD; OPTIONS] }
```

Apart from actually checking whether access is allowed, the other important thing we do here is add the calling clientId to the OWIN state. This means that we can make use of the clientId in any further pipeline steps (and in our logging).

So: we now have an `authMachine` which will check if you're allowed to do something... but doesn't actually do anything itself.

Time to switch back to `Api.fs` from the template project (making sure you've added in both the `Logging` and `Auth` modules to the project).

Amend your `helloMachine` as follows:

``` fsharp 
let helloMachine =
    freyaMachine {
        including (authMachine "myApi" "apiSecret" "myApi.read")
        methods [GET; HEAD; OPTIONS]
        handleOk sayHello }
```

and finally make sure that you remember to inject your logger (see the previous blog post):

``` fsharp
let root config =
    Pipeline.compose
        (Log.injectLogger config)
        (freyaRouter { resource "/hello{/name}" helloMachine })
```

Now we should be able to spin everything up.

### Trying it all out

We'll be using [Client Credential](https://www.oauth.com/oauth2-servers/access-tokens/client-credentials/) authentication for this example; this is a grant type used when a "client" is requesting access to a "resource" when no "user" is present. It's a standard grant type covered by the OAuth specification, and we're going to assume that we have an OAuth2 compliant authority available to issue allow introspection of tokens.

This type of grant is generally used for service to service communication - there's no user interaction at all, just an agreed pre-shared "client secret" (an API key).

First we need to get a token from our identity server using our clientId and clientSecret (this client must be configured in the identity server).

If you're using IdentityServer4 like I am, your request will look like this (curl format):

``` bash
curl -X POST \
  http://identity.mavnn.co.uk/connect/token \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials&scope=myApi.read&client_id=myClient&client_secret=mySecret'
```

You'll get back a response including a token:

``` json
{
    "access_token": "eyJhbGciOi...",
    "expires_in": 3600,
    "token_type": "Bearer"
}
```

Now when you call the secured API, you need to add the token to your headers:

``` bash
curl -X GET \
  http://localhost/hello \
  -H 'authorization: Bearer eyJhbGciOi...'
```

If you don't supply the `authorization` header at all, you correctly get a `401` response; if the token is invalid or you (for example) try and use `Basic` authentication, you receive a `403`. Both return with an empty body; if you wanted to make the pages pretty you would need to add `handleUnauthorized` and `handleForbidden` to your `freyaMachine`. Here, for an API it's probably as meaningful to just leave the response empty. There isn't any further information to supply, after all.

And there it is: token bearer authentication set up for Freya.

Interested in how you can set up the whole environment in Kubernetes including IdentityServer, logging, metrics and all the other mod cons you could desire? There's still time to sign up for [Building Solid Systems in F#](/building-solid-systems-in-f-number/) at the end of the month!
