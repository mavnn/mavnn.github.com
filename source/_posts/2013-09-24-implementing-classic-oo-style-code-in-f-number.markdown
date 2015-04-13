---
layout: post
title: "Implementing classic OO style code in F#"
date: 2013-09-24 14:21
comments: true
categories: 
- Programming
- FSharp
---
As part of writing up notes for introducing F# as a programming language to experienced C# devs I was looking for examples
of heavily OO code being implemented in F#. Then I realised that I'd written at least one suitable example myself.

In the [NuGetPlus project]("https://github.com/mavnn/NuGetPlus") I needed to implement a ProjectSystem class that was almost a direct copy of the MSBuildProjectSystem in the NuGet commandline client.

So without further ado, F# and then C# versions of a class with inheritance and which implements several interfaces.

<!--more-->

The [ProjectSystem class from NuGetPlus]("https://github.com/mavnn/NuGetPlus/blob/master/NuGetPlus.Core/ProjectSystem.fs"):

``` fsharp
[<AutoOpen>]
module NuGetPlus.ProjectSystem
 
open System
open System.IO
open System.Collections.Generic
open System.Reflection
open Microsoft.Build.Evaluation
open NuGet
 
let TryGetProject projectFile = 
    ProjectCollection.GlobalProjectCollection.GetLoadedProjects(projectFile) 
    |> Seq.tryFind(fun p -> p.FullPath = projectFile)
 
type ProjectSystem(projectFile : string) = 
    inherit PhysicalFileSystem(Path.GetDirectoryName(projectFile))
    
    let project = 
        match TryGetProject projectFile with
        | Some project -> project
        | None -> Project(projectFile)
    
    let projectName = Path.GetFileNameWithoutExtension <| project.FullPath
    let framework = 
        new Runtime.Versioning.FrameworkName(project.GetPropertyValue
                                                 ("TargetFrameworkMoniker"))
    
    let GetReferenceByName name =
        project.GetItems("Reference")
        |> Seq.filter
               (fun i -> 
                   i.EvaluatedInclude.StartsWith
                       (name, StringComparison.OrdinalIgnoreCase))
        |> Seq.tryFind
               (fun i -> 
                   AssemblyName(i.EvaluatedInclude)
                       .Name.Equals(name, StringComparison.OrdinalIgnoreCase))
 
    let GetReferenceByPath path = 
        let name = Path.GetFileNameWithoutExtension path
        GetReferenceByName name
    
    interface IProjectSystem with
        member x.TargetFramework with get () = framework
        member x.ProjectName with get () = projectName
        
        member x.AddReference(path, stream) = 
            let fullPath = PathUtility.GetAbsolutePath(x.Root, path)
            let relPath = 
                PathUtility.GetRelativePath(project.FullPath, fullPath)
            let includeName = Path.GetFileNameWithoutExtension fullPath
            project.AddItem
                ("Reference", includeName, [|KeyValuePair("HintPath", relPath)|]) 
            |> ignore
            project.Save()
        
        member x.AddFrameworkReference name = 
            project.AddItem("Reference", name) |> ignore
            project.Save()
        
        member x.ReferenceExists path = 
            match GetReferenceByName path with
            | Some _ -> true
            | None -> false
        
        member x.RemoveReference path = 
            match GetReferenceByPath path with
            | Some i -> 
                project.RemoveItem(i) |> ignore
                project.Save()
            | None -> ()
        
        member x.IsSupportedFile path = true
        member x.ResolvePath path = path
        member x.IsBindingRedirectSupported with get () = true
        
        member x.AddImport((targetPath : string), location) = 
            if project.Xml.Imports = null 
               || project.Xml.Imports 
                  |> Seq.forall
                         (fun import -> 
                             not 
                             <| targetPath.Equals
                                    (import.Project, 
                                     StringComparison.OrdinalIgnoreCase)) then 
                project.Xml.AddImport(targetPath) |> ignore
                project.ReevaluateIfNecessary()
                project.Save()
        
        member x.RemoveImport(targetPath : string) = 
            match project.Xml.Imports 
                  |> Seq.tryFind
                         (fun import -> 
                             targetPath.Equals
                                 (import.Project, 
                                  StringComparison.OrdinalIgnoreCase)) with
            | None -> ()
            | Some i -> 
                project.Xml.RemoveChild(i)
                project.ReevaluateIfNecessary()
                project.Save()
        
        member x.FileExistsInProject(path : string) = 
            project.Items 
            |> Seq.exists
                   (fun i -> 
                       i.EvaluatedInclude.Equals
                           (path, StringComparison.OrdinalIgnoreCase) 
                       && (String.IsNullOrEmpty(i.ItemType) 
                           || i.ItemType.[0] <> '_'))
    
    interface IPropertyProvider with
        member x.GetPropertyValue name = project.GetPropertyValue(name) :> obj
```

and the [MSBuildProjectSystem class from NuGet]("http://nuget.codeplex.com/SourceControl/latest#src/CommandLine/Common/MSBuildProjectSystem.cs"):

``` fsharp
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.Versioning;
using Microsoft.Build.Evaluation;
 
namespace NuGet.Common
{
    public class MSBuildProjectSystem : PhysicalFileSystem, IMSBuildProjectSystem
    {
        public MSBuildProjectSystem(string projectFile)
            : base(Path.GetDirectoryName(projectFile))
        {
            Project = GetProject(projectFile);
        }
 
        public bool IsBindingRedirectSupported
        {
            get
            {
                return true;
            }
        }
 
        private Project Project
        {
            get;
            set;
        }
 
        public void AddFrameworkReference(string name)
        {
            // No-op
        }
 
        public void AddReference(string referencePath, Stream stream)
        {
            string fullPath = PathUtility.GetAbsolutePath(Root, referencePath);
            string relativePath = PathUtility.GetRelativePath(Project.FullPath, fullPath);
            // REVIEW: Do we need to use the fully qualified the assembly name for strong named assemblies?
            string include = Path.GetFileNameWithoutExtension(fullPath);
 
            Project.AddItem("Reference",
                            include,
                            new[] { 
                                    new KeyValuePair<string, string>("HintPath", relativePath)
                                });
        }
 
        public dynamic GetPropertyValue(string propertyName)
        {
            return Project.GetPropertyValue(propertyName);
        }
 
        public bool IsSupportedFile(string path)
        {
            return true;
        }
 
        public string ProjectName
        {
            get
            {
                return Path.GetFileNameWithoutExtension(Project.FullPath);
            }
        }
 
        public bool ReferenceExists(string name)
        {
            return GetReference(name) != null;
        }
 
        public void RemoveReference(string name)
        {
            ProjectItem assemblyReference = GetReference(name);
            if (assemblyReference != null)
            {
                Project.RemoveItem(assemblyReference);
            }
        }
 
        private IEnumerable<ProjectItem> GetItems(string itemType, string name)
        {
            return Project.GetItems(itemType).Where(i => i.EvaluatedInclude.StartsWith(name, StringComparison.OrdinalIgnoreCase));
        }
 
        public ProjectItem GetReference(string name)
        {
            name = Path.GetFileNameWithoutExtension(name);
            return GetItems("Reference", name)
                .FirstOrDefault(
                    item =>
                    new AssemblyName(item.EvaluatedInclude).Name.Equals(name, StringComparison.OrdinalIgnoreCase));
        }
 
        public FrameworkName TargetFramework
        {
            get
            {
                string moniker = GetPropertyValue("TargetFrameworkMoniker");
                if (String.IsNullOrEmpty(moniker))
                {
                    return null;
                }
                return new FrameworkName(moniker);
            }
        }
 
        public string ResolvePath(string path)
        {
            return path;
        }
 
        public void Save()
        {
            Project.Save();
        }
 
        public bool FileExistsInProject(string path)
        {
            // some ItemTypes which starts with _ are added by various MSBuild tasks for their own purposes
            // and they do not represent content files of the projects. Therefore, we exclude them when checking for file existence.
            return Project.Items.Any(
                i => i.EvaluatedInclude.Equals(path, StringComparison.OrdinalIgnoreCase) && 
                     (String.IsNullOrEmpty(i.ItemType) || i.ItemType[0] != '_'));
        }
 
        private static Project GetProject(string projectFile)
        {
            return ProjectCollection.GlobalProjectCollection.GetLoadedProjects(projectFile).FirstOrDefault() ?? new Project(projectFile);
        }
 
        public void AddImport(string targetPath, ProjectImportLocation location)
        {
            if (targetPath == null)
            {
                throw new ArgumentNullException("targetPath");
            }
 
            // adds an <Import> element to this project file.
            if (Project.Xml.Imports == null ||
                Project.Xml.Imports.All(import => !targetPath.Equals(import.Project, StringComparison.OrdinalIgnoreCase)))
            {
                Project.Xml.AddImport(targetPath);
                NuGet.MSBuildProjectUtility.AddEnsureImportedTarget(Project, targetPath);
                Project.ReevaluateIfNecessary();
                Project.Save();
            }
        }
 
        public void RemoveImport(string targetPath)
        {
            if (targetPath == null)
            {
                throw new ArgumentNullException("targetPath");
            }
 
            if (Project.Xml.Imports != null)
            {
                // search for this import statement and remove it
                var importElement = Project.Xml.Imports.FirstOrDefault(
                    import => targetPath.Equals(import.Project, StringComparison.OrdinalIgnoreCase));
 
                if (importElement != null)
                {
                    Project.Xml.RemoveChild(importElement);
                    NuGet.MSBuildProjectUtility.RemoveEnsureImportedTarget(Project, targetPath);
                    Project.ReevaluateIfNecessary();
                    Project.Save();
                }
            }
        }
    }
}
```

I can't honestly remember if they do exactly the same thing, but they are pretty similar and implement the same interfaces and inheritance. As you can see, while F#'s focus is being functional it will support OO code just fine, which is very useful indeed when you need to interop with .NET code from other languages and coding styles.
