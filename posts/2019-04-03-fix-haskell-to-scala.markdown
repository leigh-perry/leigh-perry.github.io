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

But looking at the code 
```scala
  def fix[T]: (T => T) => T = ...
```
and
```scala
  def factorial: (Int => Int) => Int => Int = ...
```
we see that in this case, `T` is actually `Int => Int`.
Therefore `fix` can be expanded to reflect that `T` is a function from `A => A`:
```scala
  def rec[A, B]: ((A => A) => (A => A)) => (A => A) =
    f => f(rec(f))
``` 
This still stack overflows, but we can change it again slightly to reflect that brackets around the rightmost
`A => A` were redundant: 
```scala
  def rec[A, B]: ((A => A) => (A => A)) => A => A =
    f => f(rec(f))
``` 
Looking at this as a curried function, it has two argument.
First the function `((A => A) => (A => A))` that is to be fixed.
The second argument is an `A`.
This leaves just the return value of type `A`.

Armed with this, we can reimplement as a two argument curried function:
```scala
  def rec[A, B]: ((A => A) => (A => A)) => A => A =
    f => a => f(rec(f))(a)
``` 

And this doesn't stack overflow. The code `f(fix(f))` still executes eagerly but it only
partially applies the two argument function. It acts as a lazy evaluation thunk, somewhat like in Haskell. 

And we are done.
