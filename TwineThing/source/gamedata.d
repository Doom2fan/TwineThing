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

/// The size of each character block.
static const int CHARBLOCKSIZE = 8;

/// The Twine game info.
struct TwineGameInfo {
    /// The game's name.
    string gameName = null;
    /// The path to the game's .twee file.
    string tweePath;
    /// The path to the game's font.
    string fontPath;

    /// The path to the game's selection beep.
    string selectionBeepPath;

    /// The background colour of the game window.
    uint backgroundColour;
    /// The colour of the text.
    uint textColour;

    /// The width of the game image.
    int imageWidth;
    /// The height of the game image.
    int imageHeight;

    /// The width of the game window.
    int windowWidth;
    /// The height of the game window.
    int windowHeight;

    /// The starting height of the text. Obscures anything under it.
    int textStartHeight;

    /// The maximum length of a line.
    int lineMaxLen;
}

/// A Twine passage.
class TwinePassage {
    /// The name of the passage.
    string passageName;
    /// The passage's commands.
    TwineCommand[] commands;
}

/// The Twine game data.
class TwineGameData {
    /// The game's passages.
    TwinePassage[string] passages;
}

// ======================================================================
//
// Commands
//
// ======================================================================
/// A Twine VM command.
class TwineCommand {
}

/// Prints text to the screen.
class TwineCommand_PrintText : TwineCommand {
    /// The text to print.
    string text;

    this (string newText) { // @suppress(dscanner.style.undocumented_declaration)
        text = newText;
    }
}

/// Pauses the VM and displays the queued up text.
class TwineCommand_Pause : TwineCommand {
}

/// Jumps to the specified passage.
class TwineCommand_JumpToPassage : TwineCommand {
    /// The passage to jump to.
    string targetPassage;

    this (string target) { // @suppress(dscanner.style.undocumented_declaration)
        targetPassage = target;
    }
}

/// Calls the specified passage.
class TwineCommand_CallPassage : TwineCommand {
    /// The passage to call.
    string targetPassage;

    this (string target) { // @suppress(dscanner.style.undocumented_declaration)
        targetPassage = target;
    }
}

/// Returns to the previous passage from a call.
class TwineCommand_ReturnPassage : TwineCommand {
}

/// Sets the current music.
class TwineCommand_SetMusic : TwineCommand {
    /// The music to play.
    string musicName;

    this (string name) { // @suppress(dscanner.style.undocumented_declaration)
        musicName = name;
    }
}

/// Sets the current image.
class TwineCommand_SetImage : TwineCommand {
    /// The image to display.
    string imageName;

    this (string name) { // @suppress(dscanner.style.undocumented_declaration)
        imageName = name;
    }
}

/// Adds a selection.
class TwineCommand_AddSelection : TwineCommand {
    /// The selection's text.
    string selectionText;
    /// The passage to jump to.
    string targetPassage;

    this (string text, string target) { // @suppress(dscanner.style.undocumented_declaration)
        selectionText = text;
        targetPassage = target;
    }
}

/// An "if" conditional.
class TwineCommand_If : TwineCommand {
    /// The condition of the "if".
    TwineExpression condition;
    /// The amount of commands to jump over if the condition is false.
    int jumpCount;

    this (TwineExpression cond, int jmpCnt) { // @suppress(dscanner.style.undocumented_declaration)
        condition = cond;
        jumpCount = jmpCnt;
    }
}

/// Sets a variable to the value of the specified expression.
class TwineCommands_SetVariable : TwineCommand {
    /// The variable's name.
    string variableName;
    /// The expression to set the variable to.
    TwineExpression expression;

    this (string name, TwineExpression expr) { // @suppress(dscanner.style.undocumented_declaration)
        variableName = name;
        expression = expr;
    }
}

/// Prints the result of an expression to the screen.
class TwineCommand_PrintResult : TwineCommand {
    /// The expression to print.
    TwineExpression expression;

    this (TwineExpression expr) { // @suppress(dscanner.style.undocumented_declaration)
        expression = expr;
    }
}

// ======================================================================
//
// Expressions
//
// ======================================================================
/// A Twine VM expression.
class TwineExpression {
}

/// A binary expression.
abstract class TwineBinaryExpression : TwineExpression {
    /// The left-hand side of the expression.
    TwineExpression lhs;
    /// The right-hand side of the expression.
    TwineExpression rhs;
}

/// An unary expression.
abstract class TwineUnaryExpression : TwineExpression {
    /// The inner expression.
    TwineExpression expression;
}

/// An integer literal
class TwineExpr_Integer : TwineExpression {
    /// The value of the integer.
    int value;

    this (int val) { // @suppress(dscanner.style.undocumented_declaration)
        value = val;
    }
}

/// A boolean literal.
class TwineExpr_Bool : TwineExpression {
    /// The value of the boolean.
    bool value;

    this (bool val) { // @suppress(dscanner.style.undocumented_declaration)
        value = val;
    }
}

/// A string literal.
class TwineExpr_String : TwineExpression {
    /// The value of the string.
    string value;

    this (string val) { // @suppress(dscanner.style.undocumented_declaration)
        value = val;
    }
}

/// Gets the value of a variable.
class TwineExpr_Variable : TwineExpression {
    /// The variable's name.
    string variableName;

    this (string name) { // @suppress(dscanner.style.undocumented_declaration)
        variableName = name;
    }
}

/// Calls a function.
class TwineExpr_FunctionCall : TwineExpression {
    /// The name of the function.
    string functionName;
    /// The function's arguments.
    TwineExpression[] args;

    this (string name, TwineExpression[] argList) { // @suppress(dscanner.style.undocumented_declaration)
        functionName = name;
        args = argList;
    }
}

/// A logical OR operation.
class TwineExpr_Or : TwineBinaryExpression {
}

/// A logical AND operation.
class TwineExpr_And : TwineBinaryExpression {
}

/// A logical NOT operation.
class TwineExpr_LogicalNot : TwineUnaryExpression {
}

/// A negation operation.
class TwineExpr_Negate : TwineUnaryExpression {
}

/// An equality comparision operation.
class TwineExpr_Equals : TwineBinaryExpression {
}

/// An inequality comparision operation.
class TwineExpr_NotEqual : TwineBinaryExpression {
}

/// Compares two integers, returning true if lhs > rhs.
class TwineExpr_LesserThan : TwineBinaryExpression {
}

/// Compares two integers, returning true if lhs > rhs.
class TwineExpr_GreaterThan : TwineBinaryExpression {
}

/// Compares two integers, returning true if lhs <= rhs.
class TwineExpr_LesserEq : TwineBinaryExpression {
}

/// Compares two integers, returning true if lhs >= rhs.
class TwineExpr_GreaterEq : TwineBinaryExpression {
}

/// Sums two integers.
class TwineExpr_Add : TwineBinaryExpression {
}

/// Subtracts rhs from lhs.
class TwineExpr_Subtract : TwineBinaryExpression {
}

/// Multiplies lhs by rhs.
class TwineExpr_Multiply : TwineBinaryExpression {
}

/// Divides lhs by rhs.
class TwineExpr_Division : TwineBinaryExpression {
}

/// Returns the remainder of the division of lhs by rhs.
class TwineExpr_Remainder : TwineBinaryExpression {
}