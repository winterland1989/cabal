-----------------------------------------------------------------------------
-- |
-- Module      :  Distribution.Simple.Program.HcPkg
-- Copyright   :  Duncan Coutts 2009
--
-- Maintainer  :  cabal-devel@haskell.org
-- Portability :  portable
--
-- This module provides an library interface to the @hc-pkg@ program.
-- Currently only GHC and LHC have hc-pkg programs.

module Distribution.Simple.Program.HcPkg (
    register,
    reregister,
    unregister,
    expose,
    hide,
    dump,

    -- * Program invocations
    registerInvocation,
    reregisterInvocation,
    unregisterInvocation,
    exposeInvocation,
    hideInvocation,
    dumpInvocation,
  ) where

import Distribution.Package
         ( PackageId )
import Distribution.InstalledPackageInfo
         ( InstalledPackageInfo
         , showInstalledPackageInfo, parseInstalledPackageInfo )
import Distribution.ParseUtils
         ( ParseResult(..) )
import Distribution.Simple.Compiler
         ( PackageDB(..) )
import Distribution.Simple.Program.Types
         ( ConfiguredProgram(..), programId )
import Distribution.Simple.Program.Run
         ( ProgramInvocation(..), programInvocation
         , runProgramInvocation, getProgramInvocationOutput )
import Distribution.Text
         ( display )
import Distribution.Simple.Utils
         ( die )
import Distribution.Verbosity
         ( Verbosity )
import Distribution.Compat.Exception
         ( catchExit )


-- | Call @hc-pkg@ to register a package.
--
-- > hc-pkg register {filename | -} [--user | --global | --package-conf]
--
register :: Verbosity -> ConfiguredProgram -> PackageDB
         -> Either FilePath
                   InstalledPackageInfo
         -> IO ()
register verbosity hcPkg packagedb pkgFile =
  runProgramInvocation verbosity (registerInvocation hcPkg packagedb pkgFile)


-- | Call @hc-pkg@ to re-register a package.
--
-- > hc-pkg register {filename | -} [--user | --global | --package-conf]
--
reregister :: Verbosity -> ConfiguredProgram -> PackageDB
           -> Either FilePath
                     InstalledPackageInfo
           -> IO ()
reregister verbosity hcPkg packagedb pkgFile =
  runProgramInvocation verbosity (reregisterInvocation hcPkg packagedb pkgFile)


-- | Call @hc-pkg@ to unregister a package
--
-- > hc-pkg unregister [pkgid] [--user | --global | --package-conf]
--
unregister :: Verbosity -> ConfiguredProgram -> PackageDB -> PackageId -> IO ()
unregister verbosity hcPkg packagedb pkgid =
  runProgramInvocation verbosity (unregisterInvocation hcPkg packagedb pkgid)


-- | Call @hc-pkg@ to expose a package.
--
-- > hc-pkg expose [pkgid] [--user | --global | --package-conf]
--
expose :: Verbosity -> ConfiguredProgram -> PackageDB -> PackageId -> IO ()
expose verbosity hcPkg packagedb pkgid =
  runProgramInvocation verbosity (exposeInvocation hcPkg packagedb pkgid)


-- | Call @hc-pkg@ to expose a package.
--
-- > hc-pkg expose [pkgid] [--user | --global | --package-conf]
--
hide :: Verbosity -> ConfiguredProgram -> PackageDB -> PackageId -> IO ()
hide verbosity hcPkg packagedb pkgid =
  runProgramInvocation verbosity (hideInvocation hcPkg packagedb pkgid)


-- | Call @hc-pkg@ to get all the installed packages.
--
dump :: Verbosity -> ConfiguredProgram -> PackageDB -> IO [InstalledPackageInfo]
dump verbosity hcPkg packagedb = do

  output <- getProgramInvocationOutput verbosity
              (dumpInvocation hcPkg packagedb)
    `catchExit` \_ -> die $ programId hcPkg ++ " dump failed"

  case parsePackages output of
    Left ok -> return ok
    _       -> die $ "failed to parse output of '"
                  ++ programId hcPkg ++ " dump'"

  where
    parsePackages str =
      let parsed = map parseInstalledPackageInfo (splitPkgs str)
       in case [ msg | ParseFailed msg <- parsed ] of
            []   -> Left [ pkg | ParseOk _ pkg <- parsed ]
            msgs -> Right msgs

    splitPkgs :: String -> [String]
    splitPkgs = map unlines . splitWith ("---" ==) . lines
      where
        splitWith :: (a -> Bool) -> [a] -> [[a]]
        splitWith p xs = ys : case zs of
                           []   -> []
                           _:ws -> splitWith p ws
          where (ys,zs) = break p xs


--------------------------
-- The program invocations
--

registerInvocation, reregisterInvocation
  :: ConfiguredProgram -> PackageDB
  -> Either FilePath InstalledPackageInfo
  -> ProgramInvocation
registerInvocation   = registerInvocation' "register"
reregisterInvocation = registerInvocation' "update"

registerInvocation' :: String
                    -> ConfiguredProgram -> PackageDB
                    -> Either FilePath InstalledPackageInfo
                    -> ProgramInvocation
registerInvocation' cmdname hcPkg packagedb (Left pkgFile) =
  programInvocation hcPkg
    [cmdname, pkgFile, packageDbOpts packagedb]

registerInvocation' cmdname hcPkg packagedb (Right pkgInfo) =
  (programInvocation hcPkg
     [cmdname, "-", packageDbOpts packagedb]) {
     progInvokeInput = Just (showInstalledPackageInfo pkgInfo)
  }


unregisterInvocation :: ConfiguredProgram -> PackageDB -> PackageId -> ProgramInvocation
unregisterInvocation hcPkg packagedb pkgid =
  programInvocation hcPkg
    ["unregister", packageDbOpts packagedb, display pkgid]


exposeInvocation :: ConfiguredProgram -> PackageDB -> PackageId -> ProgramInvocation
exposeInvocation hcPkg packagedb pkgid =
  programInvocation hcPkg
    ["expose", packageDbOpts packagedb, display pkgid]


hideInvocation :: ConfiguredProgram -> PackageDB -> PackageId -> ProgramInvocation
hideInvocation hcPkg packagedb pkgid =
  programInvocation hcPkg
    ["hide", packageDbOpts packagedb, display pkgid]


dumpInvocation :: ConfiguredProgram -> PackageDB -> ProgramInvocation
dumpInvocation hcPkg packagedb =
  programInvocation hcPkg
    ["dump", packageDbOpts packagedb]


packageDbOpts :: PackageDB -> String
packageDbOpts GlobalPackageDB        = "--global"
packageDbOpts UserPackageDB          = "--user"
packageDbOpts (SpecificPackageDB db) = "--package-conf=" ++ db