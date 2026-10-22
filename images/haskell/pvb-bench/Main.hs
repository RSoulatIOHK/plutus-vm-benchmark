{-# LANGUAGE ImportQualifiedPost #-}

{-| The Haskell row of plutus-vm-benchmark (spec D3, D4, D11; docs/IMAGE_CONTRACT.md).

Every script is evaluated the way cardano-node evaluates a PlutusV3 script at protocol version 11
(van Rossem): the evaluation context comes from 'V3.mkEvaluationContext' over the on-chain PlutusV3
cost model array, the budget mode is 'Cek.counting' (costing on, no limit). The evaluation code is
the one of check/reference/gate-ref, so the check gives the reference numbers.

@pvb-bench check COSTMODEL_JSON FLAT_DIR@
  One evaluation per script. Writes @vm,script,status,cpu,mem@ on stdout.

@pvb-bench bench COSTMODEL_JSON FLAT_DIR [criterion options]@
  One Criterion benchmark per script. Each iteration decodes the flat bytes and evaluates the
  program; reading the file is outside the timed loop. Each benchmark runs for at least 20 s, as in
  plutus-benchmark:validation (change it with -L). A script whose evaluation fails is not timed.

@pvb-bench bench-eval COSTMODEL_JSON FLAT_DIR [criterion options]@
  Eval only, with the same Criterion settings: the program is decoded (and fully forced) once
  before timing, each iteration evaluates it. The evaluation context (machine parameters) is built
  once, as for @bench@; 'Common.evaluateTerm' starts a new CEK machine with a new budget counter on
  every call.
-}
module Main (main) where

import Control.Monad (forM_, unless)
import Control.Monad.Except (runExcept)
import Control.Monad.Writer.Strict (runWriterT)
import Criterion.Main (Benchmark, bench, defaultConfig, defaultMainWith, env, whnf)
import Criterion.Types (Config (..))
import Data.Aeson qualified as Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.Types qualified as Aeson
import Data.ByteString qualified as BS
import Data.Either (isRight)
import Data.Int (Int64)
import Data.List (isSuffixOf, sort)
import System.Directory (listDirectory)
import System.Environment (getArgs, withArgs)
import System.FilePath (dropExtension, (</>))
import System.IO (hPutStrLn, stderr)

import PlutusCore.Evaluation.Machine.ExBudget (ExBudget (..))
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
mainnetContext :: FilePath -> IO Common.EvaluationContext
mainnetContext path = do
  params <- readCostModel path
  hPutStrLn stderr ("PlutusV3 cost model parameters: " ++ show (length params))
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

-- | Flat decode, then give every variable a fake name (the term type evaluateTerm takes).
decode :: FilePath -> BS.ByteString -> Term
decode file bytes =
  case unflat bytes of
    Left e -> errorWithoutStackTrace ("flat decode failed for " ++ file ++ ": " ++ show e)
    Right (UPLC.UnrestrictedProgram prog) ->
      UPLC.termMapNames UPLC.fakeNameDeBruijn (UPLC._progTerm prog)

run :: Common.EvaluationContext -> Term -> Cek.CekReport Cek.CountingSt UPLC.NamedDeBruijn UPLC.DefaultUni UPLC.DefaultFun
run = Common.evaluateTerm Cek.counting Common.vanRossemPV Common.Quiet

evaluate :: Common.EvaluationContext -> Term -> Outcome
evaluate ctx term =
  case run ctx term of
    Cek.CekReport res (Cek.CountingSt (ExBudget (ExCPU cpu) (ExMemory mem))) _ ->
      let status = either (const "error") (const "ok") (Cek.cekResultToEither res)
       in (status, read (show cpu), read (show mem))

{-| The timed function: decode + evaluate. The result is True on success. Forcing it to WHNF
forces the budget and the evaluation result, so the whole evaluation runs. -}
decodeAndEvaluate :: Common.EvaluationContext -> FilePath -> BS.ByteString -> Bool
decodeAndEvaluate ctx file bytes =
  case run ctx (decode file bytes) of
    Cek.CekReport res (Cek.CountingSt budget) _ ->
      budget `seq` isRight (Cek.cekResultToEither res)

{-| The timed function of @bench-eval@: evaluate a decoded term. Forced like
'decodeAndEvaluate'. -}
evaluateDecoded :: Common.EvaluationContext -> Term -> Bool
evaluateDecoded ctx term =
  case run ctx term of
    Cek.CekReport res (Cek.CountingSt budget) _ ->
      budget `seq` isRight (Cek.cekResultToEither res)

flatFiles :: FilePath -> IO [FilePath]
flatFiles dir = sort . filter (".flat" `isSuffixOf`) <$> listDirectory dir

check :: FilePath -> FilePath -> IO ()
check costModelPath dir = do
  ctx <- mainnetContext costModelPath
  files <- flatFiles dir
  putStrLn "vm,script,status,cpu,mem"
  mapM_
    ( \file -> do
        term <- decode file <$> BS.readFile (dir </> file)
        let (status, cpu, mem) = evaluate ctx term
        putStrLn ("haskell," ++ dropExtension file ++ "," ++ status ++ "," ++ show cpu ++ "," ++ show mem)
    )
    files
  hPutStrLn stderr (show (length files) ++ " scripts checked")

-- | Which loop: flat decode + evaluation (spec D3), or evaluation of a program decoded once.
data Loop = DecodeAndEval | EvalOnly

benchmarks :: Loop -> FilePath -> FilePath -> [String] -> IO ()
benchmarks loop costModelPath dir criterionArgs = do
  ctx <- mainnetContext costModelPath
  files <- flatFiles dir
  -- Evaluate once; a script that fails is not timed (the run script fills in a -1 row).
  timed <- fmap concat . mapM (\file -> do
    ok <- decodeAndEvaluate ctx file <$> BS.readFile (dir </> file)
    unless ok $ hPutStrLn stderr ("error: " ++ dropExtension file ++ ": evaluation failed, not timed")
    pure [file | ok]) $ files
  let mkBench :: FilePath -> Benchmark
      mkBench file = case loop of
        DecodeAndEval ->
          env (BS.readFile (dir </> file)) $ \ ~bytes ->
            bench (dropExtension file) (whnf (decodeAndEvaluate ctx file) bytes)
        -- env forces the decoded term to normal form, so no decoding is left for the loop.
        EvalOnly ->
          env (decode file <$> BS.readFile (dir </> file)) $ \ ~term ->
            bench (dropExtension file) (whnf (evaluateDecoded ctx) term)
      -- Same time limit as plutus-benchmark:validation, without its HTML report.
      cfg = defaultConfig {timeLimit = 20}
  withArgs criterionArgs (defaultMainWith cfg (map mkBench timed))

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["check", c, d] -> check c d
    "bench" : c : d : rest -> benchmarks DecodeAndEval c d rest
    "bench-eval" : c : d : rest -> benchmarks EvalOnly c d rest
    _ -> fail "usage: pvb-bench check COSTMODEL_JSON FLAT_DIR | pvb-bench bench|bench-eval COSTMODEL_JSON FLAT_DIR [criterion options]"
