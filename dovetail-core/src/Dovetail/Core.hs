{-# LANGUAGE BlockArguments      #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE ViewPatterns        #-}

module Dovetail.Core where

import Control.Monad (unless)  
import Control.Monad.Error.Class (catchError)
import Control.Monad.Fix (MonadFix)
import Control.Monad.IO.Class (MonadIO(..))
import Data.Foldable (fold, traverse_)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Data.Typeable (Typeable)
import Data.Vector (Vector)
import Data.Vector qualified as Vector
import Dovetail
import Dovetail.Evaluate (ForeignType(..), builtIn)
import Language.PureScript.Names qualified as P
import System.FilePath ((</>))

import Dovetail.Core.Control.Apply qualified as Control.Apply
import Dovetail.Core.Control.Bind qualified as Control.Bind
import Dovetail.Core.Control.Extend qualified as Control.Extend
import Dovetail.Core.Control.Monad.ST.Internal qualified as Control.Monad.ST.Internal
import Dovetail.Core.Data.Bounded qualified as Data.Bounded
import Dovetail.Core.Data.Eq qualified as Data.Eq
import Dovetail.Core.Data.EuclideanRing qualified as Data.EuclideanRing
import Dovetail.Core.Data.Foldable qualified as Data.Foldable
import Dovetail.Core.Data.Function.Uncurried qualified as Data.Function.Uncurried
import Dovetail.Core.Data.Functor qualified as Data.Functor
import Dovetail.Core.Data.FunctorWithIndex qualified as Data.FunctorWithIndex
import Dovetail.Core.Data.HeytingAlgebra qualified as Data.HeytingAlgebra
import Dovetail.Core.Data.Int qualified as Data.Int
import Dovetail.Core.Data.Int.Bits qualified as Data.Int.Bits
import Dovetail.Core.Data.Number qualified as Data.Number
import Dovetail.Core.Data.Number.Format qualified as Data.Number.Format
import Dovetail.Core.Data.Ord qualified as Data.Ord
import Dovetail.Core.Data.Ring qualified as Data.Ring
import Dovetail.Core.Data.Semigroup qualified as Data.Semigroup
import Dovetail.Core.Data.Semiring qualified as Data.Semiring
import Dovetail.Core.Data.Show qualified as Data.Show
import Dovetail.Core.Data.Show.Generic qualified as Data.Show.Generic
import Dovetail.Core.Data.String.CodeUnits qualified as Data.String.CodeUnits
import Dovetail.Core.Data.String.Common qualified as Data.String.Common
import Dovetail.Core.Data.String.Regex qualified as Data.String.Regex
import Dovetail.Core.Data.String.Unsafe qualified as Data.String.Unsafe
import Dovetail.Core.Data.Symbol qualified as Data.Symbol
import Dovetail.Core.Data.Unit qualified as Data.Unit
import Dovetail.Core.Effect qualified as Effect
import Dovetail.Core.Effect.Console qualified as Effect.Console
import Dovetail.Core.Effect.Exception qualified as Effect.Exception
import Dovetail.Core.Effect.Random qualified as Effect.Random
import Dovetail.Core.Effect.Ref qualified as Effect.Ref
import Dovetail.Core.Effect.Uncurried qualified as Effect.Uncurried
import Dovetail.Core.Effect.Unsafe qualified as Effect.Unsafe
import Dovetail.Core.Math qualified as Math
import Dovetail.Core.Partial qualified as Partial
import Dovetail.Core.Partial.Unsafe qualified as Partial.Unsafe
import Dovetail.Core.Record.Builder qualified as Record.Builder
import Dovetail.Core.Record.Unsafe qualified as Record.Unsafe
import Dovetail.Core.Record.Unsafe.Union qualified as Record.Unsafe.Union
import Dovetail.Core.Test.Assert qualified as Test.Assert
import Dovetail.Core.Unsafe.Coerce qualified as Unsafe.Coerce
  
core :: forall m. (MonadFix m, MonadIO m, Typeable m) => FilePath -> InterpretT m ()
core sourceFiles = do
    loadEnv env
    traverse_ buildOne modules
  where
    buildOne fileName = do
      liftIO . putStrLn $ fileName
      moduleText <- liftIO . Text.readFile $ toPath fileName
      build moduleText
    
    toPath fileName = sourceFiles </> fileName
    
    modules =
      [ "unsafe-coerce/v5.0.0/src/Unsafe/Coerce.purs"
      
      , "safe-coerce/v1.0.0/src/Safe/Coerce.purs"
      
      , "type-equality/v4.0.0/src/Type/Equality.purs"
      
      , "prelude/v5.0.1/src/Type/Proxy.purs"
      , "prelude/v5.0.1/src/Type/Data/RowList.purs"
      , "prelude/v5.0.1/src/Type/Data/Row.purs"
      , "prelude/v5.0.1/src/Record/Unsafe.purs"
      , "prelude/v5.0.1/src/Data/NaturalTransformation.purs"
      , "prelude/v5.0.1/src/Data/Boolean.purs"
      , "prelude/v5.0.1/src/Control/Semigroupoid.purs"
      , "prelude/v5.0.1/src/Data/Symbol.purs"
      , "prelude/v5.0.1/src/Control/Category.purs"
      , "prelude/v5.0.1/src/Data/Show.purs"
      , "prelude/v5.0.1/src/Data/Unit.purs"
      , "prelude/v5.0.1/src/Data/Void.purs"
      , "prelude/v5.0.1/src/Data/HeytingAlgebra.purs"
      , "prelude/v5.0.1/src/Data/Semiring.purs"
      , "prelude/v5.0.1/src/Data/Semigroup.purs"
      , "prelude/v5.0.1/src/Data/Generic/Rep.purs"
      , "prelude/v5.0.1/src/Data/Ring.purs"
      , "prelude/v5.0.1/src/Data/BooleanAlgebra.purs"
      , "prelude/v5.0.1/src/Data/Eq.purs"
      , "prelude/v5.0.1/src/Data/CommutativeRing.purs"
      , "prelude/v5.0.1/src/Data/Ordering.purs"
      , "prelude/v5.0.1/src/Data/EuclideanRing.purs"
      , "prelude/v5.0.1/src/Data/Ord.purs"
      , "prelude/v5.0.1/src/Data/DivisionRing.purs"
      , "prelude/v5.0.1/src/Data/Field.purs"
      , "prelude/v5.0.1/src/Data/Monoid.purs"
      , "prelude/v5.0.1/src/Data/Function.purs"
      , "prelude/v5.0.1/src/Data/Bounded.purs"
      , "prelude/v5.0.1/src/Data/Functor.purs"
      , "prelude/v5.0.1/src/Control/Apply.purs"
      , "prelude/v5.0.1/src/Data/Monoid/Generic.purs"
      , "prelude/v5.0.1/src/Data/Bounded/Generic.purs"
      , "prelude/v5.0.1/src/Control/Applicative.purs"
      , "prelude/v5.0.1/src/Control/Bind.purs"
      , "prelude/v5.0.1/src/Control/Monad.purs"
      , "prelude/v5.0.1/src/Prelude.purs"
      , "prelude/v5.0.1/src/Data/Semiring/Generic.purs"
      , "prelude/v5.0.1/src/Data/Monoid/Additive.purs"
      , "prelude/v5.0.1/src/Data/Monoid/Dual.purs"
      , "prelude/v5.0.1/src/Data/Monoid/Multiplicative.purs"
      , "prelude/v5.0.1/src/Data/Ord/Generic.purs"
      , "prelude/v5.0.1/src/Data/HeytingAlgebra/Generic.purs"
      , "prelude/v5.0.1/src/Data/Ring/Generic.purs"
      , "prelude/v5.0.1/src/Data/Show/Generic.purs"
      , "prelude/v5.0.1/src/Data/Monoid/Conj.purs"
      , "prelude/v5.0.1/src/Data/Semigroup/Generic.purs"
      , "prelude/v5.0.1/src/Data/Semigroup/First.purs"
      , "prelude/v5.0.1/src/Data/Semigroup/Last.purs"
      , "prelude/v5.0.1/src/Data/Eq/Generic.purs"
      , "prelude/v5.0.1/src/Data/Monoid/Disj.purs"
      , "prelude/v5.0.1/src/Data/Monoid/Endo.purs"
      
      , "typelevel-prelude/v6.0.0/src/Type/Function.purs"
      , "typelevel-prelude/v6.0.0/src/Type/Row.purs"
      , "typelevel-prelude/v6.0.0/src/Type/Data/Boolean.purs"
      , "typelevel-prelude/v6.0.0/src/Type/Data/Ordering.purs"
      , "typelevel-prelude/v6.0.0/src/Type/Data/Symbol.purs"
      , "typelevel-prelude/v6.0.0/src/Type/RowList.purs"
      , "typelevel-prelude/v6.0.0/src/Type/Prelude.purs"
      , "typelevel-prelude/v6.0.0/src/Type/Row/Homogeneous.purs"
      
      , "partial/v3.0.0/src/Partial.purs"
      , "partial/v3.0.0/src/Partial/Unsafe.purs"
      
      , "math/v3.0.0/src/Math.purs"
      
      , "newtype/v4.0.0/src/Data/Newtype.purs"
      
      , "control/v5.0.0/src/Control/Lazy.purs"
      , "control/v5.0.0/src/Control/Extend.purs"
      , "control/v5.0.0/src/Control/Alt.purs"
      , "control/v5.0.0/src/Control/Plus.purs"
      , "control/v5.0.0/src/Control/Comonad.purs"
      , "control/v5.0.0/src/Control/Alternative.purs"
      , "control/v5.0.0/src/Control/MonadZero.purs"
      , "control/v5.0.0/src/Control/MonadPlus.purs"
      , "control/v5.0.0/src/Data/Monoid/Alternate.purs"
      
      , "foldable-traversable/v5.0.1/src/Data/Traversable/Accum.purs"
      , "strings/v5.0.0/src/Data/String/Unsafe.purs"
      
      , "integers/v5.0.0/src/Data/Int/Bits.purs"
      
      , "exists/v5.1.0/src/Data/Exists.purs"
      
      , "functions/v5.0.0/src/Data/Function/Uncurried.purs"
      
      , "record/v3.0.0/src/Record/Unsafe/Union.purs"
      
      , "transformers/v5.1.0/src/Control/Comonad/Trans/Class.purs"
      
      , "effect/v3.0.0/src/Effect.purs"
      , "record/v3.0.0/src/Record/Builder.purs"
      , "transformers/v5.1.0/src/Control/Monad/Cont/Class.purs"
      , "gen/v3.0.0/src/Control/Monad/Gen/Class.purs"
      
      , "transformers/v5.1.0/src/Control/Monad/Trans/Class.purs"
      , "foldable-traversable/v5.0.1/src/Data/Traversable/Accum/Internal.purs"
      
      , "record/v3.0.0/src/Record.purs"
      
      , "transformers/v5.1.0/src/Control/Monad/Reader/Class.purs"
      
      , "numbers/v8.0.0/src/Data/Number/Approximate.purs"
      , "free/v6.0.1/src/Data/Yoneda.purs"
      
      , "numbers/v8.0.0/src/Data/Number/Format.purs"
      , "effect/v3.0.0/src/Effect/Unsafe.purs"
      , "console/v5.0.0/src/Effect/Console.purs"
      , "effect/v3.0.0/src/Effect/Uncurried.purs"
      -- , "refs/v5.0.0/src/Effect/Ref.purs"
      -- , "effect/v3.0.0/src/Effect/Class.purs"
      -- , "psci-support/v5.0.0/src/PSCI/Support.purs"
      -- , "assert/v5.0.0/src/Test/Assert.purs"
      -- , "console/v5.0.0/src/Effect/Class/Console.purs"
      -- , "functors/v4.1.1/src/Data/Functor/App.purs"
      -- , "orders/v5.0.0/src/Data/Ord/Down.purs"
      -- , "orders/v5.0.0/src/Data/Ord/Min.purs"
      -- , "orders/v5.0.0/src/Data/Ord/Max.purs"
      -- , "datetime/v5.0.2/src/Data/Time/Duration.purs"
      -- , "profunctor/v5.0.0/src/Data/Profunctor.purs"
      -- , "transformers/v5.1.0/src/Control/Comonad/Traced/Trans.purs"
      -- , "strings/v5.0.0/src/Data/String/Pattern.purs"
      -- , "strings/v5.0.0/src/Data/String/Common.purs"
      -- , "profunctor/v5.0.0/src/Data/Profunctor/Closed.purs"
      -- , "invariant/v5.0.0/src/Data/Functor/Invariant.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Compose.purs"
      -- , "const/v5.0.0/src/Data/Const.purs"
      -- , "tuples/v6.0.1/src/Data/Tuple.purs"
      -- , "maybe/v5.0.0/src/Data/Maybe.purs"
      -- , "identity/v5.0.0/src/Data/Identity.purs"
      -- , "profunctor/v5.0.0/src/Data/Profunctor/Join.purs"
      -- , "profunctor/v5.0.0/src/Data/Profunctor/Split.purs"
      -- , "contravariant/v5.0.0/src/Data/Functor/Contravariant.purs"
      -- , "contravariant/v5.0.0/src/Data/Op.purs"
      -- , "contravariant/v5.0.0/src/Data/Predicate.purs"
      -- , "contravariant/v5.0.0/src/Data/Comparison.purs"
      -- , "contravariant/v5.0.0/src/Data/Equivalence.purs"
      -- , "either/v5.0.0/src/Data/Either.purs"
      -- , "maybe/v5.0.0/src/Data/Maybe/Last.purs"
      -- , "strings/v5.0.0/src/Data/String/CodeUnits.purs"
      -- , "maybe/v5.0.0/src/Data/Maybe/First.purs"
      -- , "numbers/v8.0.0/src/Data/Number.purs"
      -- , "integers/v5.0.0/src/Data/Int.purs"
      -- , "contravariant/v5.0.0/src/Data/Divide.purs"
      -- , "profunctor/v5.0.0/src/Data/Profunctor/Strong.purs"
      -- , "transformers/v5.1.0/src/Control/Comonad/Store/Trans.purs"
      -- , "distributive/v5.0.0/src/Data/Distributive.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/State/Class.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Writer/Class.purs"
      -- , "transformers/v5.1.0/src/Control/Comonad/Traced/Class.purs"
      -- , "tuples/v6.0.1/src/Data/Tuple/Nested.purs"
      -- , "profunctor/v5.0.0/src/Data/Profunctor/Costrong.purs"
      -- , "random/v5.0.0/src/Effect/Random.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Cont/Trans.purs"
      -- , "transformers/v5.1.0/src/Control/Comonad/Traced.purs"
      -- , "lcg/v3.0.0/src/Random/LCG.purs"
      -- , "contravariant/v5.0.0/src/Data/Divisible.purs"
      -- , "contravariant/v5.0.0/src/Data/Decide.purs"
      -- , "profunctor/v5.0.0/src/Data/Profunctor/Cochoice.purs"
      -- , "exceptions/v5.0.0/src/Effect/Exception.purs"
      -- , "bifunctors/v5.0.0/src/Data/Bifunctor.purs"
      -- , "either/v5.0.0/src/Data/Either/Nested.purs"
      -- , "either/v5.0.0/src/Data/Either/Inject.purs"
      -- , "profunctor/v5.0.0/src/Data/Profunctor/Choice.purs"
      -- , "exceptions/v5.0.0/src/Effect/Exception/Unsafe.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Error/Class.purs"
      -- , "bifunctors/v5.0.0/src/Control/Biapply.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Coproduct.purs"
      -- , "tailrec/v5.0.1/src/Control/Monad/Rec/Class.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Product.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Costar.purs"
      -- , "profunctor/v5.0.0/src/Data/Profunctor/Star.purs"
      -- , "contravariant/v5.0.0/src/Data/Decidable.purs"
      -- , "bifunctors/v5.0.0/src/Control/Biapplicative.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Cont.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Joker.purs"
      -- , "bifunctors/v5.0.0/src/Data/Bifunctor/Join.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Clown.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Flip.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Product2.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Coproduct/Inject.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Coproduct/Nested.purs"
      -- , "foldable-traversable/v5.0.1/src/Data/FunctorWithIndex.purs"
      -- , "functors/v4.1.1/src/Data/Functor/Product/Nested.purs"
      -- , "foldable-traversable/v5.0.1/src/Data/Foldable.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Maybe/Trans.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/RWS/Trans.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Reader/Trans.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Except/Trans.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Writer/Trans.purs"
      -- , "st/v5.0.1/src/Control/Monad/ST/Internal.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/State/Trans.purs"
      -- , "st/v5.0.1/src/Control/Monad/ST.purs"
      -- , "arrays/v6.0.1/src/Data/Array/ST.purs"
      -- , "st/v5.0.1/src/Control/Monad/ST/Global.purs"
      -- , "st/v5.0.1/src/Control/Monad/ST/Ref.purs"
      -- , "foreign-object/v3.0.0/src/Foreign/Object/ST.purs"
      -- , "st/v5.0.1/src/Control/Monad/ST/Class.purs"
      -- , "arrays/v6.0.1/src/Data/Array/ST/Partial.purs"
      -- , "arrays/v6.0.1/src/Data/Array/ST/Iterator.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Reader.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Except.purs"
      -- , "parallel/v5.0.0/src/Control/Parallel/Class.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Writer.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/State.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/RWS.purs"
      -- , "foldable-traversable/v5.0.1/src/Data/Bifoldable.purs"
      -- , "foldable-traversable/v5.0.1/src/Data/FoldableWithIndex.purs"
      -- , "foldable-traversable/v5.0.1/src/Data/Traversable.purs"
      -- , "foldable-traversable/v5.0.1/src/Data/Semigroup/Foldable.purs"
      -- , "transformers/v5.1.0/src/Control/Comonad/Env/Trans.purs"
      -- , "foldable-traversable/v5.0.1/src/Data/Semigroup/Traversable.purs"
      -- , "foldable-traversable/v5.0.1/src/Data/Bitraversable.purs"
      -- , "validation/v5.0.0/src/Data/Validation/Semigroup.purs"
      -- , "validation/v5.0.0/src/Data/Validation/Semiring.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/Identity/Trans.purs"
      -- , "parallel/v5.0.0/src/Control/Parallel.purs"
      -- , "free/v6.0.1/src/Data/Coyoneda.purs"
      -- , "unfoldable/v5.0.0/src/Data/Unfoldable1.purs"
      -- , "foldable-traversable/v5.0.1/src/Data/TraversableWithIndex.purs"
      -- , "transformers/v5.1.0/src/Control/Comonad/Env/Class.purs"
      -- , "transformers/v5.1.0/src/Control/Comonad/Store/Class.purs"
      -- , "unfoldable/v5.0.0/src/Data/Unfoldable.purs"
      -- , "transformers/v5.1.0/src/Control/Comonad/Env.purs"
      -- , "transformers/v5.1.0/src/Control/Comonad/Store.purs"
      -- , "enums/v5.0.0/src/Data/Enum.purs"
      -- , "gen/v3.0.0/src/Control/Monad/Gen.purs"
      -- , "datetime/v5.0.2/src/Data/Time/Duration/Gen.purs"
      -- , "arrays/v6.0.1/src/Data/Array/NonEmpty/Internal.purs"
      -- , "nonempty/v6.0.0/src/Data/NonEmpty.purs"
      -- , "lazy/v5.0.0/src/Data/Lazy.purs"
      -- , "arrays/v6.0.1/src/Data/Array.purs"
      -- , "datetime/v5.0.2/src/Data/Time/Component.purs"
      -- , "datetime/v5.0.2/src/Data/Date/Component.purs"
      -- , "strings/v5.0.0/src/Data/Char.purs"
      -- , "enums/v5.0.0/src/Data/Enum/Generic.purs"
      -- , "transformers/v5.1.0/src/Control/Monad/List/Trans.purs"
      -- , "enums/v5.0.0/src/Data/Enum/Gen.purs"
      -- , "lists/v6.0.1/src/Data/List/Lazy/Types.purs"
      -- , "strings/v5.0.0/src/Data/Char/Gen.purs"
      -- , "lists/v6.0.1/src/Data/List/Types.purs"
      -- , "gen/v3.0.0/src/Control/Monad/Gen/Common.purs"
      -- , "datetime/v5.0.2/src/Data/Time/Component/Gen.purs"
      -- , "datetime/v5.0.2/src/Data/Time.purs"
      -- , "strings/v5.0.0/src/Data/String/Gen.purs"
      -- , "datetime/v5.0.2/src/Data/Date/Component/Gen.purs"
      -- , "datetime/v5.0.2/src/Data/Date.purs"
      -- , "datetime/v5.0.2/src/Data/Time/Gen.purs"
      -- , "arrays/v6.0.1/src/Data/Array/Partial.purs"
      -- , "foreign-object/v3.0.0/src/Foreign/Object.purs"
      -- , "strings/v5.0.0/src/Data/String/CodePoints.purs"
      -- , "arrays/v6.0.1/src/Data/Array/NonEmpty.purs"
      -- , "datetime/v5.0.2/src/Data/Date/Gen.purs"
      -- , "datetime/v5.0.2/src/Data/DateTime.purs"
      -- , "lists/v6.0.1/src/Data/List/Internal.purs"
      -- , "datetime/v5.0.2/src/Data/DateTime/Gen.purs"
      -- , "datetime/v5.0.2/src/Data/DateTime/Instant.purs"
      -- , "strings/v5.0.0/src/Data/String.purs"
      -- , "strings/v5.0.0/src/Data/String/NonEmpty/Internal.purs"
      -- , "strings/v5.0.0/src/Data/String/CaseInsensitive.purs"
      -- , "strings/v5.0.0/src/Data/String/Regex/Flags.purs"
      -- , "lists/v6.0.1/src/Data/List/Lazy.purs"
      -- , "lists/v6.0.1/src/Data/List.purs"
      -- , "foreign-object/v3.0.0/src/Foreign/Object/Unsafe.purs"
      -- , "foreign-object/v3.0.0/src/Foreign/Object/ST/Unsafe.purs"
      -- , "strings/v5.0.0/src/Data/String/NonEmpty/CodeUnits.purs"
      -- , "strings/v5.0.0/src/Data/String/Regex.purs"
      -- , "strings/v5.0.0/src/Data/String/NonEmpty/CodePoints.purs"
      -- , "strings/v5.0.0/src/Data/String/Regex/Unsafe.purs"
      -- , "strings/v5.0.0/src/Data/String/NonEmpty.purs"
      -- , "strings/v5.0.0/src/Data/String/NonEmpty/CaseInsensitive.purs"
      -- , "lists/v6.0.1/src/Data/List/ZipList.purs"
      -- , "lists/v6.0.1/src/Data/List/Lazy/NonEmpty.purs"
      -- , "foreign-object/v3.0.0/src/Foreign/Object/Gen.purs"
      -- , "lists/v6.0.1/src/Data/List/Partial.purs"
      -- , "catenable-lists/v6.0.1/src/Data/CatQueue.purs"
      -- , "semirings/v6.0.0/src/Data/Semiring/Free.purs"
      -- , "ordered-collections/v2.0.1/src/Data/Map/Internal.purs"
      -- , "lists/v6.0.1/src/Data/List/NonEmpty.purs"
      -- , "catenable-lists/v6.0.1/src/Data/CatList.purs"
      -- , "foreign/v6.0.1/src/Foreign.purs"
      -- , "quickcheck/v7.1.0/src/Test/QuickCheck/Gen.purs"
      -- , "free/v6.0.1/src/Control/Monad/Free.purs"
      -- , "foreign/v6.0.1/src/Foreign/Keys.purs"
      -- , "foreign/v6.0.1/src/Foreign/Index.purs"
      -- , "quickcheck/v7.1.0/src/Test/QuickCheck/Arbitrary.purs"
      -- , "free/v6.0.1/src/Control/Comonad/Cofree.purs"
      -- , "free/v6.0.1/src/Control/Monad/Trampoline.purs"
      -- , "free/v6.0.1/src/Control/Monad/Free/Class.purs"
      -- , "free/v6.0.1/src/Control/Comonad/Cofree/Class.purs"
      -- , "quickcheck/v7.1.0/src/Test/QuickCheck.purs"
      -- , "ordered-collections/v2.0.1/src/Data/Set.purs"
      -- , "ordered-collections/v2.0.1/src/Data/Map.purs"
      -- , "ordered-collections/v2.0.1/src/Data/Set/NonEmpty.purs"
      -- , "graphs/v5.0.0/src/Data/Graph.purs"
      -- , "ordered-collections/v2.0.1/src/Data/Map/Gen.purs"
      -- , "datetime/v5.0.2/src/Data/Interval/Duration.purs"
      -- , "datetime/v5.0.2/src/Data/Interval.purs"
      -- , "datetime/v5.0.2/src/Data/Interval/Duration/Iso.purs"
      ]
    
env :: forall m. (MonadFix m, Typeable m) => Env m
env = 
  fold
    [ Control.Apply.env
    , Control.Bind.env
    , Control.Extend.env
    , Control.Monad.ST.Internal.env
    , Data.Bounded.env
    , Data.Eq.env
    , Data.EuclideanRing.env
    , Data.Foldable.env
    , Data.Function.Uncurried.env
    , Data.Functor.env
    , Data.FunctorWithIndex.env
    , Data.HeytingAlgebra.env
    , Data.Int.env
    , Data.Int.Bits.env
    , Data.Number.env
    , Data.Number.Format.env
    , Data.Ord.env
    , Data.Ring.env
    , Data.Semigroup.env
    , Data.Semiring.env
    , Data.Show.env
    , Data.Show.Generic.env
    , Data.String.CodeUnits.env
    , Data.String.Common.env
    , Data.String.Regex.env
    , Data.String.Unsafe.env
    , Data.Symbol.env
    , Data.Unit.env
    , Effect.env
    , Effect.Console.env
    , Effect.Exception.env
    , Effect.Random.env
    , Effect.Ref.env
    , Effect.Uncurried.env
    , Effect.Unsafe.env
    , Math.env
    , Partial.env
    , Partial.Unsafe.env
    , Record.Builder.env
    , Record.Unsafe.env
    , Record.Unsafe.Union.env
    , Test.Assert.env
    , Unsafe.Coerce.env
    ]