---
permalink: /throttling-the-level-of-concurrency-in-f/
layout: post
title: Throttling the level of concurrency in F#
published: true
comments: true
categories:
- 15below
- fake
- fsharp
- programming
---
Async.Parallel |> Async.RunSynchronously is great for running a load of stuff in parallel in F#, as long as you don't mind them all running at the same time.

Often, though, you want to map across a sequence and run functions on the elements in parallel, but with a limit to how many are being processed concurrently. Whether you're doing something CPU heavy and there's no point running more than the number of processors on the box, or whether you know that you'll swamp a remote server if you just dump all of your connections on it at once, this issue comes up surprisingly often.

As a first stab, you might be tempted to do something like this (if you think like I do):

``` fsharp
let inline doParallelWithThrottle limit f items =
    use sem = new System.Threading.Semaphore(limit, limit)
    items
    |> Seq.map (fun element -> async {
            sem.WaitOne() |> ignore
            let result = Async.RunSynchronously <| async { return f element }
            sem.Release() |> ignore
            return result
        })
    |> Async.Parallel
    |> Async.RunSynchronously
```

In a word: don't. The contention in the Semaphore make this enormously inefficient with even a few hundred tasks.

In the end, the simplest  implementation I could come up with that didn't involve dragging in external dependencies was the following:

``` fsharp
open System.Collections.Concurrent
 
type JobRequest<'T> =
    {
        Id : int
        WorkItem : 'T
    }
 
type WorkRequest<'T> =
    | Job of JobRequest<'T>
    | End
 
let inline doParallelWithThrottle<'a, 'b> limit f items =
    let itemArray = Seq.toArray items
    let itemCount = Array.length itemArray
    let resultMap = ConcurrentDictionary<int, 'b>()
    use block = new BlockingCollection<WorkRequest<'a>>(1)
    use completeBlock = new BlockingCollection<unit>(1)
    let monitor = 
        MailboxProcessor.Start(fun inbox ->
            let rec inner complete =
                async {
                    do! inbox.Receive()
                    if complete + 1 = limit then
                        completeBlock.Add(())
                        return ()
                    else
                        return! inner <| complete + 1
                }
            inner 0)
    let createAgent () =
        MailboxProcessor.Start(
            fun inbox ->
                let rec inner () = async {
                        let! request = async { return block.Take() }
                        match request with
                        | Job job ->
                            let! result = async { return f (job.WorkItem) }
                            resultMap.AddOrUpdate(job.Id, result, fun _ _ -> result) |> ignore
                            return! inner ()
                        | End  ->
                            monitor.Post ()                            
                            return ()
                    }
                inner ()
        )
    let agents =
        [| for i in 1..limit -> createAgent() |]
    itemArray
    |> Array.mapi (fun i item -> Job { Id = i; WorkItem = item })
    |> Array.iter (block.Add)
 
    [1..limit]
    |> Seq.iter (fun x -> block.Add(End))
 
    completeBlock.Take()
    let results = Array.zeroCreate itemCount
    resultMap
    |> Seq.iter (fun kv -> results.[kv.Key] <- kv.Value)
    results
```

