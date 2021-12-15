{-# LANGUAGE BlockArguments      #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE ViewPatterns        #-}

module Dovetail.Core.Control.Extend where

import Data.Vector (Vector)
import Data.Vector qualified as Vector
import Dovetail
import Dovetail.Evaluate (builtIn)

env :: forall ctx. Env ctx
env = do
  let _ModuleName = ModuleName "Control.Extend"

  -- arrayExtend :: forall a b. (Array a -> b) -> Array a -> Array b
  builtIn @ctx @((Vector (Value ctx) -> Eval ctx (Value ctx)) -> Vector (Value ctx) -> Eval ctx (Vector (Value ctx)))
    _ModuleName "arrayExtend"
    \f xs ->
      Vector.generateM (Vector.length xs) \i ->
        f (Vector.drop i xs)