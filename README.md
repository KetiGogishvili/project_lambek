# ChatLLaMbda: a natural language interface based on Lambek calculus

CSE301 project (individual), [Ketevan Gogishvili].

The program reads a lexicon (words with Lambek types and Python meanings) and a file of facts about a small world, and then lets the user type sentences. It decides whether each input is grammatical, builds every derivation as a lambda term, and evaluates each term in a Python interpreter to answer. Declarative sentences are answered with `True` or `False`, and "Who" questions with the list of matching individuals.

## How to build and run

Requirements: GHC, and `python3` on the PATH (the program starts `python3 -i`).

```bash
ghc ChatLLaMbda
./ChatLLaMbda
```

At the prompts, enter a lexicon file and a facts file, for example `school_questions.elx` and `schoolworld.py`. Then type sentences. Case and the punctuation `? ! . ,` are ignored.

Example session (school world):

```
> Alperen works
True
> every professor teaches a student
That sentence is ambiguous
Sense [Every_1 Professor_2 (\a. A_4 Student_5 (\b. Teaches_3 a b))]: True
Sense [A_4 Student_5 (\a. Every_1 Professor_2 (\b. Teaches_3 b a))]: False
> Who teaches Ketevan?
Noam, Sebastien
> Who does Noam teach?
Ketevan, Alperen, Matheus
> Who flies?
That is not a well-formed sentence
```

The two readings of the ambiguous sentence differ in which quantifier has wide scope. Each professor teaches some student (true), but no single student is taught by every professor (false).

## Files

| File | Role | Status |
|---|---|---|
| `Lambek.hs` | decision procedure and derivations as lambda terms | completed by me |
| `ChatLLaMbda.hs` | main program, evaluation, questions | modified by me |
| `school.elx` | second lexicon (students and professors), declarative sentences only | written by me |
| `school_questions.elx` | the same lexicon plus the entries for questions | written by me |
| `schoolworld.py` | facts for the school lexicon | written by me |
| `LTypes.hs`, `LExp.hs`, `Parser.hs`, `PySupport.hs` | types, lambda terms, lexicon parser, Python interface | template, unchanged |
| `animals.elx`, `aniworld.py` | example lexicon and facts | template, unchanged |

## How it works

### Step 1: deciding grammaticality (`Lambek.hs`)

The sequent calculus rules R, R′, F, L, L′ and X are implemented by two mutually recursive functions.

- `dec_rinv gamma b` handles the right rules. A goal `A \ B` or `B / A` is reduced by adding `A` to the left (rule R) or right (rule R′) end of the context. Once the goal is atomic, rule F tries every way of picking one type out of the context as the focus.
- `dec_lfoc gammaL a gammaR p` handles a focused type. A focus `A \ B` or `B / A` requires the types on the matching side to derive `A` (rules L and L′, trying every split of that side with the helper `splits`). An atomic focus succeeds only when both sides are empty and the atom equals the goal (rule X).
- `isGrammatical` looks up every entry of every word (case-insensitively, `typesFor`), tries every combination of one entry per word with `sequence`, and succeeds if some combination derives the sentence type.

### Step 2: derivations as lambda terms (`Lambek.hs`)

`der_rinv` and `der_lfoc` have the same structure but return lists of terms (`LExp`), following the annotated rules of the project description.

- Rules R and R′ build a lambda abstraction over a fresh variable (`freshVar`, which uses `fresh` from `LExp.hs`).
- Rules L and L′ derive an argument and put it at the front of the argument list.
- Rule X returns the empty argument list (the "hole"), and rule F fills the hole with the focused variable (`foldl A (V x) args`).

`derivationsWith` names each word of the sentence by its lexicon spelling and position (`Every_1`, `Cat_2`, ...) using `numbered`, derives all terms for every combination of lexicon entries, and returns each term together with the Python meanings of the entries it used. Several results mean the sentence is ambiguous.

### Step 3: evaluation with Python (`ChatLLaMbda.hs`)

- `toPython` translates a lambda term into one line of Python (`V x` is `x`, `A f a` is `f(a)`, `L x e` is `(lambda x: e)`).
- `pythonFor` wraps the translated term in an outer lambda whose parameters are the word variables and whose arguments are the Python meanings from the lexicon. For "Conor sleeps" it produces `(lambda Conor_1, Sleeps_2: Sleeps_2(Conor_1))(('Conor'), (lambda x : x in sleep))`. The meanings are passed as arguments and not pasted into the term, so they cannot capture names of the term's variables.
- `answer` runs each derivation with `runPythonCode`. One reading prints just the value. Several readings print "That sentence is ambiguous" and one `Sense [term]: value` line per reading (`printReadings`).

## Extension 1: a second domain

`school.elx` and `schoolworld.py` describe three students and three professors, with the verbs *works* and *teaches* (and *helps*), the adjectives *tired* and *clever*, and the quantifiers *someone*, *every* and *a*. They use the same types as `animals.elx` and run on the unchanged engine, which shows that the engine does not depend on the domain.

## Extension 2: questions

The interface now also answers "Who" questions: "Who is clever?", "Who teaches Ketevan?" (subject questions), and "Who does Noam teach?" (object question).

**Design.** A question is not true or false, so it gets its own atomic type `q`. The Lambek algorithm is unchanged. `answer` first tries to derive the sentence type `s`, and if there is no derivation, `answerQuestion` asks again with the goal type `q` (`lex { stp = Atm "q" }`).

**Lexicon entries** (in `school_questions.elx`):

```
Who   : q / (np \ s)         = lambda p : [x for x in people if p(x)].
Who   : q / (s / np)         = lambda p : [x for x in people if p(x)].
Does  : (s / np) / (s / np)  = lambda p : p.
Teach : np \ (s / np)        = lambda x : lambda y : (x,y) in teach.
Help  : np \ (s / np)        = lambda x : lambda y : (x,y) in assist.
```

- For a subject question ("Who sleeps?"), the verb phrase `np \ s` follows "Who", so `Who : q / (np \ s)`.
- For an object question ("Who does Conor fear?"), the part after "Who" is a sentence missing its object, which has type `s / np`, so `Who : q / (s / np)`.
- "Does" only makes the English grammatical. Its type `(s / np) / (s / np)` lets "does Conor fear" count as an `s / np`, and its meaning is the identity.
- `Teach` and `Help` are the base forms of the verbs, needed after "does".
- The meaning of `Who` is a list of answers. `pythonForQuestion` prints it as `a, b, c`, or `nobody` when the list is empty.

`removePunctuation` strips `? ! . ,` from the input so that "hungry?" matches the lexicon.

## Changes to the template

- `Lambek.hs`: implemented `dec_rinv`, `dec_lfoc`, `isGrammatical`, `der_rinv`, `der_lfoc` and the helpers `splits`, `typesFor`, `entriesFor`, `numbered`, `freshVar`, `derivationsWith`, `derivations`.
- `ChatLLaMbda.hs`: added `showDerivations` (kept for debugging), `toPython`, `meaningString`, `pythonFor`, `printReadings`, `answer`, `pythonForQuestion`, `printQuestionReadings`, `answerQuestion`, `removePunctuation`, and `import Data.List (intercalate)`. In `repl`, the call to `Lambek.isGrammatical` is replaced by `answer`, and the input goes through `removePunctuation`.
- No other template file was modified. (On older compilers GHC prints an "unrecognised warning flag" message for `LExp.hs`. It is harmless and I left the file as provided.)

## Limitations

- Ambiguity is purely syntactic. Sentences whose derivations are semantically equivalent (for example three clauses joined by "and") are still reported as ambiguous, and all senses are printed.
- If a Python meaning raises an error, for example because the facts file does not define a name that the lexicon uses, the program freezes: `runPythonCode` waits for an output line that never comes. Every name used in a meaning must be defined in the facts file.
- Nothing checks that a meaning has the shape promised by its type.
- Lexicon format: a word is one uppercase letter followed by lowercase letters, and a meaning cannot contain a `.` character (the parser ends a meaning at the first dot).
- Only "Who" questions are supported. Yes/no questions, "Who is a student?" and imperatives are not, and neither are explanations of why a sentence is true or false. "Who Conor fears" (without "does") is also accepted.
- The search tries every combination of lexicon entries, so words with several entries slow down long sentences. This is not a problem for the example sentences.

## AI-use acknowledgement

I used Claude AI while working on this project for looking up various built-in functions, debugging, testing and creating this README file. 

## References

- J. Lambek, "The Mathematics of Sentence Structure", American Mathematical Monthly 65(3), 1958.
- J. Lambek, "On the calculus of syntactic types", 1961.
- CSE301 project description and template code (instructor).
