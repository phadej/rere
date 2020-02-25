{-# LANGUAGE CPP               #-}
{-# LANGUAGE OverloadedStrings #-}
#ifdef RERE_CFG
{-# LANGUAGE Trustworthy       #-}
#elif __GLASGOW_HASKELL__ >=704
{-# LANGUAGE Safe              #-}
#elif __GLASGOW_HASKELL__ >=702
{-# LANGUAGE Trustworthy       #-}
#endif
-- | Various examples of using @rere@,
-- as used [in the blog post](#).
module RERE.Examples where

import Control.Applicative (some, (<|>))
import Control.Monad       (void)
import Data.Void           (Void)

import qualified Text.Parsec        as P
import qualified Text.Parsec.String as P

import RERE

#ifdef RERE_CFG
import Data.Vec.Lazy (Vec (..))

import qualified Data.Fin      as F
import qualified Data.Type.Nat as N
#endif

#ifdef RERE_INTERSECTION
import Data.Void (vacuous)
#endif

#if !MIN_VERSION_base(4,8,0)
import Control.Applicative ((*>))
#endif

#if !MIN_VERSION_base(4,11,0)
import Data.Semigroup (Semigroup (..))
#endif

-- $setup
-- >>> import Test.QuickCheck.Random (mkQCGen)
-- >>> import Test.QuickCheck.Gen (unGen)
-- >>> let runGen seed = maybe "<<null>>" (\g' -> unGen g' (mkQCGen seed) 10)

-------------------------------------------------------------------------------
-- * Syntax
-------------------------------------------------------------------------------

-- | Demonstrates how various constructors are pretty printed.
syntaxExamples :: IO ()
syntaxExamples = do
    putLatex Null
    putLatex Eps

    putLatex $ ch_ 'a'
    putLatex $ ch_ 'b'

    putLatex $ Let "r" Eps $ Let "r" Eps $ App (Var B) (Var (F B))
    putLatex $ Let "r" Eps $ Let "r" Eps $ Alt (Var B) (Var (F B))
    putLatex $ Let "r" Eps $ Star (Var B)

-------------------------------------------------------------------------------
-- * Example 1
-------------------------------------------------------------------------------

-- |
--
-- >>> match ex1 "abab"
-- True
--
-- >>> match ex1 "ababa"
-- False
--
-- >>> ex1
-- Star (App (Ch "a") (Ch "b"))
--
-- >>> fromRE ex1
-- Star (App (Ch "a") (Ch "b"))
--
-- >>> matchR ex1 "abab"
-- True
--
-- >>> matchR ex1 "ababa"
-- False
--
-- >>> runGen 42 (generate 10 20 ex1)
-- "ababab"
--
-- >>> runGen 44 (generate 10 20 ex1)
-- "abababababababababab"
--
ex1 :: RE Void
ex1 = star_ (ch_ 'a' <> ch_ 'b')

ex1run1 :: IO ()
ex1run1 = putLatexTrace ex1 "abab"

-------------------------------------------------------------------------------
-- * Example 2
-------------------------------------------------------------------------------

-- |
--
-- >>> match ex2 "aaa"
-- True
--
-- Note: how "sharing" is preserved.
--
-- >>> fromRE ex2
-- App (Ref 0 (Star (Ch "a"))) (Ref 0 (Star (Ch "a")))
--
-- >>> matchR ex2 "aaa"
-- True
--
-- >>> runGen 42 (generate 10 20 ex2)
-- "aaaaaaaaaaa"
--
-- >>> runGen 44 (generate 10 20 ex2)
-- "aaaaaaaaaa"
--
ex2 :: RE Void
ex2 = Let "r" (star_ (ch_ 'a')) (Var B <> Var B)

ex2run1 :: IO ()
ex2run1 = putLatexTrace ex2 "aaa"

-------------------------------------------------------------------------------
-- * Example 3
-------------------------------------------------------------------------------

-- |
--
-- >>> match ex3 "abab"
-- True
--
-- >>> match ex3 "ababa"
-- False
--
-- >>> fromRE ex3
-- Ref 0 (Alt Eps (App (Ch "a") (App (Ch "b") (Ref 0 ...))))
--
-- >>> matchR ex3 "abab"
-- True
--
-- >>> matchR ex3 "ababa"
-- False
--
-- >>> runGen 42 (generate 10 20 ex3)
-- "ab"
--
-- >>> runGen 50 (generate 10 20 ex3)
-- "ababab"
--
ex3 :: RE Void
ex3 = Fix "x" (Eps \/ ch_ 'a' <> ch_ 'b' <> Var B)

ex3run1 :: IO ()
ex3run1 = putLatexTrace ex3 "abab"

-------------------------------------------------------------------------------
-- * Example 4
-------------------------------------------------------------------------------

-- |
--
-- >>> match ex4 "aaaabbbb"
-- True
--
-- >>> matchR ex4 "aaaabbbb"
-- True
--
-- >>> runGen 42 (generate 10 20 ex4)
-- "aabb"
--
-- >>> runGen 45 (generate 10 20 ex4)
-- "aaabbb"
--
ex4 :: RE Void
ex4 = Fix "x" (Eps \/ ch_ 'a' <> Var B <> ch_ 'b')

ex4run1 :: IO ()
ex4run1 = putLatexTrace ex4 "aaaabbbb"

-------------------------------------------------------------------------------
-- * Example 5
-------------------------------------------------------------------------------

-- |
--
-- >>> match ex5 "abab"
-- True
--
-- >>> match ex5 "ababa"
-- False
--
-- >>> matchR ex5 "abab"
-- True
--
-- >>> matchR ex5 "ababa"
-- False
--
-- >>> runGen 42 (generate 10 20 ex5)
-- "ab"
--
-- >>> runGen 45 (generate 10 20 ex5)
-- "ababab"
--
ex5 :: RE Void
ex5 = Fix "x" (Eps \/ Var B <> ch_ 'a' <> ch_ 'b')

ex5run1 :: IO ()
ex5run1 = putLatexTrace ex5 "abab"

-------------------------------------------------------------------------------
-- * Example 6
-------------------------------------------------------------------------------

-- |
--
-- Using fix-point operator:
--
-- @
-- fix expr = "(" expr ")" | "1" | "2" | ... | "9" | expr "+" expr | expr "*" expr
-- @
--
-- which in BNF is almost he same
--
-- @
-- expr ::= "(" expr ")" | "1" | "2" | ... | "9" | expr "+" expr | expr "*" expr
-- @
--
-- >>> matchR ex6 "(1+2)*3"
-- True
--
-- >>> runGen 42 (generate 5 5 ex6)
-- "96+(09493+90790)*19"
--
ex6 :: RE Void
ex6 = Let "d" (Ch "0123456789")
    $ Let "n" (Var B <> star_ (Var B))
    $ Fix "e"
    $  ch_ '(' <> Var B <> ch_ ')'
    \/ Var (F B)
    \/ Var B <> ch_ '+' <> Var B
    \/ Var B <> ch_ '*' <> Var B

--
-- (displayTraced . traced) is "match" function, which
-- also prints the trace of execution.
--
-- True
ex6run1 :: IO ()
ex6run1 = putLatexTrace ex6 "1*(20+3)"

-------------------------------------------------------------------------------
-- * Example 7
-------------------------------------------------------------------------------

#ifdef RERE_CFG
exCfg :: Ord a => CFG N.Nat5 a
exCfg =
    digit ::: digits ::: term ::: mult ::: expr ::: VNil
  where
    expr = Alt (multV <> ch_ '*' <> exprV) multV
    mult = Alt (termV <> ch_ '+' <> multV) termV
    term = Alt digitsV (ch_ '(' <> exprV <> ch_ ')')

    digit = Ch "0123456789"
    digits = digitV <> star_ digitV

    digitV, digitsV, exprV, multV, termV :: CFGBase N.Nat5 a
    exprV   = Var $ Left F.fin4
    multV   = Var $ Left F.fin3
    termV   = Var $ Left F.fin2
    digitsV = Var $ Left F.fin1
    digitV  = Var $ Left F.fin0

exCfgN :: Vec N.Nat5 Name
exCfgN = "digit" ::: "digits" ::: "term" ::: "mult" ::: "expr" ::: VNil

-- |
--
-- >>> matchR ex7 "(1+2)*3"
-- True
--
-- >>> runGen 42 (generate 5 5 ex7)
-- "(0181+912595*00+((1228)+467+(80)+(216406))*(65)+4+5*5149+994734)"
--
ex7 :: Ord a => RE a
ex7 = cfgToRE exCfgN exCfg

-- ex7 :: RE Void
-- ex7 = Let "digit" (Ch '0' \/ Ch '1' \/ Ch '2' \/ Ch '3')
--     $ Let "digits" (Var B <> star (Var B))
--     $ Fix "expr"
--     $ Let "term" (Var (F B) \/ Ch '(' <> Var B <> Ch ')')
--     $ Let "mult" (Fix "mult" $ Var (F B) <> Ch '+' <> Var B \/ Var (F B))
--     $ Var B <> Ch '*' <> Var (F B) \/ Var B

ex7run1 :: IO ()
ex7run1 = ex7run "1*(20+3)"

ex7run :: String -> IO ()
ex7run str = putLatexTrace ex7 str
#endif

ex7parsec :: P.Parser ()
ex7parsec = expr where
    expr   = void $ P.try (mult >> P.char '*' >> expr) <|> mult
    mult   = void $ P.try (term >> P.char '+' >> mult) <|> term
    term   = P.try digits <|> void (P.char '(' *> expr *> P.char ')')
    digits = void $ some digit
    digit  = P.satisfy (\c -> c >= '0' && c <= '9')

ex7parsecRun :: IO ()
ex7parsecRun = P.parseTest ex7parsec "1*(20+3)"

-------------------------------------------------------------------------------
-- * Example 8
-------------------------------------------------------------------------------

#ifdef RERE_INTERSECTION
xnyn :: Name -> Char -> Char -> RE Void
xnyn n x y = Fix n (Eps \/ ch_ x <> Var B <> ch_ y)

ambncn :: RE Void
ambncn = star_ (ch_ 'a') <> xnyn "bc" 'b' 'c'

anbncm :: RE Void
anbncm = xnyn "ab" 'a' 'b' <> star_ (ch_ 'c')

-- |
--
-- >>> match ex8 "aabbcc"
-- True
--
-- >>> match ex8 "aabbccc"
-- False
--
-- >>> matchR ex8 "aabbcc"
-- True
--
-- >>> matchR ex8 "aabbccc"
-- False
--
-- >>> runGen 42 (generate 10 20 ex8)
-- "<<null>>"
--
ex8 :: RE Void
ex8 = ambncn /\ anbncm

ex8run1 :: IO ()
ex8run1 = putLatexTrace ex8 "aaabbbccc"

-- |
--
-- >>> matchR ex8b "aabbccaaabbbccc"
-- True
ex8b :: RE Void
ex8b = Fix "abc" (Eps \/ vacuous ex8 <> Var B)

ex8run2 :: IO ()
ex8run2 = putLatexTrace ex8b "aabbccaabbcc"

#endif
