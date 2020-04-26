---
title: Controlling magnolia implicit priorities in Scala 
---

I recently added [Magnolia](https://github.com/propensive/magnolia) based automated instance generation
to my [configuration library](https://leigh-perry.github.io/posts/2019-09-01-conduction.html).
Magnolia can save the boilerplate of describing your configuration descriptors, and is pretty convenient.
However, I didn't want to bake it into the base library `conduction-core`.
I wanted it to be an opt-in addition, called `conduction-magnolia`.

# The Magnolia-native way

If you bake Magnolia support right into the class you want to provide automatic derivations for, 
everything is easy.

```scala
trait Configured[F, T] ...

object Configured {

  /** Specific instances */
  implicit def configuredOption[F[_], A]: Configured[F, Option[A]] = ...

  /** Now Magnolia generation support */
  type Typeclass[T] = Configured[F, T]
  def combine[T](caseClass: CaseClass[Typeclass, T]): Typeclass[T] = ...
  def dispatch[T](sealedTrait: SealedTrait[Typeclass, T]): Typeclass[T] = ...
  implicit def gen[T]: Typeclass[T] = macro Magnolia.gen[T]

  :
}
``` 

Because the specific, hand-coded instances are baked into the `Configured` companion object,
there is a natural priority of implicits – there is a specific instances available, Magnolia is not
called upon to create an instance. For anything else, Magnolia's automatically generated instance
would be used. 

This is all via the magic of Scala implicits and their priority scheme.

# Opt-in automated Instances

Putting the Magnolia support in an external class:
```scala
object MagnoliaConfigSupport[F[_]: Applicative] {

  type Typeclass[T] = Configured[F, T]
  def combine[T](caseClass: CaseClass[Typeclass, T]): Typeclass[T] = ...
  def dispatch[T](sealedTrait: SealedTrait[Typeclass, T]): Typeclass[T] = ...
  implicit def gen[T]: Typeclass[T] = macro Magnolia.gen[T]

}
```
means that to use it, you need to `import MagnoliaConfigSupport._`, whereas previously, the implicit instances
were always available from the companion object. 
The unexpected downside of this is that the`MagnoliaConfigSupport` instances are always used.
In the example above, I have `configuredOption`, which provides a specialised implementation for `Option[A]`,
However, I found that tests were failing because my specialised implementation was not being used.
`import MagnoliaConfigSupport._` was able to synthesise an implicit instance because, internally, `Option`
is just another data structure. But the synthesised instance was not compatible with how I want `Option`
support to work.

## Analysis

Why does it work when baked in in the Magnolia-native way?
Because the Magnolia instances are in the same companion object as the specialised instance,
and the compile will always choose the specialisation.
But when they are separate, the compiler stops looking as soon as it can fulfill an instance, 
and never gets around to looking in the companion object. It surprised me too.

## Solution

To get around this, I had to establish a priority of specialised instances over Magnolia-generated.
I refactored `MagnoliaConfigSupport` to reassert the natural priority of things:

```scala
/** Implicit resolution for any F[_] with Applicative */
abstract class AutoConfigInstances[F[_]: Applicative] extends MagnoliaConfigSupport[F] {

  // Explicitly re-expose the companion object implicits at higher priority
  implicit def configuredA[F[_]: Monad, A: Conversion]: Configured[F, A] =
    Configured.configuredA

  implicit def configuredOption[F[_], A](implicit F: Functor[F], A: Configured[F, A]): Configured[F, Option[A]] =
    Configured.configuredOption

  implicit def configuredList[F[_], A](implicit F: Monad[F], A: Configured[F, A]): Configured[F, List[A]] =
    Configured.configuredList

  implicit def configuredEither[F[_], A, B](
    implicit F: Monad[F],
    A: Configured[F, A],
    B: Configured[F, B]
  ): Configured[F, Either[A, B]] =
    Configured.configuredEither

}

private[magnolia] abstract class MagnoliaConfigSupport[F[_]: Applicative] {

  type Typeclass[T] = Configured[F, T]
  def combine[T](caseClass: CaseClass[Typeclass, T]): Typeclass[T] = ...
  def dispatch[T](sealedTrait: SealedTrait[Typeclass, T]): Typeclass[T] = ...
  implicit def gen[T]: Typeclass[T] = macro Magnolia.gen[T]

}
```

Through sub-classing, this layers the specialised implementations *ahead in priority* of the Magnolia implementations.

I then added an object suitable for importing into client code.
```scala
object AutoConfigInstancesIO extends AutoConfigInstances[IO]
```

This way, via `import AutoConfigInstancesIO._`, a user gets well-behaved implicit resolution,
that resolves the same way as a Magnolia-native implementation would have.