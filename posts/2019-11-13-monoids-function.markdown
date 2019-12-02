---
title: Function Monoids 
---

In [this article](https://leigh-perry.github.io/posts/2019-10-25-monoids-1.html)
I talked about how tuple monoids.

This time it is monoids for functions. 

# Inductive Monoid for functions

If a type `B` has a `Monoid` instance, then so does any function `A => B`.
When combining, the `Semigroup` instance gathers the output of two functions
and combines the values using the underlying `Monoid[B]`.
```scala
trait Function1Semigroup[A, B] extends Semigroup[A => B] {
  implicit def B: Semigroup[B]
 
  override def combine(x: A => B, y: A => B): A => B =
    (a: A) => B.combine(x(a), y(a))
}

trait Function1Monoid[A, B]
  extends Function1Semigroup[A, B] with Monoid[A => B] {
  implicit def B: Monoid[B]
 
  val empty: A => B =
    (_: A) => B.empty
}
```

# Example

```scala
  val int2IntFunctions: List[Int => Int] =
    List(
      (i: Int) => i * i,
      (i: Int) => i * 5,
      (i: Int) => i + 6
    )
  (0 to 10).foreach {
    i =>
      val total: Int => Int = int2IntFunctions.foldMap(identity)
      println(s"$i => ${total(i)}")
  }
```

> Note: this code would ideally be written using `Foldable.fold`, ie
> `int2IntFunctions.foldMap`, but `List` has a `fold` method that doesn't
> know about monoids. Instead, `int2IntFunctions.foldMap(identity)` 
> is equivalent to `int2IntFunctions.fold`.

Output is
```scala
    0 => 6
    1 => 13
    2 => 22
    3 => 33
    4 => 46
    5 => 61
    6 => 78
    7 => 97
    8 => 118
    9 => 141
    10 => 166
```

The function monoid combines the three functions in `int2IntFunctions`, 
and returning a function that will apply each of those functions in turn
to an input value, and combine the three outputs using `Monoid[Int]`, which sums them.
For example, value `4` yields `16 + 20 + 10`, ie `46`.

# Example variant

This time, each function maps to a `Max` rather than `Int`.
`Monoid[Max]` accumulates the maximum value, and is defined as
```scala
  final case class Max(i: Int) extends AnyVal

  implicit val intMaxMonoid =
    new Monoid[Max] {
      override def empty: Max = Max(Int.MinValue)
      override def combine(x: Max, y: Max): Max = if (x.i > y.i) x else y
    }
```

This time
```scala
  val int2MaxFunctions: List[Int => Max] =
    List(
      (i: Int) => Max(i * i),
      (i: Int) => Max(i * 5),
      (i: Int) => Max(i + 6)
    )
  (0 to 10).foreach {
    i =>
      val bestf: Int => Max = int2MaxFunctions.foldMap(identity)
      val best: Max = bestf(i)
      println(s"$i => ${best}")
  }
```
yields
```scala
    0 => Max(6)
    1 => Max(7)
    2 => Max(10)
    3 => Max(15)
    4 => Max(20)
    5 => Max(25)
    6 => Max(36)
    7 => Max(49)
    8 => Max(64)
    9 => Max(81)
    10 => Max(100)
```

Behaviour is similar to the previous, however, this time the monoid
just selects the largest value returned by any of the functions.
From input `0` to `1`, the equation `i + 6` dominates. 
From `2` to `5`, `i * 5` takes over.
Finally, from `6` onwards, `i * i` wins.

# Uses

This kind of behaviour can be used to check a collection of predicates,
accumulating their boolean results using a `AllTrue` or `AnyTrue` monoid.
(These are called `All` and `Any` in Haskell).

> Note: these monoidal predicates do not provide short-circuiting behaviour.
> They apply all predicates even if the result has already been decided, such
> as an `AllTrue` accumulation that has already encountered a `false`.

Despite the short-circuiting limitation, such monoidal accumulations of 
functions can provide a simple and expressive way of dynamically configuring 
application runtime behaviour.