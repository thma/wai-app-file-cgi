module Network.Wai.Application.Classic.FileInfo where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS
import Data.Time
import Data.Time.Clock.POSIX
import Network.HTTP.Types
import Network.Wai
import Network.Wai.Application.Classic.Field
import Network.Wai.Application.Classic.Header
import Network.Wai.Application.Classic.Range
import Network.Wai.Application.Classic.Types
import System.Directory
import System.FilePath
import System.Posix.Files

----------------------------------------------------------------

fileInfo :: FilePath -> IO (Maybe (Integer, UTCTime))
fileInfo file = do
    exist <- doesFileExist file
    if exist
       then do
         fs <- getFileStatus file
         let size = fromIntegral . fileSize $ fs
             mtime = posixSecondsToUTCTime . realToFrac . modificationTime $ fs
         return $ Just (size, mtime)
       else return Nothing

----------------------------------------------------------------

data StatusAux = Full Status | Partial Integer Integer

ifmodified :: Request -> Integer -> UTCTime -> Maybe StatusAux
ifmodified req size mtime = do
    date <- ifModifiedSince req
    if date /= mtime
       then unconditional req size mtime
       else Just (Full statusNotModified)

ifunmodified :: Request -> Integer -> UTCTime -> Maybe StatusAux
ifunmodified req size mtime = do
    date <- ifUnmodifiedSince req
    if date == mtime
       then unconditional req size mtime
       else Just (Full statusPreconditionFailed)

ifrange :: Request -> Integer -> UTCTime -> Maybe StatusAux
ifrange req size mtime = do
    date <- ifRange req
    rng  <- lookupRequestField fkRange req
    if date == mtime
       then Just (Full statusOK)
       else range size rng

unconditional :: Request -> Integer -> UTCTime -> Maybe StatusAux
unconditional req size _ =
    maybe (Just (Full statusOK)) (range size) $ lookupRequestField fkRange req

range :: Integer -> ByteString -> Maybe StatusAux
range size rng = case skipAndSize rng size of
  Nothing         -> Just (Full statusRequestedRangeNotSatisfiable)
  Just (skip,len) -> Just (Partial skip len)


----------------------------------------------------------------

pathinfoToFilePath :: Request -> FileRoute -> FilePath
pathinfoToFilePath req filei = path'
  where
    path = rawPathInfo req
    src = fileSrc filei
    dst = fileDst filei
    path' = dst </> drop (BS.length src) (BS.unpack path)

addIndex :: AppSpec -> FilePath -> FilePath
addIndex spec path
  | hasTrailingPathSeparator path = path </> indexFile spec
  | otherwise                     = path

redirectPath :: AppSpec -> FilePath -> Maybe FilePath
redirectPath spec path
  | hasTrailingPathSeparator path = Nothing
  | otherwise                     = Just (path </> indexFile spec)
