---
title: Abstracting effects MTL-style
---

Naively implementating an application in Haskell might use `error` to throw exceptions under, well, exceptional conditions,
and use the `IO` monad for all functions that need to actually do anything that might be noticable by the outside world.
This can lead to overly concrete implementations that are tricky to test.

# Background

Imagine you have a function that reads a CSV file and parses it. The function's signature might be:
```haskell
readAndParse :: FilePath -> IO [Entry]
```

This function signature has two shortcomings.

1. It doesn't advertise what errors might be encountered.
1. It executes in `IO`, which means it can have any side-effect that it wants, not just
limited to those associated with reading and parsing a CSV file. It could also launch the proverbial missiles, to recycle a 
functional programming trope.

# Analysis

Recently I wrote a quick [Haskell program](https://github.com/leigh-perry/bankcheck) to analyse credit card transactions, 
which are arriving at an accelerating rate in an increasingly cashless era.
To get started, I wrote the parsing code in exactly that naive style.
```haskell
analyseFile :: String -> IO (V.Vector Entry)
analyseFile filepath = do
  csvData <- BL.readFile filepath
  let d = Csv.decodeByName csvData :: Either String (Csv.Header, V.Vector Entry)
  return $
    case d of
      Left err     -> error err -- TODO ExceptT
      Right (_, v) -> v
``` 

Its purpose was simply to prove that the CSV parsing library would do what I wanted.
The `TODO` comment expressed the temporary embarrassment of throwing an exception, and
once I was happy with the CSV handling, along with some other refactoring, I quickly upgraded to
returning `ExceptT`.

# Advertising potential errors

```haskell
parseEntryFile :: String -> ExceptT AnalyserError IO [CsvEntry]
parseEntryFile filepath = do
  csvData <- liftIO $ BL.readFile filepath
  let d = Csv.decodeByName csvData :: Either String (Csv.Header, V.Vector CsvEntry)
  except $ bimap ParseEntryError (toList . snd) d
```

`ExceptT` is Haskell's equivalent of Scala's `EitherT` (well really, it is the other way around).
It is essentially an `Either` wrapped in `IO`. In this case, the left (error) side of
the `Either` contains a consolidated error ADT `AnalyserError`. In the last line of `parseEntryFile`,
the bifunctor `bimap` operation converts any error from the parsing library into a `ParseEntryError`, or otherwise
it converts the `Either`'s successful right value in a manner similar to the original `Right (_, v) -> v`.

This has solved the first shortcoming.
The function no longer unceremoneously leaves the building on error.
It also proclaims the nature of any errors that will now be explicitly returned from the function.

But it doesn't do anything about the second point.

# Abstracting Effects

Using monad stacks like `ExceptT` has a downside.
You end up with some deeply unattractive function signatures, returning `ExceptT AnalyserError IO a`
instead of just `a`.
The standard solution to this is to abstract the returned effect (`ExceptT` in this case) by declaring
required capabilities instead. This is called *MTL-style*.
MTL stands for monad transformer library, but the name is anachronistic and doesn't fully apply
to the contemporary meaning of the MTL acronym.

Anyway, there are two effects we need to cater for.

- `ExceptT` allows for returning error indications, eg `AnalyserError`, in this case.
- `IO` allows for side-effects, eg reading a file.

The first is modelled via `MonadError`, and the second via `MonadIO`.

Refactoring the application, it becomes:
```haskell
parseEntryFile :: (MonadError AnalyserError m, MonadIO m) => String -> m [CsvEntry]
parseEntryFile filepath = do
  csvData <- liftIO $ BL.readFile filepath
  let d = Csv.decodeByName csvData :: Either String (Csv.Header, V.Vector CsvEntry)
  liftEither $ bimap ParseEntryError (toList . snd) d
```
This simplifies the return type from `ExceptT AnalyserError IO [CsvEntry]` to `m [CsvEntry]`.
In other words, it returns some monad wrapping `[CsvEntry]`.
This simplification comes at some expense though – we have now gained the boilerplatey
typeclass constraints `(MonadError AnalyserError m, MonadIO m) =>`. 
However, the impact on the function body, was minimal, swapping `except` for the 
[typeclass equivalent](https://hackage.haskell.org/package/mtl-2.2.2/docs/Control-Monad-Error-Class.html#v:liftEither) `liftEither`.

This implementation gives the caller more flexibility.
It allows them to use any effect that has an instance of `MonadError`,
which can be useful in scenarios such as unit testing.

# A hangover

There is one small problem.

We are using `MonadIO`, which is the typeclass equivalent
of `IO`, which means we can still launch those missiles.
`MonadIO` gives the appearance of effect abstraction, but it is a wolf in sheep's clothing.

A good design principle to live by is the *principle of least power*.
Functions should be given the minimal level of power that they need.
But instead, with `MonadIO`, they are being given the power to do anything at all. 
Semantically, `MonadIO` is ambiguous; it has only one method `liftIO`, which doesn't tell 
us anything about what it might do.

## Granting less power

The MTL solution (also known as *finally tagless*) is to define one or more focused 
typeclasses that declare exactly the semantic intent.
```haskell
class FileOps m where
  readBinFile :: FilePath -> m BL.ByteString
```

It is a minor change to the function to use this typeclass.
```haskell
parseEntryFile :: (MonadError AnalyserError m, FileOps m) => String -> m [CsvEntry]
parseEntryFile filepath = do
  csvData <- readBinFile filepath
  let d = Csv.decodeByName csvData :: Either String (Csv.Header, V.Vector CsvEntry)
  liftEither $ bimap ParseEntryError (toList . snd) d
```  

The function now expresses a requirement for the `FileOps` capability, and that capability's 
one function `readBinFile` is employed via `readBinFile filepath`.
This approach tells callers of `parseEntryFile` that they need to provide *a means of
reading a byte-string file*.
It doesn't say how it is expected to be done.
This clearly gives an improvement in testability, allowing stub implementations to be used in unit test suites.

## Fulfilling the capability

All that remains now is to provide the promised `FileOps` in the caller.
This is done by providing a typeclass instance for `FileOps` that is specialised 
for `ExceptT` and `IO`, which matches the original pre-MTL implementation of the application's `main`.
```haskell
instance FileOps (ExceptT AnalyserError IO) where
  readBinFile a = lift $ BL.readFile a
```

A slight Haskell complexity arises at this point.
Haskell only allows typeclass instances for fully-saturated types, designated by kind `*`.
However, `ExceptT AnalyserError IO` is partial application of `ExceptT e m a`, ie only `e` and `m` are specified, leaving a type hole for `a`.
This is designated by kind `* -> *`.

To get around this compiler limitation, you need to enable `{-# LANGUAGE FlexibleInstances #-}`.
Haskell then accepts the typeclass instance for the partially-saturated `ExceptT AnalyserError IO`.

Now to actually write some tests to exploit this new-found flexibility.
