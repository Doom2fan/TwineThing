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

module twineparser.parser;

import std.array : appender;
import std.string : strip;

import gamedata;
import twineparser.tokenizer;

class TweeParserException : Exception {
    import std.typecons : Tuple;

    protected Tuple!(int, "line", int, "column") _position;

    this (string message, int errLine, int errColumn, string file = __FILE__, int _line = __LINE__) {
        super (message, file, _line);

        this._position.line = errLine;
        this._position.column = errColumn;
    }

    /**
     ** Gets the position (line and column) where the parsing expection
     ** has occured.
    */
    pure nothrow @property @safe @nogc auto position () {
        return this._position;
    }
}

class TweeParserException_UnexpectedToken : TweeParserException {
    this (TwineTokenType[] expected, TwineToken received, string file = __FILE__, int _line = __LINE__)
    in { assert (expected.length > 0); }
    body {
        auto app = appender!string;

        app.put ("Unexpected \"");
        app.put (received.value);
        app.put ("\", expected ");

        if (expected.length == 1)
            app.put (TwineToken.typeToString (expected [0]));
        else {
            app.put ("one of [ ");
            bool first = true;
            foreach (type; expected) {
                if (!first)
                    app.put (", ");

                app.put (TwineToken.typeToString (type));
                first = false;
            }
            app.put (" ]");
        }

        super (app [], received.line, received.column, file, _line);
    }
}

class TwineParser {
    protected {
        TwineTokenizer tokenizer;
        string curTokenizerInput;
    }

    this () {
        tokenizer = new TwineTokenizer ();
        curTokenizerInput = null;
    }

    protected struct ParserPassage {
        string passageName;
        string passageContents;
    }

    protected ParserPassage[] preprocessTweeFile (string input) {
        import stringstream : StringStream;

        StringStream stream = StringStream (input);

        ParserPassage[] passages;

        auto curPassage = ParserPassage ();
        int curContentStart;
        int curLabelLen = 0;

        // Ignore everything until we hit the first passage marker.
        while (!stream.eof ()) {
            auto curPos = stream.getPosition ();
            if (curPos == 0 || stream.peek () == '\n') {
                if (stream.peek () == '\n') {
                    stream.read ();
                    curPos++;
                }

                auto peek = stream [curPos .. curPos + 2];
                if (peek == "::") {
                    // Read the label markers and update the current position.
                    stream.read ();
                    stream.read ();
                    curPos = stream.getPosition ();

                    // Parse the passage label.
                    curLabelLen = 0;
                    while (stream.peek () != '\n') {
                        stream.read ();
                        curLabelLen++;
                    }

                    curPassage.passageName = strip (stream [curPos .. curPos + curLabelLen]);
                    stream.read (); // Read the newline.
                    curContentStart = stream.getPosition ();
                    break;
                } else if (curPos == 0)
                    stream.read ();
            } else
                stream.read ();
        }

        while (!stream.eof ()) {
            if (stream.read () == '\n') {
                auto curPos = stream.getPosition ();

                auto peek = stream [curPos .. curPos + 2];
                if (peek == "::") {
                    // Set the passage's contents.
                    curPassage.passageContents = stream [curContentStart .. curPos];

                    // Read the label markers and update the current position.
                    stream.read ();
                    stream.read ();
                    curPos = stream.getPosition ();

                    // Parse the passage label.
                    curLabelLen = 0;
                    while (stream.peek () != '\n') {
                        stream.read ();
                        curLabelLen++;
                    }

                    passages ~= curPassage;

                    curPassage = ParserPassage ();
                    curPassage.passageName = strip (stream [curPos .. curPos + curLabelLen]);
                    stream.read (); // Read the newline.
                    curContentStart = stream.getPosition ();
                }
            }
        }

        curPassage.passageContents = stream [curContentStart .. stream.getPosition () - 1];
        passages ~= curPassage;

        return passages;
    }

    protected void setTokenizerInput (string tkInput) {
        tokenizer.setInput (tkInput);
        curTokenizerInput = tkInput;
    }

    TwineGameData parseTweeFile (string input) {
        ParserPassage[] splitPassages = preprocessTweeFile (input); // @suppress(dscanner.suspicious.unmodified)

        auto gameData = new TwineGameData ();

        foreach (parserPassage; splitPassages) {
            auto passage = new TwinePassage ();
            passage.passageName = parserPassage.passageName;

            setTokenizerInput (parserPassage.passageContents);
            tokenizer.commandMode = false;

            parsePassage (passage);

            gameData.passages [parserPassage.passageName] = passage;
        }

        scope (exit)
            setTokenizerInput (null);

        return gameData;
    }

    void parsePassage (TwinePassage passage) {
        import std.array : appender;

        auto commands = parseCommands!(false) ();
        passage.commands = commands;
    }

    TwineToken readToken (TwineTokenType[] expected, bool peek = false, bool errorOut = true) () {
        TwineToken tk;
        static if (!peek)
            tk = tokenizer.next ();
        else
            tk = tokenizer.peek ();

        switch (tk.type) {
            static foreach (tkType; expected)
                case tkType:
            return tk;

            default:
                static if (errorOut)
                    throw new TweeParserException_UnexpectedToken (expected, tk);
                else
                    return TwineToken (); // Return an invalid token.
        }

        assert (0);
    }

    TwineCommand[] parseCommands(bool parsingIf) () {
        auto commands = appender!(TwineCommand[]);

        auto tk = tokenizer.next ();
        parseLoop:
        while (tk.type != TwineTokenType.EOF) {
            switch (tk.type) {
                case TwineTokenType.Text:
                    commands.put (new TwineCommand_PrintText (tk.value));
                    break;

                case TwineTokenType.CommandStart:
                    static if (parsingIf) {
                        tokenizer.commandMode = true;

                        auto tkPeek = readToken!([ TwineTokenType.Identifier ], true, false) ();
                        if (tkPeek.value == "endif") {
                            // Read the "endif" token.
                            tokenizer.next ();

                            // Read the ">>".
                            readToken!([ TwineTokenType.CommandEnd ]) ();

                            tokenizer.commandMode = false;
                            break parseLoop;
                        }

                        tokenizer.commandMode = false;
                    }

                    commands.put (parseCommand (tokenizer));
                    break;

                case TwineTokenType.Asterisk:
                    auto tkPeek = readToken!([ TwineTokenType.SpecialOpen ], true, false) ();
                    if ((tkPeek.startPos - (tk.startPos + tk.value.length)) == 1 &&
                        curTokenizerInput [tkPeek.startPos - 1] == ' '
                      ) {
                        // Read the "[" token.
                        tokenizer.next ();

                        // Read the other "[" token.
                        readToken!([ TwineTokenType.SpecialOpen ]) ();
                        // Read the selection text.
                        auto tkText = readToken!([ TwineTokenType.Text ]) ();
                        // Read the "|" token.
                        readToken!([ TwineTokenType.SpecialSeparator ]) ();
                        // Read the targetPassage.
                        auto tkTarget = readToken!([ TwineTokenType.Text ]) ();
                        // Read the two "]" tokens.
                        readToken!([ TwineTokenType.SpecialClose ]) ();
                        readToken!([ TwineTokenType.SpecialClose ]) ();

                        // Emit the command.
                        commands.put (new TwineCommand_AddSelection (tkText.value, tkTarget.value));
                    }
                    break;

                default:
                    throw new TweeParserException_UnexpectedToken (
                        [
                            TwineTokenType.Text,
                            TwineTokenType.CommandStart,
                            TwineTokenType.Asterisk,
                        ],
                        tk
                    );
            }

            tk = tokenizer.next ();
        }

        return commands [];
    }

    TwineCommand parseCommand (TwineTokenizer tokenizer) {
        return null;
    }
}
