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
    ParenOpen,
    ParenClose,
    Comma,
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
}

class TwineToken {
    TwineTokenType type;
    string value;

    string typeString () {
        switch (type) {

        case TwineTokenType.EOF: return "TOK_EOF";
        default:
        case TwineTokenType.Unknown: return "TOK_Unknown";
        }
    }
}

class TwineTokenizer {
    protected StringStream input;
    protected bool commandMode;

    public this (string input) {
        this.input = StringStream (input);
        commandMode = false;
    }

    protected void skipWhitespace () {
        while (isWhite (input.peek ()))
            input.read ();
    }

    TwineToken peek () {
        const (int) origPos = input.getPosition ();
        auto tok = next ();
        input.seek (origPos);

        return tok;
    }

    TwineToken [] peek (int count) {
        const (int) origPos = input.getPosition ();
        TwineToken [] tokens = new TwineToken [count];

        for (int i = 0; i < count; i++)
            tokens [count] = next ();

        input.seek (origPos);

        return tokens;
    }

    TwineToken next () {
        import std.uni : icmp;

        skipWhitespace ();
        auto tk = new TwineToken ();
        tk.type = TwineTokenType.Unknown;

        // Are we at the end of the stream?
        if (input.eof ()) {
            tk.type = TwineTokenType.EOF;
            return tk;
        }

        const (int) startPos = input.getPosition ();
        char c = input.read ();
        int curLen = 1;

        switch (c) {
            // String
            case '"': {
                if (!commandMode)
                    goto default;

                tk.type = TwineTokenType.String;

                do {
                    c = input.read ();
                    curLen++;

                    // Handle escape sequences
                    if (c == '\\') {
                        input.read ();
                        curLen++;
                    }
                } while (c != '"' && !input.eof ());
                break;
            }

            case '<': {
                auto peek = input.peek ();
                if (peek == '<') {
                    tk.type = TwineTokenType.CommandStart;
                    input.read ();
                    curLen++;
                    break;
                }

                if (!commandMode)
                    goto default;

                if (peek == '>') {
                    tk.type = TwineTokenType.NotEqualWeird;
                    input.read ();
                    curLen++;
                } else if (peek == '=') {
                    tk.type = TwineTokenType.LesserEqual;
                    input.read ();
                    curLen++;
                } else
                    tk.type = TwineTokenType.LesserThan;

                break;
            }

            case '>': {
                auto peek = input.peek ();
                if (peek == '>') {
                    tk.type = TwineTokenType.CommandEnd;
                    input.read ();
                    curLen++;
                    break;
                }

                if (!commandMode)
                    goto default;

                if (peek == '=') {
                    tk.type = TwineTokenType.GreaterEqual;
                    input.read ();
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
                    input.read ();
                    curLen++;
                } else
                    tk.type = TwineTokenType.Assign;

                break;
            }

            case '!': {
                if (!commandMode)
                    goto default;

                auto peek = input.peek ();
                if (peek == '=') {
                    tk.type = TwineTokenType.NotEqual;
                    input.read ();
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
                if (!commandMode)
                    tk.type = TwineTokenType.Asterisk;
                else
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
                    while (!input.eof ()) {
                        if (peek == '<') {
                            auto peek2 = input [startPos + curLen + 1]; // @suppress(dscanner.suspicious.unmodified)

                            if (peek2 == '<')
                                break;
                        }
                        if (peek == '[' || peek == ']' || peek == '|' || peek == '*')
                            break;

                        curLen++;
                        input.read ();
                        peek = input.peek ();
                    }
                    
                    break;
                }

                if (isAlpha (c) || c == '_') {
                    tk.type = TwineTokenType.Identifier;

                    char peek = input.peek ();
                    while (isAlphaNum (peek) || peek == '_') {
                        curLen++;
                        input.read ();
                        peek = input.peek ();
                    }
                } else if (isDigit (c)) {
                    tk.type = TwineTokenType.Number;

                    char peek = input.peek ();
                    while (isDigit (peek)) {
                        curLen++;
                        input.read ();
                        peek = input.peek ();
                    }
                } else
                    tk.type = TwineTokenType.Unknown;

                break;
            }
        }

        tk.value = input [startPos .. startPos + curLen];

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

    TwineToken [] next (int count) {
        TwineToken [] tokens = new TwineToken [count];

        for (int i = 0; i < count; i++)
            tokens [count] = next ();

        return tokens;
    }
}
