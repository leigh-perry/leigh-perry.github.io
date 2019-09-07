---
title: Generating functions in Scalacheck
---

[Scalacheck](https://www.scalacheck.org/) properties are a great way to test your code.
In general, you use Scalacheck generators (`Gen`) to fabricate data that you use to test 
supposedly-invariant properties of your code.

Sometimes you even want to generate functions. Scalacheck also supports that. 
This article addresses how Scalacheck does that.  

# Gen monad

`Gen` is defined as a monad to allow composition of more complex generators from component generators.
Its essence is something like this:
```scala
  final case class Seed()

  abstract case class Gen[A](run: Seed => (A, Seed)) {
    def map[B](f: A => B): Gen[B]
    def flatMap[B](f: A => Gen[B]): Gen[B]
  }
```

A `Gen[A]` generates `A` values.

# Consuming values

To be able to implement a function, we need to be able to consume values as well as producing them.
That is where `Cogen[A]` comes in.

A `Cogen[A]` consumes `A` values.

## Cogen

Cogen's essence is something like this:
```scala
  abstract case class Cogen[A](perturb: (A, Seed) => Seed) {
    def contramap[S](f: S => A): Cogen[S]
  }
```

`Cogen` is really just `Gen` with the arrows reversed, which is a pretty standard
trick from category theory – reverse the arrows and stick "Co" in front of the name.
Like with monad and comonad.
 
Also, `Cogen` is a contravariant functor, hence `contramap`.
This means if you have a `Cogen` for any type `A`, you can also get a `Cogen` for any type `S`
so long as you can convert a `S` into an `A`. 
That is `contramap`'s signature is trying to say.

Scalacheck provides some `Cogen` instances for us, defined in exactly this way:
```scala
  object Cogen {
    def apply[A](implicit F: Cogen[A]): Cogen[A] = F
  }

  implicit lazy val cogenLong: Cogen[Long] = ...

  implicit lazy val cogenBoolean: Cogen[Boolean] =
    Cogen[Long]
      .contramap(b => if (b) 1L else 0L)

  implicit lazy val cogenByte: Cogen[Byte] =
    Cogen[Long]
      .contramap(_.toLong)

  implicit lazy val cogenShort: Cogen[Short] =
    Cogen[Long]
      .contramap(_.toLong)

  // :  you get the idea
```

# Generating a function

Armed with the means of generating and consuming values, we should be able to create a function.
Consider this starting point:
```scala
  def combine(seed0: Seed, cogen: Cogen[Long], gen: Gen[Boolean], n: Long): Boolean = {
    val seed1 = cogen.perturb(n, seed0)
    gen.run(seed1)._1
  }
```

It combines a `Gen` and a `Cogen`, converting a `Long` value `n` to a `Boolean` result.
If we convert the `n` parameter to curried form, we get the equivalent code:  
```scala
  def combineCurried(seed0: Seed, cogen: Cogen[Long], gen: Gen[Boolean]): Long => Boolean =
    n => {
      val seed1 = cogen.perturb(n, seed0)
      gen.run(seed1)._1
    }
```

But now this function returns a function – one from `Long` to `Boolean`.

Making this polymorphic:
```scala
  def createFunction[A, B](seed0: Seed, cogen: Cogen[A], gen: Gen[B]): A => B =
    n => {
      val seed1 = cogen.perturb(n, seed0)
      gen.run(seed1)._1
    }
```

Scalacheck internally uses a more baroque version of this mechanism to satisfy
a generator for a function, ie `Gen[A => B]`, when one is summoned like this:
```scala
  val intPredicate: Gen[Int => Boolean] =
    arbitrary[Int => Boolean] // ie Gen.function1(arbitrary[Boolean])(implicitly[Cogen[Int]])
```
