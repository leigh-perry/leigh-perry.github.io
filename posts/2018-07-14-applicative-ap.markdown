---
title: The mystery of Applicative's <*> operator (ap)
---

When I was learning about the `Applicative` typeclass, originally in Scala, it seemed a little strange. 
`Applicative` sits between `Functor` and `Monad` in the typeclass hierarchy.
Simplified somewhat, they look like:
```scala
trait Functor[F[_]] {
 def map[A, B](fa: F[A])(f: A => B): F[B]
}

trait Applicative[F[_]] extends Functor[F] {
 def pure[A](a: A): F[A]
 def ap [A, B](fa: F[A])(ff: F[A => B]): F[B]
}

trait Monad[F[_]] extends Applicative[F] {
  def flatMap[A, B](fa: F[A])(f: A => F[B]): F[B]
}
```

See [this explanation](http://adit.io/posts/2013-04-17-functors,_applicatives,_and_monads_in_pictures.html) for some illuminating visualisations.

`Functor` and `Monad` make intuitive sense once you get used to what they do.
But `Applicative` was a different matter.
It has that weird `ap` method, that takes as a parameter `ff` which is a function from `A` to `B` in the effect `F`.
I don't know about you, but I don't often end up with a function in an effect.
Probably never.
So what is it about?


# What?

`ff: F[A => B]`?

It turns out that you end up with a function in `F` when you use `Functor.map` with a function that takes more than one argument.
(For this to happen, the function must be in curried form `A => B => C` rather than the more Scala-idiomatic `(A, B) => C` uncurried form).
```scala
  val f: A => B => C = ...
  val o: Option[A] = a.some
  val o2: Option[B => C] = o.map(f)
```

There it is. `o2` is a function in an effect (`Option`).

# When?

When do you use this?
`Applicative`'s reason for existence is the combination of independent effect instances.
In Haskell, this is commonly expressed as the idiomatic `Applicative` chain
```haskell
  effectD = f <$> effectA <*> effectB <*> effectC
```
In this, `f` has type `a -> b -> c -> d`, while
`effectA` is `F a`,
`effectB` is `F b`, and
`effectC` is `F c`.

In Scala, this is more or less:
```scala
  val fa: F[A] = ...
  val fb: F[B] = ...
  val fc: F[C] = ...
  val f: (A, B, C) => D = ...
  val fc: A => B => C => D = f.curried
  val effectD: F[D] = ap(effectC)(ap(effectB)(map(effectA)(fc)))
```

The significant part here is `map(effectA)(f.curried)`. 
This maps the curried function (`A => B => C => D`) over effectA.
That is, it applies `fc(a)`.
But this just partially applies the `A` to `fc`, yielding `B => C => D` in the returned effect, ie `F[B => C => D]`.
This is then fed into `ap` on `effectB`, which partially applies the `B` parameter.
And so on until the function is fully applied, yielding a `D` in the returned effect, ie `F[D]`.

# Executive Summary

You get a function in an effect via partial application.
