---
title: Monoidal aggregation via Traverse 
---

[Earlier](https://leigh-perry.github.io/posts/2019-11-16-monoids-applicative.html),
I talked about the relationship between `Applicative` and `Monoid` typeclasses.

It is time to work out what the `Applicative` instance for a `Monoid` is good for. 

# Real world programming

For a programming language, it is not enough to be able to just write Hello World.
You have to write word count too.

Let's do that.

# wc via Monoid

Implementing character count and line count are easy, since the accumulations are stateless.
```scala
    val chars: List[Char] =
      """Tonight's the night
        |I shall be talking about of flu
        |the   subject   of
        |word association football
        |""".stripMargin.toList
  
    val (ls, cs) = chars.foldMap(c => (if (c == '\n') 1 else 0, 1))
    println(s"$ls $cs")
```
outputs `4 97`.

Depending on whether it is counting lines or characters, 
this implementation maps each character to `0` or `1`.
The `Monoid[Int]` instance then adds them up. (Ignore the fact that the string may not end in a newline,
so line count could be out by one.) 

Implementing the count of words is not so easy, since an implementation needs
to track transitions from whitespace to non-whitespace.
It needs state.

## State via custom Monoid

Tracking state can be implemented using a custom `Monoid`
```scala
final case class Counts(lines: Int, inWord: Boolean, words: Int, chars: Int)

object Counts {
  implicit val monoidInstance =
    new Monoid[Counts] {
      override def empty: Counts =
        Counts(0, false, 0, 0)
      override def combine(x: Counts, y: Counts): Counts =
        Counts(
          x.lines + y.lines,
          y.inWord,
          x.words + y.words + (if (!x.inWord && y.inWord) 1 else 0),
          x.chars + y.chars
        )
    }
}

  val counts =
     chars.foldMap(
       c =>
         Counts(
           lines = if (c == '\n') 1 else 0,
           inWord = c != ' ' && c != '\n',
           words = 0,
           chars = 1
         )
     )
```
that tracks whitespace transitions when counting words.

## State via Applicative

An interesting alternative is to lift the accumulating `Monoid`s into their
`Const`-based `Applicative` [instance](https://leigh-perry.github.io/posts/2019-11-16-monoids-applicative.html),
and use `Traverse` to control the accumulation.

This function
```scala
  def countWords[A](c: Char): Nested[State[Boolean, *], Const[Int, *], A] =
    Nested[State[Boolean, *], Const[Int, *], A] {
      // F: State[Boolean, *] ; G: Const[Int, *]
      for {
        before <- State.get[Boolean]
        after = !c.isWhitespace
        _ <- State.set[Boolean](after)
      } yield {
        Const.of[A](if (!before && after) 1 else 0)
      }
    }
```
maps each character to an `Applicative` instance that uses Cats `Nested` to wrap
a `State` monad instance.
The `State`'s _state_ tracks whether currently in whitespace (ie `Boolean`),
and its yielded value is `Const[Int, *]`.
This is the integer word count, wrapped in `Const` in order to provide an `Applicative`
instance.
Having a `Monad` instance, `State` also by definition has an `Applicative` instance.
`Nested` is Cats machinery for composing `State` and `Applicative` to make a 
composite `Applicative`.

Armed with this word-counting `Applicative`, typeclass `Traverse`'s `traverse` method
can be used to apply it to a collection of characters.

```scala
    val result : Nested[State[Boolean, *], Const[Int, *], Unit] =
      input.traverse_ {
        c =>
          countWords[Unit](c)
      }

    result.value.runA(false).value.getConst

    val chars: List[Char] =
      """Tonight's the night
        |I shall be talking about of flu
        |the   subject   of
        |word association football
        |""".stripMargin.toList
  
    println(run(chars))
```  
yields `16`.

A bit clunky, especially `result.value.runA(false).value.getConst` to unpeel the
`Nested` then `State` then `Const` to get at the underlying value accumulated
by the wrapped `Monoid[Int`.
But it works, demonstrating that monoids can be invoked indirectly when wrapped
by an `Applicative` instance.

> Note: the `traverse_` method is used here since the actual result of the traversal
> is not used.
> The full return type would be `Nested[State[Boolean, *], Const[Int, *], List[Unit]]`,
> and that `List[Unit]` is not very useful.
> Instead, `traverse_` replaces it with `Unit`.

### Putting it together

In reality, it is a requirement to also accumulate the easy line and character counts.
To do this in one pass, we need a composite `Applicative` that counts lines, words, and characters.

This is a mechanical exercise utilising another piece of Cats machinery called `Tuple2K`.
This is a tuple acting at kind `* -> *`, but the executive summary is that
it provides a composite `Applicative` for a pair of `Applicative`s.
In this case, we need a 3-part tuple.
There is no such thing, but it can be emulating by nesting `Tuple2K`s: 
`Tuple2K[Tuple2K[A, B], C]`.

The full horror, with Scala type inference assistance liberally applied, follows
```scala
    def countChars[A](c: Char): Const[Int, A] =
      Const.of(1)
  
    def countLines[A](c: Char): Const[Int, A] =
      Const.of[A](if (c == '\n') 1 else 0)
  
    def run(input: List[Char]): (Int, Int, Int) = {
      val Tuple2K(
        Tuple2K(chars: Const[Int, Unit], lines: Const[Int, Unit]),
        words: Nested[State[Boolean, *], Const[Int, *], Unit]
      ) =
        input.traverse_ {
          c =>
            val charsAndLines: Tuple2K[Const[Int, *], Const[Int, *], Unit] =
              Tuple2K[Const[Int, *], Const[Int, *], Unit](
                countChars[Unit](c),
                countLines[Unit](c)
              )
  
            Tuple2K[Tuple2K[Const[Int, *], Const[Int, *], *], Nested[
              State[Boolean, *],
              Const[Int, *],
              *
            ], Unit](
              charsAndLines,
              countWords[Unit](c)
            )
        }
  
      (lines.getConst, words.value.runA(false).value.getConst, chars.getConst)
    }

    println(run(chars))
```

# Conclusion

Would you write word count this way?
Probably not.
But it does illustrate how a reasonable understanding of typeclass derivation 
and some lateral thinking can provide alternative solutions, perhaps even
a solution where no straightforward approach was feasible.

