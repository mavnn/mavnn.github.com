---
layout: post
title: "Coding Hygiene: Moving from project references to NuGet dependencies"
date: 2013-03-08 17:08
comments: true
categories:
- 15below
- fake
- fsharp
- programming
---
So, first post with the new blogging engine. Let's see how it goes.

Our code base at [15below](http://15below.com) started it's life a fair
while ago, well before any form of .NET package management became
practical. Because of that, we ended up building a lot of code in
'lockstep' with project references in code as there was no sensible way
of taking versioned binary dependencies.

That's fine and all, but it encourages bad code hygiene: rather than
having sharply defined contracts between components, if you've got them
all open in the same solution it becomes far too tempting to just nudge
changes around as it's convenient at the time. Changes can infect other
pieces of code, and the power of automatic refactoring across the entire
solution becomes intoxicating.

The result? It becomes very hard to do incremental builds (or
deployments, for that matter). This in turn makes for a long feed back
cycle between making a change, and being able to see it rolled out to a
testing environment.

So as part of the ongoing refactoring that any long lived code base needs to
keep it maintainable and under control, we've embarked on the process of
splitting our code down into more logically separated repositories that
reference each other via NuGet. This will require us to start being much
more disciplined in our [semantic versioning](http://semver.org) than we
have been in the past, but will also allow us to build and deploy
incrementally and massively reduce our feed back times.

As part of splitting out the first logical division (I'd like to say
[domain](http://en.wikipedia.org/wiki/Domain-driven_design) but we're
not there yet!), I created the new repository and got the included
assemblies up and building on TeamCity. It was only then (stupidly) that
I realised that we had several hundred project references to these
assemblies in our code. There was no way I was going to update them all
by hand, so after a few hours development we now have a script for
idempotently updating a project reference in a [cs|vb|fs]proj file to a
NuGet reference. It does require you to do one update manually first;
especially with assemblies that are strongly signed, I chickened out of
trying to generate the reference nodes that needed to be added
automatically. The script also makes sure that you end up with a
packages.config file with the project that includes the new dependency.

It should be noted that this script has only seen minimal testing, was
coded up for one time use and does not come with a warranty of any kind!
Use at your own risk, and once you understand what it's doing. But for
all that, I hope you find it useful.

```
#r "System.Xml.Linq"
#r "tools\FAKE\FakeLib.dll"
open System.IO
open System.Xml
open System.Xml.Linq
open System.Xml.XPath
open Fake

// You'll want to replace these values...
let nugetId = "my.package.id"
let refName = "my.ref.name"
let packageNode = XElement.Parse """<package id="my.package.id" version="1.0.0.6" targetFramework="net40" />"""
let refXml =
    """
    <Reference Include="my.ref.name">
      <HintPath>..\..\packages\my.package.id.1.0.0.6\lib\net40\my.ref.name.dll</HintPath>
      <Private>True</Private>
    </Reference>
    """
let hintPathFromRoot =
@"packages\my.package.id.1.0.0.6\lib\net40\my.ref.name.dll"
let sourceRoot = "C:\WhereIKeepMyRepo"

// You should be able to leave the rest alone
let ns = "http://schemas.microsoft.com/developer/msbuild/2003"
let nsm = new XmlNamespaceManager(new NameTable())
nsm.AddNamespace("ns", ns)
let nugetPath = sourceRoot @@ "tools" @@ "NuGet" @@ "NuGet.exe"

let HasProjectReference (projDoc : XDocument) refName =
    projDoc.Root.XPathSelectElements("//ns:ProjectReference[ns:Name='" + refName + "']", nsm)
    |> Seq.length
    |> (<) 0

let GetProjectReference (projDoc : XDocument) refName =
    projDoc.Root.XPathSelectElement("//ns:ProjectReference[ns:Name='" + refName + "']", nsm)

let DeleteProjectReference refName (projFile : string) =
    let projDoc = XDocument.Load(projFile)
    if HasProjectReference projDoc refName then
        let ref = GetProjectReference projDoc refName
        ref.Remove()
        projDoc.Save(projFile)

let HasReference (projDoc : XDocument) refName =
    projDoc.Root.XPathSelectElements("//ns:Reference[@Include='" + refName + "']", nsm)
    |> Seq.append <| projDoc.Root.XPathSelectElements("//ns:Reference[@Include[starts-with(., '" + refName + ",')]]", nsm)
    |> Seq.tryPick (fun e -> Some e)

let FirstReference (projDoc : XDocument) =
    projDoc.Root.XPathSelectElements("//ns:Reference", nsm)
    |> Seq.head

let GetHintPath hintPathFromRoot root projFile =
    let rootDir = DirectoryInfo(root)
    let projDir = DirectoryInfo(Path.GetDirectoryName(projFile))
    let rec dirDiff (rootDir : DirectoryInfo) (currentDir : DirectoryInfo) levels =
        if rootDir.FullName = currentDir.FullName then
            levels
        else
            dirDiff rootDir (currentDir.Parent) (levels + 1)
    hintPathFromRoot::[for _ in 1..(dirDiff rootDir projDir 0) -> ".."]
    |> List.rev
    |> List.fold (@@) "."

let UpdateHintPath projFile =
    let ref = XElement.Parse(refXml)
    let xs = XNamespace.Get(ns)
    let el = ref.XPathSelectElement("//HintPath")
    el.SetValue (GetHintPath hintPathFromRoot sourceRoot projFile)
    for node in ref.DescendantsAndSelf() do
        node.Name <- xs + node.Name.LocalName
    ref

let EnsureReference refName (projFile : string) =
    let doc = XDocument.Load(projFile)
    match HasReference doc refName with
    | Some el -> el.Remove()
    | None -> ()
    let el = FirstReference doc
    el.AddBeforeSelf(UpdateHintPath projFile)
    doc.Save(projFile)

type PackageFile =
    | Exists of string
    | Missing of string

let GetPackagesDotConfig projFile =
    let dir = Path.GetDirectoryName(projFile)
    let path = dir @@ "packages.config"
    if File.Exists(path) then
        Exists path
    else
        Missing path

let HasPackageReference (doc : XDocument) nugetId =
    doc.XPathSelectElements("//package[@id = '" + nugetId + "']")
    |> Seq.length
    |> (<) 0

let EnsurePackagesDotConfigHasPackage nugetId projFile =
    let doc, path =
        match GetPackagesDotConfig projFile with
        | Missing path ->
            XDocument.Parse("<packages />"), path
        | Exists path ->
            XDocument.Load(path), path
    if not <| HasPackageReference doc nugetId then
        doc.Root.XPathSelectElement("/packages").Add(packageNode)
        doc.Save path

let UpdateProj (projFile : string) =
    if HasProjectReference (XDocument.Load(projFile)) refName then
        DeleteProjectReference refName projFile
        EnsureReference refName projFile
        EnsurePackagesDotConfigHasPackage nugetId projFile

!+ (@"**\*.csproj")
++ (@"**\*.fsproj")
++ (@"**\*.vbproj")
|> Scan
|> Seq.map (fun proj -> printfn "Updating %s" proj; proj)
|> Seq.iter UpdateProj
```
