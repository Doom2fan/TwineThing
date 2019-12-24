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

module gamedata;

struct TwineGameInfo {
    string gameName = null;
    string tweePath = null;
    string fontPath = null;
}

class TwinePassage {
    string passageName;
    TwineCommand[] commands;
}

class TwineGameData {
    TwinePassage[string] passages;
}

// ======================================================================
//
// Commands
//
// ======================================================================
class TwineCommand {
}

class TwineCommand_PrintText : TwineCommand {
    string text;
}

class TwineCommand_Pause : TwineCommand {
}

class TwineCommand_JumpToPassage : TwineCommand {
    string targetPassage;
}

class TwineCommand_CallPassage : TwineCommand {
    string targetPassage;
}

class TwineCommand_ReturnPassage : TwineCommand {
}

class TwineCommand_SetMusic : TwineCommand {
    string musicName;
}

class TwineCommand_SetImage : TwineCommand {
    string imageName;
}

class TwineCommand_AddSelection : TwineCommand {
    string selectionText;
    string targetPassage;
}

class TwineCommand_If : TwineCommand {
    TwineExpression condition;
    int jumpCount;
}

class TwineCommands_SetVariable : TwineCommand {
    string variableName;
    TwineExpression expression;
}

class TwineCommand_PrintResult : TwineCommand {
    TwineExpression expression;
}

// ======================================================================
//
// Expressions
//
// ======================================================================
class TwineExpression {
}

abstract class TwineBinaryExpression {
    TwineExpression lhs;
    TwineExpression rhs;
}

class TwineExpr_Integer : TwineExpression {
    int value;
}

class TwineExpr_Bool : TwineExpression {
    int value;
}

class TwineExpr_String : TwineExpression {
    int value;
}

class TwineExpr_Variable : TwineExpression {
    string variableName;
}

class TwineExpr_FunctionCall : TwineExpression {
    string functionName;
    TwineExpression[] args;
}

class TwineExpr_Or : TwineBinaryExpression {
}

class TwineExpr_And : TwineBinaryExpression {
}

class TwineExpr_Negate : TwineExpression {
    TwineExpression expr;
}

class TwineExpr_Equals : TwineBinaryExpression {
}

class TwineExpr_NotEqual : TwineBinaryExpression {
}

class TwineExpr_LesserThan : TwineBinaryExpression {
}

class TwineExpr_GreaterThan : TwineBinaryExpression {
}

class TwineExpr_LesserEq : TwineBinaryExpression {
}

class TwineExpr_GreaterEq : TwineBinaryExpression {
}

class TwineExpr_Add : TwineBinaryExpression {
}

class TwineExpr_Subtract : TwineBinaryExpression {
}

class TwineExpr_Multiply : TwineBinaryExpression {
}

class TwineExpr_Division : TwineBinaryExpression {
}

class TwineExpr_Remainder : TwineBinaryExpression {
}