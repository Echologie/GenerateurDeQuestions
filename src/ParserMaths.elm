module ParserMaths exposing (parseMaths, evaluer, montrerErreurs)

import Fractions as F
import Maybe as M
import Parser exposing (..)

montrerErreurs : String -> List DeadEnd -> String
montrerErreurs source errs =
    case List.head errs of
        Nothing ->
            ""

        Just firstErr ->
            source
                ++ "\n"
                ++ String.repeat (firstErr.col - 1) " "
                ++ "^"
                ++ "\nL'algorithme attendait :"
                ++ String.join
                    " ou "
                    (List.map displayExpected errs)


displayExpected : DeadEnd -> String
displayExpected err =
    case err.problem of
        ExpectingNumber ->
            "un nombre entier"
        ExpectingSymbol s ->
            "un \"" ++ s ++ "\""
        _ ->
            "une expression"


evaluer : Expr -> Maybe F.Frac
evaluer expression =
    case expression of
        Add a b ->
            M.map2 F.add (evaluer a) (evaluer b)

        Sub a b ->
            M.map2 F.sub (evaluer a) (evaluer b)

        Mul a b ->
            M.map2 F.mul (evaluer a) (evaluer b)

        Div a b ->
            M.map2 F.div (evaluer a) (evaluer b)

        Exp a b ->
            case M.map2 F.exp (evaluer a) (evaluer b) of
                Nothing -> Nothing
                Just p -> p

        Neg a ->
            M.map F.neg (evaluer a)

        Grouping l ->
            evaluer l

        Entier n ->
            Just <| F.Frac n 1


type Expr
    = Add Expr Expr
    | Sub Expr Expr
    | Mul Expr Expr
    | Div Expr Expr
    | Exp Expr Expr
    | Neg Expr
    | Entier Int
    | Grouping Expr


parseMaths : String -> Result (List DeadEnd) Expr
parseMaths source =
    run expr source


expr : Parser Expr
expr =
    add


type Operator
    = MulOp
    | DivOp
    | AddOp
    | SubOp
    | ExpOp


type Operand
    = NoOperand
    | Operand Operator Expr


binary : Expr -> Operand -> Expr
binary a b =
    case b of
        NoOperand ->
            a

        Operand op e ->
            case op of
                MulOp ->
                    Mul a e

                DivOp ->
                    Div a e

                AddOp ->
                    Add a e

                SubOp ->
                    Sub a e

                ExpOp ->
                    Exp a e


add : Parser Expr
add =
    succeed
        foldBinary
        |= mul
        |. spaces
        |= loop [] addHelper


foldBinary : Expr -> List Operand -> Expr
foldBinary left operands =
    List.foldr
    (\operand expression -> binary expression operand)
    left
    operands


addHelper : List Operand -> Parser (Step (List Operand) (List Operand))
addHelper operands =
    oneOf
        [ succeed (\right -> Loop (Operand AddOp right :: operands))
            |. symbol "+"
            |. spaces
            |= lazy (\_ -> mul)
        , succeed (\right -> Loop (Operand SubOp right :: operands))
            |. symbol "-"
            |. spaces
            |= lazy (\_ -> mul)
        , succeed ()
            |> map (\_ -> Done operands)
        ]


mul : Parser Expr
mul =
    succeed
        foldBinary
        |= exp
        |. spaces
        |= loop [] mulHelper


mulHelper : List Operand -> Parser (Step (List Operand) (List Operand))
mulHelper operands =
    oneOf
        [ succeed (\right -> Loop (Operand MulOp right :: operands))
            |. symbol "*"
            |. spaces
            |= lazy (\_ -> exp)
        , succeed (\right -> Loop (Operand DivOp right :: operands))
            |. symbol "/"
            |. spaces
            |= lazy (\_ -> exp)
        , succeed ()
            |> map (\_ -> Done operands)
        ]


exp : Parser Expr
exp =
    succeed
        binary
        |= primary
        |. spaces
        |= oneOf
            [ succeed (Operand ExpOp)
                |. symbol "^"
                |. spaces
                |= lazy (\_ -> exp)
            , succeed NoOperand
            ]


primary : Parser Expr
primary =
    succeed (\op literal ->
            case op of
                Nothing ->
                    literal

                Just _ ->
                    Neg literal
        )
    |= oneOf
        [ succeed Just
            |= symbol "-"
        , succeed Nothing
        ]
    |= oneOf
        [ grouping
        , nombre
        ]


nombre : Parser Expr
nombre =
    succeed Entier
        |= number
            { int = Just identity
            , hex = Nothing
            , octal = Nothing
            , binary = Nothing
            , float = Nothing
            }


grouping : Parser Expr
grouping =
    succeed Grouping
        |. symbol "("
        |. spaces
        |= lazy (\_ -> expr)
        |. spaces
        |. symbol ")"