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

`Functor` and `Monad` make intuitive sense once you get used to what they do.
But `Applicative` was a different matter.
It has that weird `ap` method, that takes as a parameter `ff` which is a function from `A` to `B` in the effect `F`.
I don't know about you, but I don't often end up with a function in an effect.
Probably never.
So what is it about?
