---
title: Converting fix function to Fix data structure
---

[That article](/posts/2019-04-03-fix-haskell-to-scala.html) derives the `fix` function – the essence of recursion – for Scala.

But as well as recursive functions, Fix also describes data structures.
Let's follow the process of converting the `fix` function to a data structure. 
As I showed in [the original article](/posts/2019-04-01-fix-haskell-function.html), the Haskell function is defined:
```haskell
fix f = f (fix f)
``` 

First, replace the argument polymorphism with type polymorphism.
This is more or less just capitalising the names and wrapping type parameters in square brackets:
```scala
final case class Fix[F](f: F[Fix[F]])
```

This doesn't quite compile, since `F` itself has to take a type parameter, so must be `F[_]`:
```scala
final case class Fix[F[_]](f: F[Fix[F]])
```

The fixed data item `f` is usually called `unfix`:
```scala
final case class Fix[F[_]](unfix: F[Fix[F]])
```

Sorted.
