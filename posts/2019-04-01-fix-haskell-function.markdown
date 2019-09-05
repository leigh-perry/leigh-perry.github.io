---
title: Deriving Haskell's fix function
---

The function `fix` is the essence of recursion.
It originates from lambda calculus and the [Y-combinator](https://en.wikipedia.org/wiki/Fixed-point_combinator) 
`λf.(λx.f(xx))(λx.f(xx))`, which reduces nicely to a function:
```
Y    = λf.(λx.f(xx))(λx.f(xx))
Y g  = (λf. (λx.f(xx)) (λx.f(xx))) g
     = (λx.g(xx)) (λx.g(xx))
     = g((λx.g(xx)) (λx.g(xx)))
     = g (Y g)
```

In Haskell, this is `fix g = g (fix g)`.
```
Prelude> fix g = g (fix g)
Prelude> :t fix
fix :: (t -> t) -> t
```

GHC's amazing type inference engine is able to determine that this is of type `(t -> t) -> t`, 
that is it can tell that `g` is a function.

Anyway, putting this to use in a recursive function.
Factorial is the canonical recursive function.
Written with explicit recursion, `fac` is:

```
Prelude> fac n = if (n < 3) then n else n * fac (n - 1)

Prelude> fac 6
720

Prelude> :t fac
fac :: (Ord t, Num t) => t -> t
```

To remove the explicit recursion, just replace the call to `fac` with a call to some function `f`
that now becomes an argument of the `fac` function.
```
Prelude> fac f n = if (n < 3) then n else n * f (n - 1)

Prelude> :t fac
fac :: (Ord t, Num t) => (t -> t) -> t -> t
```

But when you try and use it:
```
Prelude> fac fac 6

<interactive>:6:1: error:
    • Non type-variable argument in the constraint: Ord (t -> t)
      (Use FlexibleContexts to permit this)
    • When checking the inferred type
        it :: forall t.
              (Ord t, Ord (t -> t), Num t, Num (t -> t)) =>
              t -> t
```

The solution is to use the `fix` function we saw above:
```
Prelude> fixfac = fix fac
Prelude> :t fixfac
fixfac :: (Ord t, Num t) => t -> t

Prelude> :t fixfac 5
fixfac 5 :: (Ord t, Num t) => t

Prelude> fixfac 6
720
```
