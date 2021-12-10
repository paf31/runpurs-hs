{-# LANGUAGE BlockArguments      #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE ViewPatterns        #-}

module Dovetail.Core.Effect.Unsafe where

import Control.Monad.IO.Class (MonadIO)
import Dovetail
import Dovetail.Evaluate (builtIn)

env :: forall m. MonadIO m => Env m
env = do
  let _ModuleName = ModuleName "Effect.Unsafe"

  -- unsafePerformEffect :: forall a. Effect a -> a
  builtIn @m @((Value m -> EvalT m (Value m)) -> EvalT m (Value m))
    _ModuleName "unsafePerformEffect"
    \f -> f (Object mempty)