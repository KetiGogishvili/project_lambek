{-# OPTIONS_GHC -fwarn-incomplete-patterns #-}

module Lambek where

import LTypes
import Data.Char (toLower)

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
dec_lfoc gammaL (DivL a b) gammaR p = anyTrue [ (dec_rinv gammaL2 a) && (dec_lfoc gammaL1 b gammaR p) | (gammaL1, gammaL2) <- split gammaL, not (null gammaL2) ] -- rule L'
dec_lfoc gammaL (DivR b a) gammaR p = anyTrue [ (dec_rinv gammaR1 a) && (dec_lfoc gammaL b gammaR2 p) | (gammaR1, gammaR2) <- split gammaR, not (null gammaR1) ] -- rule L

-- extracts all possible type lists for a sentence
types :: Lexicon sem -> [String] -> [[LTp]]
types lex ws = sequence( map (\w' -> [t | (w, t, _) <- items lex, map toLower w == map toLower w' ]) ws)

isGrammatical :: Lexicon sem -> [String] -> Bool
isGrammatical lex ws = anyTrue [ (dec_rinv ts (stp lex)) | ts <- types lex ws]

