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

module twineparser.tokenizer;

import std.ascii;
import std.format;
import std.conv;
import stringstream;

enum TwineTokenType {
    /* Both modes */
    CommandStart, // <<
    CommandEnd,   // >>

    /* Text mode */
    Text,             // .+ (basically)
    SpecialOpen,      // [
    SpecialClose,     // ]
    SpecialSeparator, // |
    Asterisk,         // *

    /* Command mode */
    // Basic
    Identifier, // [a-zA-Z_][a-zA-Z0-9_]+
    Number,     // [0-9]+
    String,     // "([^"]|\\")+"
    Assign,     // =
    // Function calls
    ParenOpen,  // (
    ParenClose, // )
    Comma,      // ,
    // Constants
    True,  // true
    False, // false
    // Logical ops
    Or,  // or
    And, // and
    Not, // not
    // Comparison ops
    Equals,        // ==
    Is,            // is
    NotEqual,      // !=
    NotEqualWeird, // <>
    LesserThan,    // <
    GreaterThan,   // >
    LesserEqual,   // <=
    GreaterEqual,  // >=
    // Arithmetic ops
    Add,       // +
    Subtract,  // -
    Multiply,  // *
    Divide,    // /
    Remainder, // %

    /* Markers */
    EOF,
    Unknown,
    Invalid,
}

/// A Twine token.
struct TwineToken {
    /// The type of the token.
    TwineTokenType type = TwineTokenType.Invalid;
    /// The value of the token.
    string value = null;

    /// The starting position of the token.
    int startPos = -1;
    /// The starting line of the token.
    int line = -1;
    /// The starting column of the token.
    int column = -1;

    /// Converts a TwineTokenType to a string representation of such a token.
    static string typeToString (TwineTokenType type) {
        switch (type) {
            /* Both modes */
            case TwineTokenType.CommandStart: return "<<";
            case TwineTokenType.CommandEnd  : return ">>";

            /* Text mode */
            case TwineTokenType.Text:             return "text";
            case TwineTokenType.SpecialOpen:      return "[";
            case TwineTokenType.SpecialClose:     return "]";
            case TwineTokenType.SpecialSeparator: return "|";
            case TwineTokenType.Asterisk:         return "*";

            /* Command mode */
            // Basic
            case TwineTokenType.Identifier: return "identifier";
            case TwineTokenType.Number:     return "number";
            case TwineTokenType.String:     return "string";
            case TwineTokenType.Assign:     return "=";
            // Function calls
            case TwineTokenType.ParenOpen:  return "(";
            case TwineTokenType.ParenClose: return ")";
            case TwineTokenType.Comma:      return ",";
            // Constants
            case TwineTokenType.True:  return "true";
            case TwineTokenType.False: return "false";
            // Logical ops
            case TwineTokenType.Or:  return "or";
            case TwineTokenType.And: return "and";
            case TwineTokenType.Not: return "not";
            // Comparison ops
            case TwineTokenType.Equals:        return "==";
            case TwineTokenType.Is:            return "is";
            case TwineTokenType.NotEqual:      return "!=";
            case TwineTokenType.NotEqualWeird: return "<>";
            case TwineTokenType.LesserThan:    return "<";
            case TwineTokenType.GreaterThan:   return ">";
            case TwineTokenType.LesserEqual:   return "<=";
            case TwineTokenType.GreaterEqual:  return ">=";
            // Arithmetic ops
            case TwineTokenType.Add:       return "+";
            case TwineTokenType.Subtract:  return "-";
            case TwineTokenType.Multiply:  return "*";
            case TwineTokenType.Divide:    return "/";
            case TwineTokenType.Remainder: return "%";

            /* Markers */
            case TwineTokenType.EOF: return "EOF";
            case TwineTokenType.Unknown: return "Unknown";

            default: assert (0, "Unimplemented token type");
        }
    }
}

/// The Twine tokenizer.
class TwineTokenizer {
    protected {
        StringStream input;
        int lineCount;
        int curLineStart;
    }

    /// Whether the tokenizer is in command mode.
    bool commandMode;
    /// Whether the tokenizer should ignore whitespace.
    bool ignoreWhitespace;

    /// Sets the current input.
    void setInput (string newInput) {
        input = StringStream (newInput);
        reset ();
    }

    /// Sets the current line count.
    void setLineCount (int count) {
        lineCount = count;
    }

    /// Resets the tokenizer.
    void reset () {
        input.seek (0);
        commandMode = false;
        ignoreWhitespace = false;

        lineCount = 1;
        curLineStart = 0;
    }

    /// Whether we've reached the end of the input.
    bool eof () {
        return input.eof ();
    }

    /// Reads a character from the input stream.
    char readChar () {
        const (char) c = input.read ();

        if (c == '\n') {
            curLineStart = input.getPosition ();
            lineCount++;
        }

        return c;
    }

    protected void skipWhitespace () {
        auto c = input.peek ();
        while (isWhite (c)) {
            readChar ();

            c = input.peek ();
        }
    }

    protected int getColumn (int curPos, int lineStart) const {
        return curPos - lineStart + 1;
    }

    /// Gets a token without advancing the tokenizer.
    TwineToken peek () {
        const (int) origPos = input.getPosition ();
        const (int) origLineCount = lineCount;
        const (int) origLineStart = curLineStart;

        auto tok = next ();

        input.seek (origPos);
        lineCount = origLineCount;
        curLineStart = origLineStart;

        return tok;
    }

    /// Gets the specified number of tokens without advancing the tokenizer.
    TwineToken[] peek (int count) {
        const (int) origPos = input.getPosition ();
        const (int) origLineCount = lineCount;
        const (int) origLineStart = curLineStart;

        TwineToken[] tokens = new TwineToken[count];

        for (int i = 0; i < count; i++)
            tokens [count] = next ();

        input.seek (origPos);
        lineCount = origLineCount;
        curLineStart = origLineStart;

        return tokens;
    }

    /// Reads a token.
    TwineToken next () {
        import std.uni : icmp;

        if (ignoreWhitespace || commandMode)
            skipWhitespace ();
        auto tk = TwineToken ();
        tk.type = TwineTokenType.Unknown;

        // Are we at the end of the stream?
        if (input.eof ()) {
            tk.type = TwineTokenType.EOF;

            tk.startPos = input.getPosition ();
            tk.line = lineCount;
            tk.column = getColumn (tk.startPos, curLineStart);

            return tk;
        }

        const (int) startPos = input.getPosition ();
        const (int) startLine = lineCount;
        const (int) startColumn = getColumn (startPos, curLineStart);
        char c = readChar ();
        int curLen = 1;

        switch (c) {
            // String
            case '"': {
                if (!commandMode)
                    goto default;

                tk.type = TwineTokenType.String;

                do {
                    c = readChar ();
                    curLen++;

                    // Handle escape sequences
                    if (c == '\\') {
                        readChar ();
                        curLen++;
                    }
                } while (c != '"' && !input.eof ());
                break;
            }

            case '<': {
                auto peek = input.peek ();
                if (peek == '<') {
                    tk.type = TwineTokenType.CommandStart;
                    readChar ();
                    curLen++;
                    break;
                }

                if (!commandMode)
                    goto default;

                if (peek == '>') {
                    tk.type = TwineTokenType.NotEqualWeird;
                    readChar ();
                    curLen++;
                } else if (peek == '=') {
                    tk.type = TwineTokenType.LesserEqual;
                    readChar ();
                    curLen++;
                } else
                    tk.type = TwineTokenType.LesserThan;

                break;
            }

            case '>': {
                auto peek = input.peek ();
                if (peek == '>') {
                    tk.type = TwineTokenType.CommandEnd;
                    readChar ();
                    curLen++;
                    break;
                }

                if (!commandMode)
                    goto default;

                if (peek == '=') {
                    tk.type = TwineTokenType.GreaterEqual;
                    readChar ();
                    curLen++;
                } else
                    tk.type = TwineTokenType.GreaterThan;

                break;
            }

            case '[': {
                if (!commandMode)
                    tk.type = TwineTokenType.SpecialOpen;

                break;
            }

            case ']': {
                if (!commandMode)
                    tk.type = TwineTokenType.SpecialClose;

                break;
            }

            case '|': {
                if (!commandMode)
                    tk.type = TwineTokenType.SpecialSeparator;

                break;
            }

            case '=': {
                if (!commandMode)
                    goto default;

                auto peek = input.peek ();
                if (peek == '=') {
                    tk.type = TwineTokenType.Equals;
                    readChar ();
                    curLen++;
                } else
                    tk.type = TwineTokenType.Assign;

                break;
            }

            case '(': {
                if (!commandMode)
                    goto default;

                tk.type = TwineTokenType.ParenOpen;

                break;
            }

            case ')': {
                if (!commandMode)
                    goto default;

                tk.type = TwineTokenType.ParenClose;

                break;
            }

            case ',': {
                if (!commandMode)
                    goto default;

                tk.type = TwineTokenType.Comma;

                break;
            }

            case '!': {
                if (!commandMode)
                    goto default;

                auto peek = input.peek ();
                if (peek == '=') {
                    tk.type = TwineTokenType.NotEqual;
                    readChar ();
                    curLen++;
                }

                break;
            }

            case '+': {
                if (!commandMode)
                    goto default;

                tk.type = TwineTokenType.Add;

                break;
            }

            case '-': {
                if (!commandMode)
                    goto default;

                tk.type = TwineTokenType.Subtract;

                break;
            }

            case '*': {
                if (!commandMode) {
                    if ((startPos - curLineStart) == 0)
                        tk.type = TwineTokenType.Asterisk;
                    else
                        goto default;
                } else
                    tk.type = TwineTokenType.Multiply;

                break;
            }

            case '/': {
                if (!commandMode)
                    goto default;

                tk.type = TwineTokenType.Divide;

                break;
            }

            case '%': {
                if (!commandMode)
                    goto default;

                tk.type = TwineTokenType.Remainder;

                break;
            }

            // Identifier and number
            case '_':
            default: {
                if (!commandMode) {
                    tk.type = TwineTokenType.Text;

                    char peek = input.peek ();
                    parseLoop:
                    while (!input.eof ()) {
                        if (peek == '<') {
                            auto peek2 = input [startPos + curLen + 1]; // @suppress(dscanner.suspicious.unmodified)

                            if (peek2 == '<')
                                break parseLoop;
                        }
                        if (peek == '>') {
                            auto peek2 = input [startPos + curLen + 1]; // @suppress(dscanner.suspicious.unmodified)

                            if (peek2 == '>')
                                break parseLoop;
                        }

                        if (peek == '[' || peek == ']' || peek == '|' || peek == '*')
                            break parseLoop;

                        curLen++;
                        readChar ();

                        peek = input.peek ();
                    }

                    break;
                }

                if (isAlpha (c) || c == '_') {
                    tk.type = TwineTokenType.Identifier;

                    char peek = input.peek ();
                    while (isAlphaNum (peek) || peek == '_') {
                        curLen++;
                        readChar ();
                        peek = input.peek ();
                    }
                } else if (isDigit (c)) {
                    tk.type = TwineTokenType.Number;

                    char peek = input.peek ();
                    while (isDigit (peek)) {
                        curLen++;
                        readChar ();
                        peek = input.peek ();
                    }
                } else
                    tk.type = TwineTokenType.Unknown;

                break;
            }
        }

        tk.value = input [startPos .. startPos + curLen];
        tk.startPos = startPos;
        tk.line = startLine;
        tk.column = startColumn;

        if (tk.type == TwineTokenType.Identifier) {
            if (icmp (tk.value, "true") == 0)
                tk.type = TwineTokenType.True;
            else if (icmp (tk.value, "false") == 0)
                tk.type = TwineTokenType.False;
            else if (icmp (tk.value, "or") == 0)
                tk.type = TwineTokenType.Or;
            else if (icmp (tk.value, "and") == 0)
                tk.type = TwineTokenType.And;
            else if (icmp (tk.value, "not") == 0)
                tk.type = TwineTokenType.Not;
            else if (icmp (tk.value, "is") == 0)
                tk.type = TwineTokenType.Is;
        }

        return tk;
    }

    /// Reads the specified number of tokens.
    TwineToken[] next (int count) {
        TwineToken[] tokens = new TwineToken[count];

        for (int i = 0; i < count; i++)
            tokens [count] = next ();

        return tokens;
    }
}
