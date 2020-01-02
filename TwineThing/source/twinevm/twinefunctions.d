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

module twinevm.twinefunctions;

import std.algorithm : swap;
import std.variant : Algebraic;
import std.typecons : Tuple;
import std.conv : to;

import twinevm.common;
import twinevm.twinevalue;


alias TwineExprReturn = Algebraic!(TwineValue, TwineVMException);
alias TwineFunction = TwineExprReturn delegate (TwineValue[]);

class TwineFunctions {
    alias DeclArg = Tuple!(TwineValueType, "type", string, "name");

    TwineFunction[string] functionList;

    final void addFunction (string name, TwineFunction func) {
        functionList [name] = func;
    }

    final TwineFunctions create () {
        auto funcs = new TwineFunctions ();
        funcs.addFunction ("random", &random);

        return funcs;
    }

    struct TwineFunctionDeclareArgs(DeclArg[] declArgs, string funcName = __FUNCTION__) {
        import std.array : split;

        private const {
            int _twineArgCount = declArgs.length;
            string _twineFuncName = funcName.split ('.') [1];
        }
        TwineVMException vmException;

        static foreach (arg; declArgs) {
            static if (arg.type == TwineValueType.Int)
                mixin ("int " ~ arg.name ~ ";");
            else static if (arg.type == TwineValueType.Bool)
                mixin ("bool " ~ arg.name ~ ";");
            else static if (arg.type == TwineValueType.String)
                mixin ("string " ~ arg.name ~ ";");
        }

        this (TwineValue[] passedArgs) {
            import std.algorithm : countUntil;
            import std.format : format;

            if (passedArgs.length != _twineArgCount) {
                auto message = format ("Incorrect argument count for function \"%s\" (got %d, expected %d)",
                    _twineFuncName,
                    passedArgs.length,
                    _twineArgCount
                );
                vmException = new TwineVMException (message);
                return;
            }

            static foreach (arg; declArgs) {
                if (passedArgs [countUntil (declArgs, arg)].type != arg.type) {
                    auto message = format ("Incorrect argument type for function \"%s\" (got %s, expected %s)",
                        _twineFuncName,
                        to!string (passedArgs [countUntil (declArgs, arg)].type),
                        to!string (arg.type)
                    );
                    vmException = new TwineVMException (message);
                    return;
                }

                static if (arg.type == TwineValueType.Int)
                    mixin (arg.name ~ " = passedArgs [" ~ to!string (countUntil (declArgs, arg)) ~ "].asInt ();");
                else static if (arg.type == TwineValueType.Bool)
                    mixin (arg.name ~ " = passedArgs [" ~ to!string (countUntil (declArgs, arg)) ~ "].asBool ();");
                else static if (arg.type == TwineValueType.String)
                    mixin (arg.name ~ " = passedArgs [" ~ to!string (countUntil (declArgs, arg)) ~ "].asString ();");
            }
        }
    }

    TwineExprReturn random (TwineValue[] passedArgs) {
        import std.random : uniform;

        auto args = new TwineFunctionDeclareArgs!([
            DeclArg (TwineValueType.Int, "min"),
            DeclArg (TwineValueType.Int, "max")
        ]) (passedArgs);

        if (args.vmException)
            return TwineExprReturn (args.vmException);

        int minNum = args.min;
        int maxNum = args.max;

        if (minNum > maxNum)
            swap (minNum, maxNum);

        TwineValue ret = uniform!("[]") (minNum, maxNum);
        return TwineExprReturn (ret);
    }
}