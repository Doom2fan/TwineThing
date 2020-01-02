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

static const int CharBlockSize = 8;

struct TwineGameInfo {
    string gameName = null;
    string tweePath;
    string fontPath;

    string selectionBeepPath;

    uint backgroundColour;
    uint textColour;

    int imageWidth;
    int imageHeight;

    int windowWidth;
    int windowHeight;

    int textStartHeight;

    int lineMaxLen;
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

    this (string newText) {
        text = newText;
    }
}

class TwineCommand_Pause : TwineCommand {
}

class TwineCommand_JumpToPassage : TwineCommand {
    string targetPassage;

    this (string target) {
        targetPassage = target;
    }
}

class TwineCommand_CallPassage : TwineCommand {
    string targetPassage;

    this (string target) {
        targetPassage = target;
    }
}

class TwineCommand_ReturnPassage : TwineCommand {
}

class TwineCommand_SetMusic : TwineCommand {
    string musicName;

    this (string name) {
        musicName = name;
    }
}

class TwineCommand_SetImage : TwineCommand {
    string imageName;

    this (string name) {
        imageName = name;
    }
}

class TwineCommand_AddSelection : TwineCommand {
    string selectionText;
    string targetPassage;

    this (string text, string target) {
        selectionText = text;
        targetPassage = target;
    }
}

class TwineCommand_If : TwineCommand {
    TwineExpression condition;
    int jumpCount;

    this (TwineExpression cond, int jmpCnt) {
        condition = cond;
        jumpCount = jmpCnt;
    }
}

class TwineCommands_SetVariable : TwineCommand {
    string variableName;
    TwineExpression expression;

    this (string name, TwineExpression expr) {
        variableName = name;
        expression = expr;
    }
}

class TwineCommand_PrintResult : TwineCommand {
    TwineExpression expression;

    this (TwineExpression expr) {
        expression = expr;
    }
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

    this () {
        
    }

    this (TwineExpression left, TwineExpression right) {
        lhs = left;
        rhs = right;
    }
}

class TwineExpr_Integer : TwineExpression {
    int value;

    this (int val) {
        value = val;
    }
}

class TwineExpr_Bool : TwineExpression {
    bool value;

    this (bool val) {
        value = val;
    }
}

class TwineExpr_String : TwineExpression {
    string value;

    this (string val) {
        value = val;
    }
}

class TwineExpr_Variable : TwineExpression {
    string variableName;

    this (string name) {
        variableName = name;
    }
}

class TwineExpr_FunctionCall : TwineExpression {
    string functionName;
    TwineExpression[] args;

    this (string name, TwineExpression[] argList) {
        functionName = name;
        args = argList;
    }
}

class TwineExpr_Or : TwineBinaryExpression {
}

class TwineExpr_And : TwineBinaryExpression {
}

class TwineExpr_Negate : TwineExpression {
    TwineExpression expression;

    this (TwineExpression expr) {
        expression = expr;
    }
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