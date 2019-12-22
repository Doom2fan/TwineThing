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

module twinevm.vm;

import std.algorithm : min, countUntil, swap;
import std.typecons : Tuple;
import std.format : format;
import std.variant : Algebraic;
import std.array : split;
import std.conv : to;

import chr_tools.stack;

import gamedata;
import utilities : wrap;

import twinevm.common;
import twinevm.twinevalue;
import twinevm.twinefunctions;

enum TwineVMState {
    Running,
    ScreenPause,
    WaitingForSelection,
    Stopped,
}

alias TwineSelection = Tuple!(string, "text", TwinePassage, "passage");

alias TwinePassageStack = Stack!(TwineStoredPassage, true);
alias TwineStoredPassage = Tuple!(TwinePassage, "passage", int, "command");

class TwineVirtualMachine {
    /* Game data */
    protected TwineGameData gameData;
    protected TwineValue[string] gameVariables;
    protected TwineFunctions gameFunctions;

    /* VM state */
    protected TwineVMState vmState;
    // Current passage
    protected TwinePassage curPassage;
    protected int curCommand;
    // Current text
    protected string curTextBuffer;
    protected string[] curTextLines;
    // Selections
    protected TwineSelection[] selections;
    // Passage call stack
    protected TwinePassageStack passageCallStack;

    /* Callbacks */
    public void delegate (string) setTextCallback;
    public void delegate (string) setImageCallback;
    public void delegate (string) setMusicCallback;
    public void delegate (string) showFatalErrorCallback;

    public this (TwineGameData data) {
        // Game data
        gameData = data;

        // VM state
        vmState = TwineVMState.Running;
        curPassage = gameData.passages ["Start"];
        curCommand = 0;
        curTextBuffer = null;
        curTextLines = null;
        selections = null;
        passageCallStack = new TwinePassageStack (10);
    }

    public TwineVMState getVMState () {
        return vmState;
    }

    public const (TwineSelection[]) getSelections () {
        return cast (const (TwineSelection[])) (selections);
    }

    public void playerInput (int selection) {
        if (vmState == TwineVMState.ScreenPause) {
            if (curTextLines.length < 1) {
                vmState = TwineVMState.Running;
                return;
            }
            showText ();
        }
    }

    protected void startShowText () {
        vmState = TwineVMState.ScreenPause;

        curTextLines = curTextBuffer.wrap (30).split ('\n');
        curTextBuffer = null;

        showText ();
    }

    protected void showText () {
        import std.array : join;

        auto text = curTextLines [0 .. min (6, $)];
        curTextLines = curTextLines [min (6, $) - 1 .. $];
        setTextCallback (text.join ('\n'));
    }

    protected void showFatalVMError (string error) {
        showFatalErrorCallback (error);
        vmState = TwineVMState.Stopped;
    }

    protected TwineValue evaluateExpression (TwineExpression expr) {
        if (auto intExpr = cast (TwineExpr_Integer) expr) {
            return TwineValue (intExpr.value);
        } else if (auto boolExpr = cast (TwineExpr_Bool) expr) {
            return TwineValue (boolExpr.value);
        } else if (auto strExpr = cast (TwineExpr_String) expr) {
            return TwineValue (strExpr.value);
        } else if (auto varExpr = cast (TwineExpr_Variable) expr) {
            if (auto varVal = varExpr.variableName in gameVariables)
                return *varVal;
            else
                return TwineValue ("");
        } else if (auto funcCallExpr = cast (TwineExpr_FunctionCall) expr) {
            TwineValue[] funcArgs = new TwineValue[funcCallExpr.args.length];
            for (int i = 0; i < funcCallExpr.args.length; i++)
                funcArgs [i] = evaluateExpression (funcCallExpr.args [i]);

            if (auto func = funcCallExpr.functionName in gameFunctions.functionList) {
                auto funcRet = (*func) (funcArgs);
                if (auto e = funcRet.peek!TwineVMException)
                    throw *e;

                return funcRet.get!TwineValue;
            }
        } else if (auto negExpr = cast (TwineExpr_Negate) expr) {
            auto val = evaluateExpression (negExpr.expr);
            return TwineValue (!(val.asBool ()));
        } else if (auto binExpr = cast (TwineBinaryExpression) expr) {
            auto lhs = evaluateExpression (binExpr.lhs);
            auto rhs = evaluateExpression (binExpr.lhs);

            alias TwineBinaryOp = Tuple!(string, "type", string, "op", string, "conv");
            static immutable (TwineBinaryOp[]) binaryOps = [
                TwineBinaryOp ("TwineExpr_Or"         , "||", ".asBool ()"),
                TwineBinaryOp ("TwineExpr_And"        , "&&", ".asBool ()"),
                // Comparisons
                TwineBinaryOp ("TwineExpr_Equals"     , "==", ""),
                TwineBinaryOp ("TwineExpr_NotEqual"   , "!=", ""),
                TwineBinaryOp ("TwineExpr_LesserThan" , "<" , ""),
                TwineBinaryOp ("TwineExpr_GreaterThan", ">" , ""),
                TwineBinaryOp ("TwineExpr_LesserEq"   , "<=", ""),
                TwineBinaryOp ("TwineExpr_GreaterEq"  , ">=", ""),
                // Arithmetics
                TwineBinaryOp ("TwineExpr_Add"        , "+" , ""),
                TwineBinaryOp ("TwineExpr_Subtract"   , "-" , ""),
                TwineBinaryOp ("TwineExpr_Multiply"   , "*" , ""),
                TwineBinaryOp ("TwineExpr_Division"   , "/" , ""),
                TwineBinaryOp ("TwineExpr_Remainder"  , "%" , ""),
            ];

            static foreach (exprType; binaryOps) {
                mixin ("if (auto isExpr = cast (" ~ exprType.type ~ ") binExpr)" ~
                    "return TwineValue (lhs" ~ exprType.conv ~ " " ~ exprType.op ~ " rhs" ~ exprType.conv ~ ");");
            }
        }

        assert (0);
    }

    public void run () {
        if (
            vmState == TwineVMState.ScreenPause ||
            vmState == TwineVMState.WaitingForSelection ||
            vmState == TwineVMState.Stopped
            )
            return;

        while (curCommand < curPassage.commands.length) {
            auto cmd = cast (const) curPassage.commands [curCommand];
            bool incrementCmdCounter = true;

            if (auto textCMD = cast (TwineCommand_PrintText) cmd) {
                curTextBuffer ~= textCMD.text;
            } else if (auto pauseCMD = cast (TwineCommand_Pause) cmd) {
                startShowText ();

                return;
            } else if (auto jumpCMD = cast (TwineCommand_JumpToPassage) cmd) {
                auto jumpTarget = (jumpCMD.targetPassage in gameData.passages); // @suppress(dscanner.suspicious.unmodified)

                if (!jumpTarget) {
                    showFatalVMError (format ("Unknown jump target \"%s\".", jumpCMD.targetPassage));
                    return;
                }

                curPassage = *jumpTarget;
                curCommand = 0;
            } else if (auto callCMD = cast (TwineCommand_CallPassage) cmd) {
                auto jumpTarget = (callCMD.targetPassage in gameData.passages); // @suppress(dscanner.suspicious.unmodified)

                if (!jumpTarget) {
                    showFatalVMError (format ("Unknown jump target \"%s\".", callCMD.targetPassage));
                    return;
                }

                passageCallStack.push (TwineStoredPassage (curPassage, curCommand));

                curPassage = *jumpTarget;
                curCommand = 0;
            } else if (auto returnCMD = cast (TwineCommand_ReturnPassage) cmd) {
                if (passageCallStack.isEmpty) {
                    showFatalVMError ("Tried to return on an empty call stack.");
                    return;
                }

                auto storedPassage = passageCallStack.pop (); // @suppress(dscanner.suspicious.unmodified)

                curPassage = storedPassage.passage;
                curCommand = storedPassage.command;
            } else if (auto setMusicCMD = cast (TwineCommand_SetMusic) cmd) {
                setMusicCallback (setMusicCMD.musicName);
            } else if (auto setImageCMD = cast (TwineCommand_SetImage) cmd) {
                setImageCallback (setImageCMD.imageName);
            } else if (auto addSelectionCMD = cast (TwineCommand_AddSelection) cmd) {
                auto jumpTarget = (gameData.passages [addSelectionCMD.targetPassage]); // @suppress(dscanner.suspicious.unmodified)

                if (!jumpTarget) {
                    showFatalVMError (format ("Unknown passage \"%s\" in selection.", addSelectionCMD.targetPassage));
                    return;
                }

                auto selection = TwineSelection ();

                selection.text = addSelectionCMD.selectionText;
                selection.passage = jumpTarget;

                selections ~= [ selection ];
            } else if (auto ifCMD = cast (TwineCommand_If) cmd) {
                incrementCmdCounter = false;

                try {
                    if ((evaluateExpression (ifCMD.condition).asBool) == false)
                        curCommand += ifCMD.jumpCount;
                } catch (TwineVMException e) {
                    showFatalVMError (cast (string) e.message);
                    return;
                }
            } else if (auto setVarCMD = cast (TwineCommands_SetVariable) cmd) {
                try {
                    gameVariables [setVarCMD.variableName] = evaluateExpression (setVarCMD.expression);
                } catch (TwineVMException e) {
                    showFatalVMError (cast (string) e.message);
                    return;
                }
            } else if (auto printCMD = cast (TwineCommand_PrintResult) cmd) {
                try {
                    curTextBuffer ~= evaluateExpression (printCMD.expression).asString ();
                } catch (TwineVMException e) {
                    showFatalVMError (cast (string) e.message);
                    return;
                }
            } else
                throw new TwineVMException (format ("Unknown command class \"%s\" encountered.", cmd.classinfo.name));

            if (incrementCmdCounter)
                curCommand++;
        }

        if (vmState == TwineVMState.WaitingForSelection) {

        } else
            vmState = TwineVMState.Stopped;
    }
}