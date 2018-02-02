---
layout: post
title: "Getting Started with F# in Kubernetes"
date: 2018-02-02 14:44:21 +0000
comments: true
categories: [fsharp, Kubernetes]
---
> Author's note: This post is a quick start to help you get a single F# based service up and running on Kubernetes. If you want the full story on how to design a distributed system, we offer [commercial training](https://blog.mavnn.co.uk/building-solid-systems-in-f-number/) and [consulting services](https://mavnn.co.uk/) to help you with that.

"Kubernetes is an open-source system for automating deployment, scaling, and management of containerized applications" - in other words, it will handle more deployment, health monitoring and service discovery needs out of the box, as long as you can turn your application into a container. So, let's have a quick look at how to do that with an F# application.

<!-- more -->

## Prerequisites

We going to use Minikube to start up a local Kubernetes "cluster" (it will only have a single node), and installation and first start depend slightly on operating system and which virtual machine backend you want it to use. Instructions on installing it can be found [here](https://github.com/kubernetes/minikube).

Note that Minikube depends in turn on [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) which will also need to be installed.

The example application we're going to deploy is going to be a .NET Core app running on Linux, so you will also need the .NET Core SDK 2.0+ installed. We're going to leverage the `dotnet` command line tool a fair bit.

Finally, most of the commands you need to run will be given in bash syntax. Hopefully you have bash installed (via installing `git` if nothing else!), but if you don't it should be fairly clear how to carry the steps out in other consoles.

## Actually Doing Stuff

First things first; start up minikube.

``` sh
minikube start # you may need options here depending on desired virtual machine software
```

It will take a little while to get going, especially on the first run when it will download an ISO image to create its own virtual machine. You can carry on with other steps as it warms up.

While that's going on, let's lay out a nice project structure to store all the things we're going to need. All future command line snippets will assume you're running them from the root of this structure.

``` sh
mkdir kube # Stores Kubernetes config
mkdir src # our F# code
mkdir docker # docker config
```

Before we can run an application in Kubernetes, we need an application. So let's start with that. We're going to use the .NET Core [Freya](https://docs.freya.io/en/latest/) template to create a simple console application with a single HTTP endpoint on it.

If you don't have the Freya template installed, grab it first using:

``` sh
dotnet new --install "Freya.Template::*"
```

Now we can create our project.

``` sh
dotnet new freya -o src/WebHello
```

Run a restore just to make sure everything is as it should be, and then you should be able to start up your service:

``` sh
dotnet restore src/WebHello/WebHello.fsproj
dotnet run -p src/WebHello/WebHello.fsproj
```

It should tell you it has started a web server on socket 8080, and surfing to `http://localhost:8080/hello` should get you a "Hello, world!" response.

Great - it works! Hit ctrl-c to shut it down again.

We just need to make one change here; because we're going to deploy this on a container, we can't only listen on local host. Go into Program.fs, and change the `main` function to look like this:

``` fsharp
[<EntryPoint>]
let main argv =
    let myCfg =
        { defaultConfig with
            bindings = [ HttpBinding.createSimple HTTP "0.0.0.0" 8080 ]
        }

    startWebServer
        myCfg
        (Owin.OwinApp.ofAppFunc "/" (OwinAppFunc.ofFreya Api.root))

    0
```

Now we need to turn it into a docker container so it can run on Kubernetes.

Create a new file in the docker directory called `WebHelloDockerfile` (imaginative, I know). Docker will use this file to create a image based on our code. To make sure that the image created is the same as what we're going to deploy in production, we don't create the image from the compilation output on our development box - instead, we actually use a intermediate docker container to build our source code with a known version of the .NET Core tool chain. We use the exact same docker file (and therefore versions of the tool chain) for our continuous integration builds. *Thanks to [Steve Gordon](http://twitter.com/stevejgordon) for pointing out this trick for me.*

Into the file, put this contents:

```
FROM microsoft/dotnet:2.0-sdk AS BUILD
WORKDIR /build
COPY src src
RUN dotnet restore src/WebHello/WebHello.fsproj
RUN dotnet publish src/WebHello/WebHello.fsproj -o out -c Release --no-restore

FROM microsoft/dotnet:2.0-runtime
WORKDIR /app
COPY --from=BUILD /build/src/WebHello/out .
EXPOSE 8080
ENTRYPOINT dotnet /app/WebHello.dll
```

This is a multistage docker build; we're asking docker to use the a container based on `microsoft/dotnet:2.0-sdk` to restore and build our code - but the final image we're creating (i.e. the last one in the file) is based on `microsoft/dotnet:2.0-runtime`, just copying across the result of running `dotnet publish`. Between the final image not having the SDK installed, and only copying exactly the files we need to run our application, we create a much smaller image this way.

Don't run a normal docker build straight away! Even if you have docker installed, we don't want to build this image on your computer's docker - we want to build it directly in minikube's docker so that Kubernetes can find it. Kubernetes also knows how to pull images from external docker repositories, but we don't want to set one up right now.

To run a command inside minikube, we can take advantage of minikube's ssh and mount functionality.

In a separate terminal (or as a detached process if you know what you're doing) in the same directory, run:

``` sh 
minikube mount .:/host
```

This will expose the current directory (`.`) to the minikube machine at the location `/host`. You might need to use a full path local under windows, quoting it so the `:` in the drive name doesn't confuse things.

Now (back in our original terminal) we can run:

``` sh
minikube ssh "cd /host; docker build -f docker/WebHelloDockerfile -t webhello ."
```

No need to even have docker installed on your host computer at all. Running this command will take quite a while the first time; don't worry too much, it caches everything so it will be pretty quick from now on.

So this is all great, and we now have a docker container. We still need to tell Kubernetes about it though. Create yourself an other file, this time in the kube directory. Call it `webhello.yml` and put this in it:

```
apiVersion: v1
kind: Service
metadata:
  name: webhello
spec:
  selector:
    app: webhello
  ports:
  - name: http
    port: 8080
    protocol: TCP
    targetPort: http
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: webhello
spec:
  selector:
    matchLabels:
      app: webhello
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: webhello
    spec:
      containers:
      - image: "webhello"
        imagePullPolicy: Never
        name: webhello
        resources:
          requests:
            memory: "128Mi"
          limits:
            memory: "256Mi"
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        readinessProbe:
          httpGet:
            path: "/hello"
            port: http
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 10
          successThreshold: 1
          timeoutSeconds: 10
        livenessProbe:
          httpGet:
            path: "/hello"
            port: http
            scheme: HTTP
          failureThreshold: 2
          initialDelaySeconds: 20
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 5
```

Whoa! That's a wall of text. What's going on here?

Well, the first section is telling Kubernetes that we want a service called `webhello`; it should expose a port called `http` and it should route requests to it to `pods` that are part of the app called `webhello`.

What are these `pods`? Well, you can read more about that in the Kubernetes documentation, but for now we can assume they are instances of our application running. But our service won't do anything until it has pods to route to, which is where the second section of the file kicks in. Here we tell Kubernetes that we want to create a deployment with rules to govern how the `webhello` app should be deployed. We say that there should be 3 copies running, and that when new versions are rolled out that we want to start a pod with the new version and wait for it to be healthy before we shut down each old pod (the `maxUnavailable` bit).

Finally, we give a specification of how to create these 3 pods we've asked for; we want to base it on the image `webhello` (using the local version, and not trying to check for updates...), it shouldn't need much memory (the limit helps the garbage collector kick in), it exposes a port and that it shouldn't be considered alive or ready if it doesn't respond with a success code on http requests to the endpoint `/hello`.

In yet an other terminal, fire up the command `kubectl proxy`. This will give you access to the Kubernetes api, including it's built in dashboard. If you now surf to the [pods page](http://127.0.0.1:8001/api/v1/proxy/namespaces/kube-system/services/Kubernetes-dashboard/#!/pod?namespace=default) in the dashboard, it should tell you there are no pods deployed.

Back to our first terminal; run:

```
kubectl apply -f kube/
```

To apply all of the config files in the kube directory to the currently connected cluster.

Refresh your dashboard a few times, and you should slowly see your pods appearing and becoming live.

This is good progress - we have a service up and running. Unfortunately, we can't see it.

For our final step, let's configure Kubernetes to allow external access to this service. This is normally done by making use of the Ingress resource - what that actually represents is up to your Kubernetes provider, but in the case of Minikube it will use an nginx server as a proxy from the outside world to our services.

First, make sure minikube has ingress support enabled:

``` sh 
minikube addons enable ingress
```

Now add a second file into the kube directory called `ingress.yml`. Stick the following content in:

```
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress
spec:
  rules:
  - http:
      paths:
        - path: /hello
          backend:
            serviceName: webhello
            servicePort: http
```

Hopefully it should be fairly clear what this does!

Apply our config to the cluster again:

``` sh
kubectl apply -f kube/
```

Setting up the ingress can take a moment, so run:

``` sh
kubectl get ingress
```

a few times until you get a response in that contains an IP address. At this point, you should be able to hit the IP address listed by `kubectl` on the `/hello` or `/hello/yourName` paths; normally it will be [http://192.168.99.100/hello](http://192.168.99.100/hello). Depending on Minikube version, you might have to allow a self signed certificate called "ingress.local" to get through.

And there you have it - an F# service deployed in Kubernetes.

One last trick - because you're just pushing images direct into Minikube's docker rather than into a registry of any kind, Kubernetes won't pick up new versions of the image. If you do a build and want to deploy the changed image, try using something like this to add a `updated` timestamp to your deployment configuration:

``` sh
kubectl patch deployment webhello -p="{ \"spec\": { \"template\": {\"metadata\": {\"labels\":{\"updated\": \"$(date +"%s")\" }}}}}"
```

Because your deployment has changed, Kubernetes will then try and refresh all the pods with the latest version of the image. Enjoy watching your magic, zero down time deploy roll on through.

That's it for now!
