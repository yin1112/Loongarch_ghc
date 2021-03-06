{-# LANGUAGE MonoLocalBinds, RankNTypes, ScopedTypeVariables #-}

module T11339c where

import Control.Applicative ( Const(Const, getConst) )
import Data.Functor.Identity ( Identity(Identity) )

type Traversal s t a b = forall f. Applicative f => (a -> f b) -> s -> f t

failing :: forall s t a b . Traversal s t a b -> Traversal s t a b -> Traversal s t a b
failing left right afb s = case pins t of
  [] -> right afb s
  _  -> t afb
  where
    -- Works because of MonoLocalBinds
    -- But the type signature (from T11339b) is wrong:
    --   t :: Applicative f => (a -> f b) -> f t
    -- The type signature forces us to generalise, but the MR applies,
    --  so the function can't be overloaded
    Bazaar { getBazaar = t } = left sell s

    sell :: a -> Bazaar a b b
    sell w   = Bazaar ($ w)

    pins :: ((a -> Const [Identity a] b) -> Const [Identity a] t) -> [Identity a]
    pins f   = getConst (f (\ra -> Const [Identity ra]))

newtype Bazaar a b t = Bazaar { getBazaar :: (forall f. Applicative f => (a -> f b) -> f t) }

instance Functor (Bazaar a b) where
  fmap f (Bazaar k) = Bazaar (fmap f . k)

instance Applicative (Bazaar a b) where
  pure a = Bazaar $ \_ -> pure a
  Bazaar mf <*> Bazaar ma = Bazaar $ \afb -> mf afb <*> ma afb
