--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}

import           Data.Monoid (mappend)
import           Hakyll

--------------------------------------------------------------------------------
main :: IO ()
main =
  hakyll $ do
    match "images/*" $ do
      route idRoute
      compile copyFileCompiler
    match "css/*" $ do
      route idRoute
      compile compressCssCompiler
    match (fromList ["about.rst" ]) $ do  -- , "contact.markdown"
      route $ setExtension "html"
      compile $ pandocCompiler >>= loadAndApplyTemplate "templates/default.html" defaultContext >>= relativizeUrls
    match "posts/*" $ do
      route $ setExtension "html"
      compile $
        pandocCompiler >>= loadAndApplyTemplate "templates/post.html" postCtx >>= saveSnapshot "content" >>=
        loadAndApplyTemplate "templates/default.html" postCtx >>=
        relativizeUrls
    create ["archive.html"] $ do
      route idRoute
      compile $ do
        posts <- recentFirst =<< loadAll "posts/*"
        let archiveCtx =
              listField "posts" postCtx (return posts) `mappend` constField "title" "Archives" `mappend` defaultContext
        makeItem "" >>= loadAndApplyTemplate "templates/archive.html" archiveCtx >>=
          loadAndApplyTemplate "templates/default.html" archiveCtx >>=
          relativizeUrls
    match "index.html" $ do
      route idRoute
      compile $ do
        posts <- recentFirst =<< loadAll "posts/*"
        let indexCtx =
              listField "posts" postCtx (return posts) `mappend` constField "title" "Home" `mappend` defaultContext
        getResourceBody >>= applyAsTemplate indexCtx >>= loadAndApplyTemplate "templates/default.html" indexCtx >>=
          relativizeUrls
    match "templates/*" $ compile templateCompiler
    feed "atom.xml" renderAtom
    feed "feed.xml" renderRss

--------------------------------------------------------------------------------
postCtx :: Context String
postCtx = dateField "date" "%B %e, %Y" `mappend` defaultContext

myFeedConfiguration :: FeedConfiguration
myFeedConfiguration =
  FeedConfiguration
    { feedTitle = "Ephemera - Leigh Perry's Blog"
    , feedDescription = "Ephema is a software engineering blog by Leigh Perry"
    , feedAuthorName = "Leigh Perry"
    , feedAuthorEmail = "lperry.breakpoint@gmail.com"
    , feedRoot = "https://leigh-perry.github.io"
    }

feed :: Identifier -> (FeedConfiguration -> Context String -> [Item String] -> Compiler (Item String)) -> Rules ()
feed filename renderer =
  create [filename] $ do
    route idRoute
    compile $ do
      let feedCtx = postCtx `mappend` constField "description" "Another post from Leigh"
      posts <- fmap (take 10) . recentFirst =<< loadAll "posts/*"
      renderer myFeedConfiguration feedCtx posts
