---
title: Monoids for single pass aggregations
---

Monoids are awesome.
They let you perform an aggregation across some kind of collection (actually across an _effect_).
But even better, they let you perform multiple aggregations at the same time in one pass.

# Background

In Scala, the `Monoid` typeclass has the following interface.
```scala
trait Semigroup[A] {
  def combine(x: A, y: A): A  // |+|
}

trait Monoid[A] extends Semigroup[A] {
  def empty: A
}
```

They are primarily used via the `Foldable` typeclass abstraction.
```scala
trait Foldable[F[_]] {
  def fold[A](fa: F[A])(implicit A: Monoid[A]): A

  def foldMap[A, B](fa: F[A])(f: A => B)(implicit B: Monoid[B]): B
}
```

# foldMap

The `foldMap` method provides map-reduce functionality.
For each element in the `Foldable`, it maps the element via function `f`, and then combines all the mapped
values using the implicit `Monoid[B]`. For example
```scala
    val phrases =
      List("Some", "Phrases", "My hovercraft is full of eels", 
        "I am no longer infected", "A", "I", "A", "I")

    val chars = phrases.foldMap(_.length)
    println(chars)
``` 
prints
```bash
67
```

This code folds over some phrases from every day life, maps each to its length, then sums up those lengths.
This is implicitly using the `Monoid` instance for `Int` (the length of a string).

## Monoid for Int

In Cats, the `Monoid[Int]` instance is implemented as
```scala
class IntGroup extends CommutativeGroup[Int] {
  def combine(x: Int, y: Int): Int = x + y
  def empty: Int = 0
  :
}
```

The `empty` value is 0, and `Semigroup`'s `combine` functionality is to just add values.
This is not the only possible implementation.
It is just as valid to multiply values, in which case the empty value would be `1`.
Because of this ambiguity, Haskell does not provide a `Monoid Int` instance.
Instead you need to use a newtype over Int, for example `Sum` or `Product`, making your intentions clear.
Cats seems to have erred on the side of ease of use, but you do have to know what it does under the covers. 

# Multiple aggregations

Anyway, back to the main point.

Monoids compose in a number of ways, including by product.
This means that, if I have a `Monoid` for types `A` and `B`, I can form a `Monoid` for `(A, B)`.
Similarly, if I also have a `Monoid` for type `C`, I can form a `Monoid` for `(A, B, C)`.
Etc.

Therefore, if I foldMap via a tuple of required aggregations, such as
```scala
    val (phrases, chars) = phrases.foldMap(s => (1, s.length))
    println(phrases)
    println(chars)
```
the composite for `Monoid[Int, Int]` will yield two aggregated results `8` and `67`.

And it does it in a single pass.
