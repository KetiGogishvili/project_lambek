import Data.Char
import Data.List (intercalate) 
import System.IO
import Control.Exception

import LTypes
import qualified Lambek
import LExp

import Parser
import PySupport

-- added functions --

-- output derivations
showDerivations :: Lexicon sem -> [String] -> IO ()
showDerivations lex ws =
  case Lambek.derivations lex ws of
    [] -> putStrLn "The sentence is not well-formed"
    ds -> do
      putStrLn "I can derive your sentence as follows:"
      mapM_ (\d -> putStrLn ("   " ++ prettyLExp d)) ds
      
 -- translate a lambda term into a one-line Python expression
toPython :: LExp -> String
toPython (V x)   = x
toPython (A f a) = "(" ++ toPython f ++ ")(" ++ toPython a ++ ")"
toPython (L x e) = "(lambda " ++ x ++ ": " ++ toPython e ++ ")"

-- meaning of a binding in parenthesis
meaningString :: (Var, PythonCode) -> String
meaningString (_, s) = "(" ++ text s ++ ")"

-- the Python code for one derivation
pythonFor :: LExp -> [(Var, PythonCode)] -> PythonCode
pythonFor e binds =
  PCode ("(lambda " ++ intercalate ", " (map fst binds) ++ ": " ++ toPython e ++ ")("
         ++ intercalate ", " (map meaningString binds) ++ ")")

-- evaluate each reading with Python and print one "Sense" line per reading
printReadings :: PythonHandle -> [(LExp, [(Var, PythonCode)])] -> IO ()
printReadings _  []                    = return ()
printReadings ph ((e, binds) : rest) = do
  r <- runPythonCode ph (pythonFor e binds)
  putStrLn ("Sense [" ++ prettyLExp e ++ "]: " ++ r)
  printReadings ph rest
  
 -- derive, evaluate and report the sentence
answer :: Lexicon PythonCode -> PythonHandle -> [String] -> IO ()
answer lex ph ws =
  case Lambek.derivationsWith lex ws of
    [] -> putStrLn "That is not a well-formed sentence"
    [(e, binds)] -> do
      r <- runPythonCode ph (pythonFor e binds)
      putStrLn r
    readings -> do
      putStrLn "That sentence is ambiguous"
      printReadings ph readings
   
-- end of added functions --

-- "standardize" the capitalization of a word by making the first
-- letter uppercase and the following letters lowercase.
-- (This will make it easier to look up words in the lexicon.)
stdize (c:cs) = toUpper c : map toLower cs

-- read-eval-print-loop
repl :: Lexicon PythonCode -> PythonHandle -> IO ()
repl elx phandle = do
  -- print the prompt
  putStr "> "
  -- get a line of input
  line <- getLine
  -- split it up into "standardized" words
  let ws = map stdize $ words line
 {-
 -- version 1 --
 -- test if the string of words is a grammatical sentence according to the lexicon
  if Lambek.isGrammatical elx ws
    then putStrLn "That is a well-formed sentence!"
    else putStrLn "That is not a well-formed sentence"
 -}
 {-
  -- version 2
  -- show all possible derivations
  showDerivations elx ws
 -}
  -- version 3
  answer elx phandle ws 
  -- repeat
  repl elx phandle
      
main = do
  -- send console output immediately to the user
  hSetBuffering stdout NoBuffering
  -- input a lexicon file
  elx <- getLex
  -- input a database of facts
  db <- getDB
  -- launch a Python interpreter
  phandle <- launchPython db
  -- start the read-eval-print loop
  putStrLn "Starting chat..."
  repl elx phandle
  where
    getDB :: IO PythonCode
    getDB = do
      putStr "Facts about the world: "
      dname <- getLine
      mdb <- try (readFile dname) :: IO (Either IOError String)
      case mdb of
        Left err -> putStrLn ("Error loading file " ++ show err) >> getDB
        Right db -> return (PCode db)
      
    getLex :: IO (Lexicon PythonCode)
    getLex = do
      putStr "Lexicon file: "
      lname <- getLine
      res <- parseFile lexicon lname
      case res of
        Left err -> putStrLn ("Error loading file " ++ show err) >> getLex
        Right (Left err) -> putStrLn ("parse error at " ++ lname ++ ":" ++ show err) >> getLex
        Right (Right lex) -> return lex
