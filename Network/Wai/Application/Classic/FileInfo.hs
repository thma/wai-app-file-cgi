module Network.Wai.Application.Classic.FileInfo where

import Data.ByteString (ByteString)
import Network.HTTP.Date
import Network.HTTP.Types
import Network.Wai
import Network.Wai.Application.Classic.Field
import Network.Wai.Application.Classic.Header
import Network.Wai.Application.Classic.Path
import Network.Wai.Application.Classic.Range
import Network.Wai.Application.Classic.Types

----------------------------------------------------------------

data StatusAux = Full Status | Partial Integer Integer deriving Show

ifmodified :: IndexedHeader -> Integer -> HTTPDate -> Maybe StatusAux
ifmodified reqidx size mtime = do
    date <- ifModifiedSince reqidx
    if date /= mtime
       then unconditional reqidx size mtime
       else Just (Full notModified304)

ifunmodified :: IndexedHeader -> Integer -> HTTPDate -> Maybe StatusAux
ifunmodified reqidx size mtime = do
    date <- ifUnmodifiedSince reqidx
    if date == mtime
       then unconditional reqidx size mtime
       else Just (Full preconditionFailed412)

ifrange :: IndexedHeader -> Integer -> HTTPDate -> Maybe StatusAux
ifrange reqidx size mtime = do
    date <- ifRange reqidx
    rng  <- range reqidx
    if date == mtime
       then parseRange size rng
       else Just (Full ok200)

unconditional :: IndexedHeader -> Integer -> HTTPDate -> Maybe StatusAux
unconditional reqidx size _ =
    maybe (Just (Full ok200)) (parseRange size) $ range reqidx

parseRange :: Integer -> ByteString -> Maybe StatusAux
parseRange size rng = case skipAndSize rng size of
    Nothing         -> Just (Full requestedRangeNotSatisfiable416)
    Just (skip,len) -> Just (Partial skip len)

----------------------------------------------------------------

pathinfoToFilePath :: Request -> FileRoute -> Path
pathinfoToFilePath req filei = path'
  where
    path = fromByteString $ rawPathInfo req
    src = fileSrc filei
    dst = fileDst filei
    path' = dst </> (path <\> src)

addIndex :: FileAppSpec -> Path -> Path
addIndex spec path
  | hasTrailingPathSeparator path = path </> indexFile spec
  | otherwise                     = path

redirectPath :: FileAppSpec -> Path -> Maybe Path
redirectPath spec path
  | hasTrailingPathSeparator path = Nothing
  | otherwise                     = Just (path </> indexFile spec)
