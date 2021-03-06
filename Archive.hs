module Archive (createArchive) where

import qualified Codec.Archive.Tar as Tar
import qualified Codec.Archive.Tar.Entry as Tar
import qualified Codec.Compression.GZip as GZip
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as Char8
import qualified Data.ByteString.Lazy as Lazy
import Data.ByteString (ByteString)
import Data.Char (chr, isAlphaNum, ord)
import Data.These (These(That, These))
import Data.List
import Data.Maybe (fromMaybe)


createArchive :: ByteString -> [(Maybe ByteString, ByteString)] -> Lazy.ByteString
createArchive key files =
    let dirprefix = BS.append key (Char8.pack "/")
        names = chooseNames (BS.length dirprefix) (map (fromMaybe (Char8.pack "file.hs") . fst) files)
        entries = [Tar.fileEntry path content'
                  | (name, content) <- zip names (map snd files)
                  , let content' = Lazy.fromStrict content
                  , path <- case Tar.toTarPath False (BS.append dirprefix name) of
                              That path -> [path]
                              These _ path -> [path]
                              _ -> []]
    in GZip.compress (Tar.write entries)

chooseNames :: Int -> [ByteString] -> [ByteString]
chooseNames reservedPrefixLen = concatMap numberGroup . group . sort . map (BS.take maxNameLen . filterName)
  where
    numberGroup :: [ByteString] -> [ByteString]
    numberGroup [file] = [file]
    numberGroup files =
        zipWith addSuffix files [Char8.pack ('-' : show i)
                                | i <- [1::Int ..]]

    addSuffix :: ByteString -> ByteString -> ByteString
    addSuffix name suffix = case BS.elemIndexEnd (fromIntegral (ord '.')) name of
        Just idx -> let (prefix, extension) = BS.splitAt idx name
                    in BS.concat [BS.take (maxLen - BS.length suffix - BS.length extension) prefix
                                 ,suffix
                                 ,extension]
        Nothing -> BS.concat [BS.take (maxLen - BS.length suffix) name
                             ,suffix]
      where
        maxLen = maxNameLen - reservedPrefixLen

    filterName :: ByteString -> ByteString
    filterName name =
        let name' = BS.filter (\c -> 32 <= c && c < 127 &&
                                        (let ch = chr (fromIntegral c)
                                         in isAlphaNum ch || ch `elem` "-_."))
                              name
        in if BS.null name' then Char8.pack "file.hs" else name'

-- This is a limitation of the POSIX USTAR format as supported by tar-bytestring.
maxNameLen :: Int
maxNameLen = 100
