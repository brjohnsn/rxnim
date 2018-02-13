import threadpool, times
import rxpkg/schedulers, rxpkg/core, rxpkg/ops, rxpkg/connectable

export schedulers, core, ops, connectable



when isMainModule:
  import future, sequtils

  proc println[A](a: A) = echo(a)

  var o = observable(@[1, 2, 3, 4, 5])
    .map((x: int) => x * x)
    .filter((x: int) => x > 3)
    .delay((x: int) => 10 * x)
    .sendToNewThread()
    .concat(single(6))
    .concat(single(3))
    .buffer(2)
    .publish()

  o.subscribe(subscriber[seq[int]](println))
  o.subscribe(subscriber[seq[int]](println))
  o.connect()

  repeat(12)
    .drop(3)
    .take(10)
    .sendToNewThread()
    .subscribe(subscriber[int](println))

  observable(1 .. 100)
    .delay((x: int) => x)
    .map((x: int) => x * x)
    .buffer(initInterval(seconds = 1))
    .subscribe(subscriber[seq[int]](println))

  sync()