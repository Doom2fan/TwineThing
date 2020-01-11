/*
 *  TwineThing
 *  Copyright (C) 2019 Chronos "phantombeta" Ouroboros
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

module twineparser.parserexpr;

import gamedata;
import twineparser.tokenizer;
import twineparser.parser;

alias ParserExprBinaryFunc = TwineExpression function (TwineExpression, TwineExpression);
alias ParserExprUnaryFunc = TwineExpression function (TwineExpression);
alias ParserExprAtomFunc = TwineExpression function (TwineParser, TwineToken);

package enum ParserExprType {
    Atom,
    Unary,
    Binary,
}

package struct ParserExprInput {
    TwineTokenType tok;
    string val;

    ParserExprBinaryFunc binaryExprFunc;
    ParserExprUnaryFunc unaryExprFunc;
    ParserExprAtomFunc atomExprFunc;
}

package struct ParserExpr {
    ParserExprType type;
    ParserExpr* lowerExpr;
    ParserExprInput[] acceptedInput;

    TwineTokenType[] acceptedTokens;
    ParserExprInput*[][TwineTokenType] inputsByToken;

    @disable this ();

    this (ParserExprType exprType, ParserExpr* lowerExprPtr, ParserExprInput[] acceptedInputArr)
    in {
        assert (exprType != ParserExprType.Atom || !lowerExprPtr, "Atom expressions cannot have lower expressions");
    } body {
        type = exprType;
        lowerExpr = lowerExprPtr;
        acceptedInput = acceptedInputArr;

        import std.algorithm : uniq;
        import std.array : appender;

        auto searchRange = uniq!("a.tok == b.tok") (acceptedInput);
        {
            auto app = appender!(TwineTokenType[]);

            foreach (expr; searchRange)
                app.put (expr.tok);

            acceptedTokens = app [];
        }

        for (int i = 0; i < acceptedInput.length; i++) {
            auto input = acceptedInput [i];
            assert (
                (exprType == ParserExprType.Binary && input.binaryExprFunc) ||
                (exprType == ParserExprType.Unary && input.unaryExprFunc) ||
                (exprType == ParserExprType.Atom && input.atomExprFunc)
            );

            auto arr = (input.tok in inputsByToken);

            if (!arr) {
                inputsByToken [input.tok] = new ParserExprInput*[0];
                arr = (input.tok in inputsByToken);
            }

            *arr ~= [ &(acceptedInput [i]) ];
        }
    }
}

package TwineExpression createExprInput_Binary(T) (TwineExpression lhs, TwineExpression rhs) {
    auto ret = new T ();
    ret.lhs = lhs;
    ret.rhs = rhs;
    return ret;
}

package TwineExpression createExprInput_Unary(T) (TwineExpression expr) {
    auto ret = new T ();
    ret.expression = expr;
    return ret;
}

package ParserExprInput createExprInput(T, TwineTokenType token, string value) () {
    ParserExprInput exprInput;

    exprInput.tok = token;
    exprInput.val = value;

    static if (is (T : TwineBinaryExpression))
        exprInput.binaryExprFunc = &(createExprInput_Binary!(T));
    else static if (is (T : TwineUnaryExpression))
        exprInput.unaryExprFunc = &(createExprInput_Unary!(T));
    else
        assert (0, "exprType must be unary or binary.");

    return exprInput;
}

package ParserExprInput createExprInput(T) (TwineTokenType token, string value, T func) {
    ParserExprInput exprInput;

    exprInput.tok = token;
    exprInput.val = value;

    static if (is (T : ParserExprBinaryFunc))
        exprInput.binaryExprFunc = cast (ParserExprBinaryFunc) func;
    else static if (is (T : ParserExprUnaryFunc))
        exprInput.unaryExprFunc = cast (ParserExprUnaryFunc) func;
    else static if (is (T : ParserExprAtomFunc))
        exprInput.atomExprFunc = cast (ParserExprAtomFunc) func;//exprInput.atomExprFunc = cast (ParserExprAtomFunc) func;
    else
        static assert (0, "Invalid function prototype");

    return exprInput;
}