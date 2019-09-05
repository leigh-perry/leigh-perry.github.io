---
title: Converting Haskell's fix function to Scala
---

[This article](/posts/2019-04-01-fix-haskell-function.html) introduces the `fix` function – the essence of recursion.
It was neatly expressed in Haskell. 
In fact, the implementation is almost identical to the lambda calculus version, probably because
Haskell's syntax was itself based on lambda calculus.
```haskell
fix :: (t -> t) -> t
fix g = g (fix g)
```

How to implement this in Scala? A naive port yields this:
```scala
  def fix[T]: (T => T) => T =
    f => f(fix(f))
``` 

Now implementing fix-ed factorial:
```scala
  def factorial: (Int => Int) => Int => Int =
    f => n => if (n == 1) 1 else n * f(n - 1)

  val fixfac: Int => Int = fix(factorial)
  println(fixfac(6))
``` 

This compiles fine but there is one small problem – stack overflow.

The problem is that Scala performs eager evaluation, so `f(fix(f))` evaluates immediately and infinitely. 
In Haskell, lazy evaluation prevents this issue. 
It goes to show how lazy evaluation lets you write programs in an idealised way, not worrying about
behaviour or termination.
 