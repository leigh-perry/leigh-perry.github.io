---
title: Applicatives and Monoids 
---

Lukewarm on the heels of my series of [monoidal meditation](https://leigh-perry.github.io/posts/2019-11-13-monoids-function.html),
it is time to examine the connection between `Applicative` and `Monoid` typeclasses. 

# Similarities

Looking at the typeclasses for `Applicative`
```scala
trait Applicative[F[_]] extends Functor[F] {
 def pure[A](a: A): F[A]
 def ap[A, B](fa: F[A])(ff: F[A => B]): F[B]
}
```
and `Monoid`
```scala
trait Monoid[A] {
  def empty: A
  def combine(x: A, y: A): A
}
```
there are similarities.
Each has a kind of 'unit' function (`pure` and `empty`), and
each has a combination function (`ap` and `combine`).
It should come as no surprise, since the category theory for `Applicative`
is _lax monoidal functor_, since it represents monoidal combination inside effects.

# Interchangeability

It turns out that we can

- create a `Monoid` instance for any `Applicative`
- promote any `Monoid` to an `Applicative`

How?

## Monoid instance for any Applicative

This is easy. To create a `Monoid[F[A]]` where `F` has an `Applicative` instance,
just wrap the `empty` value with `pure`, and use the `Applicative` combination.

With this
```scala
    implicit def monoidForApplicative[F[_], A](
      implicit F: Applicative[F],
      M: Monoid[A]
    ): Monoid[F[A]] =
      new Monoid[F[A]] {
        override def empty: F[A] =
          F.pure(M.empty)
        override def combine(x: F[A], y: F[A]): F[A] =
          F.map2(x, y)(M.combine)
      }
```
we can now write
```scala
    val nelMonoid2 = Monoid[NonEmptyList[String]]
```
(Previously you would have had to write `Monoid[Option[NonEmptyList[String]]]`.)

## Promote Monoid to Applicative

This one is a bit harder, and requires some use of the fabulous `Const` data type
and its phantom type `B`.

From Cats,
```scala
final case class Const[A, B](getConst: A)

sealed private[data] trait ConstApplicative[C] 
  extends ConstApply[C] with Applicative[Const[C, *]] {
 implicit def C0: Monoid[C]

 def pure[A](x: A): Const[C, A] =
   Const.empty

 def ap[A, B](f: Const[C, A => B])(fa: Const[C, A]): Const[C, B] =
   f.retag[B].combine(fa.retag[B])	// retag means cast
}
```

This `Applicative` instance is lawful, but does look a bit useless.
Its `pure` function ignores its parameter `x`, and uses Const(C.empty) via the implicit Monoid[C].
And `ap` ignores the lifted function `A => B` altogether!

But, unlikely as it seems, this `Applicative` instance is useful, as shown in 
the [next article](https://leigh-perry.github.io/posts/2019-11-20-monoids-viatraverse.html)
in the series.
