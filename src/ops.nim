import times, os, threadpool
import "./core", "./schedulers"

proc lift[A, B](o: Observable[A], f: proc(s: Subscriber[B], a: A), sch: Scheduler): auto =
  create(proc(s: Subscriber[B]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) = sch.schedule(proc() =
        f(s, a)
      ),
      onComplete = proc() =
        sch.schedule(s.onComplete),
      onError = proc(e: ref Exception) = sch.schedule(proc() =
        s.onError(e)
      )
    ))
  )

proc map*[A, B](o: Observable[A], f: proc(a: A): B, sch = immediateScheduler()): Observable[B] =
  lift[A, B](o, proc(s: Subscriber[B], a: A) = s.onNext(f(a)), sch)

proc foreach*[A](o: Observable[A], f: proc(a: A)) =
  o.subscribe(subscriber[A](f))

proc filter*[A](o: Observable[A], f: proc(a: A): bool, sch = immediateScheduler()): Observable[A] =
  lift[A, A](o,
    proc(s: Subscriber[A], a: A) =
      if f(a): s.onNext(a),
    sch)

proc take*[A](o: Observable[A], n: int): Observable[A] =
  var count = 0
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      proc(a: A) =
        if count < n:
          inc count
          s.onNext(a)
        else:
          s.onComplete(),
      s.onComplete,
      s.onError
    ))
  )

proc drop*[A](o: Observable[A], n: int): Observable[A] =
  var count = 0
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        if count <= n - 1:
          count += 1
        else:
          s.onNext(a),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc concat*[A](o1, o2: Observable[A]): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o1.subscribe(subscriber(
      onNext = s.onNext,
      onComplete = proc() =
        o2.subscribe(s),
      onError = s.onError
    ))
  )

proc delay*[A](o: Observable[A], t: TimeInterval, sch = immediateScheduler()): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) = sch.schedule(proc() =
        s.onNext(a)
      , t),
      onComplete = proc() =
        sch.schedule(s.onComplete),
      onError = proc(e: ref Exception) = sch.schedule(proc() =
        s.onError(e)
      )
    ))
  )

proc delay*[A](o: Observable[A], millis: proc(a: A): int): Observable[A] =
  create(proc(s: Subscriber[A]) =
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        s.onNext(a)
        sleep(millis(a)),
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc buffer*[A](o: Observable[A], n: int): Observable[seq[A]] =
  create(proc(s: Subscriber[seq[A]]) =
    var buffer = newSeq[A](n)
    var i = 0
    o.subscribe(subscriber(
      onNext = proc(a: A) =
        buffer[i] = a
        i += 1
        if i == n:
          s.onNext(buffer)
          buffer = newSeq[A](n)
          i = 0,
      onComplete = s.onComplete,
      onError = s.onError
    ))
  )

proc buffer*[A](o: Observable[A], t: TimeInterval): Observable[seq[A]] =
  let millis = t.milliseconds + 1000 * t.seconds # fix this

  create(proc(s: Subscriber[seq[A]]) =
    var channel: Channel[A];
    channel.open()
    try:

      proc readFromOtherThread(ch: ptr Channel[A], s1: Subscriber[seq[A]], m: int) {.thread.} =
        while true:
          let n = ch[].peek()
          if n < 0: break
          var buffer = newSeq[A](n)
          for i in 0 .. < n:
            buffer[i] = ch[].recv()
          s1.onNext(buffer)
          sleep(m)

      spawn readFromOtherThread(addr channel, s, millis)

      o.subscribe(subscriber(
        onNext = proc(a: A) =
          channel.send(a),
        onComplete = s.onComplete,
        onError = s.onError
      ))

    finally:
      while channel.peek > 0:
        sleep(1)
      channel.close()
  )

proc sendToNewThread*[A](o: Observable[A]): Observable[A] =

  create(proc(s: Subscriber[A]) =
    var channel: Channel[A];
    channel.open()
    try:

      proc readFromOtherThread(ch: ptr Channel[A], s: Subscriber[A]) {.thread.} =
        while true:
          let len = ch[].peek()
          if len < 0: break
          if len == 0:
            sleep(1)
          for i in 0..<len:
            s.onNext(ch[].recv())

      spawn readFromOtherThread(addr channel, s)

      o.subscribe(subscriber(
        onNext = proc(a: A) =
          channel.send(a),
        onComplete = s.onComplete,
        onError = s.onError
      ))

    finally:
      while channel.peek > 0:
        sleep(1)
      channel.close()
  )