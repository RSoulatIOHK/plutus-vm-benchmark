{-# LANGUAGE ImportQualifiedPost #-}

{-| Haskell reference for the correctness gate.

For every *.flat file in a directory, decode the program and evaluate its term the way
cardano-node does for a PlutusV3 script at protocol version 11 (van Rossem): the evaluation
context comes from 'V3.mkEvaluationContext' applied to the on-chain PlutusV3 cost model
array, the budget mode is 'counting' (no limit, it only adds up the cost).

Output (stdout): vm,script,status,cpu,mem

As a cross-check, every script is evaluated a second time with the evaluation context that
plutus-benchmark:validation uses (the cost model compiled into plutus-core for semantics
variant E). The program prints the number of scripts where the two disagree on stderr and
exits 2 if there is any.

With the extra argument @variant-c@ it writes the reference for VMs that ship the older PlutusV3
cost model instead (the "outdated cost model" badge, check/README.md): builtin semantics variant C
with the variant C cost model compiled into plutus-core (builtinCostModelC.json and
cekMachineCostsC.json, unchanged since 2024), and case on builtin types enabled as at protocol
version 11, so that the 11 UPLC 1.1.0 scripts still run.

Usage: gate-ref COSTMODEL_JSON FLAT_DIR [variant-c] -}
module Main (main) where

import Control.Monad (forM, forM_, unless)
import Control.Monad.Except (runExcept)
import Control.Monad.Writer.Strict (runWriterT)
import Data.Aeson qualified as Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.Types qualified as Aeson
import Data.ByteString qualified as BS
import Data.Int (Int64)
import Data.List (isSuffixOf, sort)
import System.Directory (listDirectory)
import System.Environment (getArgs)
import System.Exit (exitWith, ExitCode (..))
import System.FilePath (dropExtension, (</>))
import System.IO (hPutStrLn, stderr)

import PlutusCore.Builtin qualified as PLC
import PlutusCore.Default (BuiltinSemanticsVariant (..), DefaultFun)
import PlutusCore.Evaluation.Machine.ExBudget (ExBudget (..))
import PlutusCore.Evaluation.Machine.ExBudgetingDefaults qualified as PLC
import PlutusCore.Evaluation.Machine.ExMemory (ExCPU (..), ExMemory (..))
import PlutusCore.Flat (unflat)
import PlutusLedgerApi.Common qualified as Common
import PlutusLedgerApi.V3 qualified as V3
import UntypedPlutusCore qualified as UPLC
import UntypedPlutusCore.Evaluation.Machine.Cek qualified as Cek

type Term = UPLC.Term UPLC.NamedDeBruijn UPLC.DefaultUni UPLC.DefaultFun ()

-- | Result of one evaluation: status, cpu, mem.
type Outcome = (String, Integer, Integer)

readCostModel :: FilePath -> IO [Int64]
readCostModel path = do
  r <- Aeson.eitherDecodeFileStrict path
  case r >>= Aeson.parseEither (Aeson.withObject "cost model" (Aeson..: Key.fromString "PlutusV3")) of
    Left e -> fail ("cannot read " ++ path ++ ": " ++ e)
    Right ps -> pure ps

-- | The node path: V3.mkEvaluationContext over the on-chain cost model array.
mainnetContext :: [Int64] -> IO Common.EvaluationContext
mainnetContext params =
  case runExcept (runWriterT (V3.mkEvaluationContext params)) of
    Left e -> fail ("mkEvaluationContext: " ++ show e)
    Right (ctx, warns) -> do
      -- As the node: fewer parameters than this plutus version knows is accepted, and plutus fills
      -- the missing ones with maxBound (PlutusLedgerApi.Common.ParamName, CMTooFewParamsWarn). The
      -- mainnet array (350) is shorter than plutus 1.70's (361): the 11 extra parameters belong to
      -- builtins none of the scripts call. More parameters than plutus knows means the array is newer
      -- than this plutus version: stop.
      let tooMany = [(Common.cmExpected w, Common.cmActual w) | w <- warns, Common.cmActual w > Common.cmExpected w]
      unless (null tooMany) $
        fail ("cost model has more parameters than this plutus version (expected, actual): " ++ show tooMany)
      forM_ warns $ \w -> hPutStrLn stderr
        ("note: cost model has " ++ show (Common.cmActual w) ++ " of " ++ show (Common.cmExpected w)
          ++ " parameters; plutus fills the missing ones with maxBound, as on the node")
      pure ctx

{-| A PlutusV3 context with the cost model compiled into plutus-core for one semantics variant,
case on builtin types enabled. For variant E this is the context of plutus-benchmark:validation
(PlutusBenchmark.Common.mkEvalCtx PlutusV3 E). -}
compiledContext :: BuiltinSemanticsVariant DefaultFun -> IO Common.EvaluationContext
compiledContext semvar =
  case PLC.defaultCostModelParamsForVariant semvar of
    Nothing -> fail ("no default cost model for variant " ++ show semvar)
    Just p ->
      case runExcept
        ( Common.mkDynEvaluationContext
            Common.PlutusV3
            (\_ -> PLC.CaserBuiltin PLC.caseBuiltin)
            [semvar]
            (const semvar)
            p
        ) of
        Left e -> fail ("mkDynEvaluationContext: " ++ show e)
        Right ctx -> pure ctx

evaluate :: Common.EvaluationContext -> Term -> Outcome
evaluate ctx term =
  case Common.evaluateTerm Cek.counting Common.vanRossemPV Common.Quiet ctx term of
    Cek.CekReport res (Cek.CountingSt (ExBudget (ExCPU cpu) (ExMemory mem))) _ ->
      let status = either (const "error") (const "ok") (Cek.cekResultToEither res)
       in (status, read (show cpu), read (show mem))

decode :: FilePath -> BS.ByteString -> Term
decode file bytes =
  case unflat bytes of
    Left e -> errorWithoutStackTrace ("flat decode failed for " ++ file ++ ": " ++ show e)
    Right (UPLC.UnrestrictedProgram prog) ->
      UPLC.termMapNames UPLC.fakeNameDeBruijn (UPLC._progTerm prog)

main :: IO ()
main = do
  args <- getArgs
  (costModelPath, dir, variantC) <- case args of
    [c, d] -> pure (c, d, False)
    [c, d, "variant-c"] -> pure (c, d, True)
    _ -> fail "usage: gate-ref COSTMODEL_JSON FLAT_DIR [variant-c]"
  files <- sort . filter (".flat" `isSuffixOf`) <$> listDirectory dir
  if variantC then writeVariantC dir files else writeMainnet costModelPath dir files

csvRow :: String -> Outcome -> String
csvRow name (status, cpu, mem) =
  "haskell," ++ name ++ "," ++ status ++ "," ++ show cpu ++ "," ++ show mem

writeVariantC :: FilePath -> [FilePath] -> IO ()
writeVariantC dir files = do
  ctx <- compiledContext DefaultFunSemanticsVariantC
  putStrLn "vm,script,status,cpu,mem"
  mapM_
    ( \file -> do
        term <- decode file <$> BS.readFile (dir </> file)
        putStrLn (csvRow (dropExtension file) (evaluate ctx term))
    )
    files
  hPutStrLn stderr (show (length files) ++ " scripts, variant C cost model")

writeMainnet :: FilePath -> FilePath -> [FilePath] -> IO ()
writeMainnet costModelPath dir files = do
  params <- readCostModel costModelPath
  hPutStrLn stderr ("PlutusV3 cost model parameters: " ++ show (length params))
  mainnet <- mainnetContext params
  bench <- compiledContext DefaultFunSemanticsVariantE
  putStrLn "vm,script,status,cpu,mem"
  diffs <- forM files $ \file -> do
    term <- decode file <$> BS.readFile (dir </> file)
    let o = evaluate mainnet term
        o' = evaluate bench term
        name = dropExtension file
    putStrLn (csvRow name o)
    unless (o == o') $
      hPutStrLn stderr ("DIFF " ++ name ++ ": mainnet " ++ show o ++ " vs bench-default-E " ++ show o')
    pure (o /= o')
  let n = length (filter id diffs)
  hPutStrLn stderr
    ( show (length files) ++ " scripts, "
        ++ show n
        ++ " differ between the mainnet cost model and the compiled-in variant E cost model"
    )
  unless (n == 0) $ exitWith (ExitFailure 2)
