{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE UnboxedTuples #-}
{-# LANGUAGE MagicHash #-}
{-# LANGUAGE Unsafe #-}

module GHC.Weak.Finalize
    ( -- * Handling exceptions
      -- | When an exception is thrown by a finalizer called by the
      -- garbage collector, GHC calls a global handler which can be set with
      -- 'setFinalizerExceptionHandler'. Note that any exceptions thrown by
      -- this handler will be ignored.
      setFinalizerExceptionHandler
    , getFinalizerExceptionHandler
      -- * Internal
    , runFinalizerBatch
    ) where

import GHC.Base
import GHC.Exception
import GHC.IORef
import GHC.IO (catchException, unsafePerformIO)

-- | Run a batch of finalizers from the garbage collector.  We're given
-- an array of finalizers and the length of the array, and we just
-- call each one in turn.
runFinalizerBatch :: Int
                  -> Array# (State# RealWorld -> State# RealWorld)
                  -> IO ()
runFinalizerBatch (I# n) arr =
    go n
  where
    getFinalizer :: Int# -> IO ()
    getFinalizer i =
        case indexArray# arr i of
          (# io #) -> IO $ \s ->
              case io s of
                s' -> (# s', () #)

    go :: Int# -> IO ()
    go 0# = return ()
    go i = do
        let i' = i -# 1#
        let finalizer = getFinalizer i'
        finalizer `catchException` handleExc
        go i'

    handleExc :: SomeException -> IO ()
    handleExc se = do
        handleFinalizerExc <- getFinalizerExceptionHandler
        handleFinalizerExc se `catchException` (\(SomeException _) -> return ())

-- See Note [Handling exceptions during Handle finalization] for the
-- motivation for this mechanism.
finalizerExceptionHandler :: IORef (SomeException -> IO ())
finalizerExceptionHandler = unsafePerformIO $ newIORef (const $ return ())
{-# NOINLINE finalizerExceptionHandler #-}

-- | Get the global action called to report exceptions thrown by weak pointer
-- finalizers to the user.
--
-- @since 4.18.0.0
getFinalizerExceptionHandler :: IO (SomeException -> IO ())
getFinalizerExceptionHandler = readIORef finalizerExceptionHandler

-- | Set the global action called to report exceptions thrown by weak pointer
-- finalizers to the user.
--
-- @since 4.18.0.0
setFinalizerExceptionHandler :: (SomeException -> IO ()) -> IO ()
setFinalizerExceptionHandler = writeIORef finalizerExceptionHandler
