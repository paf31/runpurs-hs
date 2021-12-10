{-# LANGUAGE BlockArguments      #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE ViewPatterns        #-}

module Dovetail.Core.Data.Eq where

import Control.Monad.IO.Class (MonadIO)
import Data.Foldable (fold)
import Data.Text (Text)
import Data.Vector (Vector)
import Data.Vector qualified as Vector
import Dovetail
import Dovetail.Evaluate (builtIn)

env :: forall m. MonadIO m => Env m
env = do
  let _ModuleName = ModuleName "Data.Eq"
  
      eqImpl :: Eq a => a -> a -> EvalT m Bool
      eqImpl x y = pure (x == y)

  fold
    [ -- eqBooleanImpl :: Boolean -> Boolean -> Boolean
      builtIn @m @(Bool -> Bool -> EvalT m Bool)
        _ModuleName "eqBooleanImpl"
        (eqImpl @Bool)
      -- eqIntImpl :: Int -> Int -> Boolean
    , builtIn @m @(Integer -> Integer -> EvalT m Bool)
        _ModuleName "eqIntImpl"
        (eqImpl @Integer)
      -- eqNumberImpl :: Number -> Number -> Boolean
    , builtIn @m @(Double -> Double -> EvalT m Bool)
        _ModuleName "eqNumberImpl"
        (eqImpl @Double)
      -- eqCharImpl :: Char -> Char -> Boolean
    , builtIn @m @(Char -> Char -> EvalT m Bool)
        _ModuleName "eqCharImpl"
        (eqImpl @Char)
      -- eqStringImpl :: String -> String -> Boolean
    , builtIn @m @(Text -> Text -> EvalT m Bool)
        _ModuleName "eqStringImpl"
        (eqImpl @Text)
      -- eqArrayImpl :: forall a. (a -> a -> Boolean) -> Array a -> Array a -> Boolean
    , builtIn @m @((Value m -> Value m -> EvalT m Bool) -> Vector (Value m) -> Vector (Value m) -> EvalT m Bool)
        _ModuleName "eqArrayImpl"
        \f xs ys -> 
          if Vector.length xs == Vector.length ys
            then Vector.and <$> Vector.zipWithM f xs ys
            else pure False
    ]
