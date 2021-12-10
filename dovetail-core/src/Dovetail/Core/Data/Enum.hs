{-# LANGUAGE BlockArguments      #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE ViewPatterns        #-}

module Dovetail.Core.Data.Enum where

import Control.Monad.IO.Class (MonadIO)
import Data.Char (chr, ord)
import Data.Foldable (fold)
import Dovetail
import Dovetail.Evaluate (builtIn)
import Language.PureScript qualified as P

env :: forall m. MonadIO m => Env m
env = do
  let _ModuleName = P.ModuleName "Data.Enum"

  fold
    [ -- toCharCode :: Char -> Int
      builtIn @m @(Char -> EvalT m Integer)
        _ModuleName "toCharCode"
        \c ->
          pure (fromIntegral (ord c))
      -- fromCharCode :: Int -> Char
    , builtIn @m @(Integer -> EvalT m Char)
        _ModuleName "fromCharCode"
        \i ->
          pure (chr (fromIntegral i))
    ]