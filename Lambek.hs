{-# OPTIONS_GHC -fwarn-incomplete-patterns #-}

module Lambek where

import LTypes
import Data.Char (toLower)
import LExp

-- Part 1 : dec_rinv and dec_lfoc

-- split a list in all possible tuples
split :: [a] -> [([a], [a])]
split l = [splitAt i l | i <- [0 .. length l]]

-- check if any of the statements is true in a list
anyTrue :: [Bool] -> Bool
anyTrue = any id

dec_rinv :: [LTp] -> LTp -> Bool
dec_rinv gamma (Atm p) = anyTrue [(dec_lfoc gammaL a gammaR p) | (gammaL, a : gammaR) <- split gamma] -- rule F
dec_rinv gamma (DivL a b) = dec_rinv (a : gamma) b -- rule R
dec_rinv gamma (DivR b a) = dec_rinv (gamma ++ [a]) b -- rule R'

dec_lfoc :: [LTp] -> LTp -> [LTp] -> Atm -> Bool
dec_lfoc [] (Atm p) [] q = p == q -- rule X
dec_lfoc _ (Atm _) _ _ = False
dec_lfoc gammaL (DivL a b) gammaR p = anyTrue [ (dec_rinv gammaL2 a) && (dec_lfoc gammaL1 b gammaR p) | (gammaL1, gammaL2) <- split gammaL ] -- rule L'
dec_lfoc gammaL (DivR b a) gammaR p = anyTrue [ (dec_rinv gammaR1 a) && (dec_lfoc gammaL b gammaR2 p) | (gammaR1, gammaR2) <- split gammaR ] -- rule L

-- extracts all possible type lists for a sentence
types :: Lexicon sem -> [String] -> [[LTp]]
types lex ws = sequence( map (\w' -> [t | (w, t, _) <- items lex, map toLower w == map toLower w' ]) ws)

isGrammatical :: Lexicon sem -> [String] -> Bool
isGrammatical lex ws = anyTrue [ (dec_rinv ts (stp lex)) | ts <- types lex ws]

-- Part 2 : der_rinv and der_lfoc

-- assigns a fresh variable 
freshVar :: [(Var,LTp)] -> Var
freshVar gamma = fresh [ V v | (v,_) <- gamma ]

der_rinv :: [(Var,LTp)] -> LTp -> [LExp]
der_rinv gamma (Atm p) = [foldl A (V x) es | (gammaL, (x, t) : gammaR) <- split gamma, es <- der_lfoc gammaL t gammaR p] -- rule F
der_rinv gamma (DivL a b) = [L x e | let x = (freshVar gamma), e <- der_rinv ((x, a) : gamma) b] -- rule R
der_rinv gamma (DivR b a) = [L x e | let x = (freshVar gamma), e <- der_rinv (gamma ++ [(x, a)]) b] -- rule R'

der_lfoc :: [(Var,LTp)] -> LTp -> [(Var,LTp)] -> Atm -> [[LExp]]
der_lfoc [] (Atm p) [] q                     -- rule X
        | p == q = [[]]
        | otherwise = []
der_lfoc _ (Atm _) _ _ = []                   -- rule X failed
der_lfoc gammaL (DivL a b) gammaR p = [e : es | (gammaL1, gammaL2) <- split gammaL, 
                                                e <- (der_rinv gammaL2 a), 
                                                es <- (der_lfoc gammaL1 b gammaR p)] -- rule L'
der_lfoc gammaL (DivR b a) gammaR p = [e : es | (gammaR1, gammaR2) <- split gammaR,
                                                e <- (der_rinv gammaR1 a), 
                                                es <- (der_lfoc gammaL b gammaR2 p)] -- rule L
                                                
-- Lexicon entries for a word (case-insensitive).
entriesFor :: Lexicon sem -> String -> [(String, LTp, sem)]
entriesFor lex w = [ (w', t, s) | (w', t, s) <- items lex, map toLower w' == map toLower w ]

-- Give each chosen entry a variable name made of its spelling and its position.
numbered :: Int -> [(String, LTp, sem)] -> [(Var, LTp, sem)]
numbered _ []                = []
numbered i ((w, t, s) : rest) = (w ++ "_" ++ show i, t, s) : numbered (i + 1) rest

-- Every derivation of the sentence, together with the semantic value
-- of each word variable (Cat_2, Every_1, ...) in the entries that were used.
derivationsWith :: Lexicon sem -> [String] -> [(LExp, [(Var, sem)])]
derivationsWith lex ws =
  [ (e, [ (v, s) | (v, _, s) <- named ])
  | choice <- sequence (map (entriesFor lex) ws),              -- list of all possible [(word, type, sem]) 
    let named = numbered 0 choice,                             -- list of [(numbered_var, type, sem])
    e <- der_rinv [ (v, t) | (v, t, _) <- named ] (stp lex) ]  -- possible derivations

-- Just the lambda terms.
derivations :: Lexicon sem -> [String] -> [LExp]
derivations lex ws = map fst (derivationsWith lex ws)
