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

import std.algorithm : min;
import std.array : appender;
import std.conv : to;
import std.string : strip, stripRight;
import std.typecons : Tuple;

import gamedata;
import twineparser.tokenizer;
import twineparser.parserexpr;

/// An exception raised when an error is encountered while parsing the .twee file.
class TweeParserException : Exception {
    protected Tuple!(int, "line", int, "column") _position;
    /// The name of the passage that was being parsed.
    string passageName;

    this (string message, int errLine, int errColumn, string file = __FILE__, int _line = __LINE__) { // @suppress(dscanner.style.undocumented_declaration)
        super (message, file, _line);

        this._position.line = errLine;
        this._position.column = errColumn;
    }

    /**
     ** Gets the position (line and column) where the parsing expection
     ** has occured.
    */
    pure nothrow @property @safe @nogc auto ref position () {
        return this._position;
    }
}

/// An exception raised when an unexpected token is encountered while parsing the .twee file.
class TweeParserException_UnexpectedToken : TweeParserException {
    /// The list of expected tokens.
    TwineTokenType[] expectedTokens;
    /// The received token.
    TwineToken receivedToken;

    this (TwineTokenType[] expected, TwineToken received, string psgName,
          string file = __FILE__, int _line = __LINE__
        ) { // @suppress(dscanner.style.undocumented_declaration)
        super ("", received.line, received.column, file, _line);

        expectedTokens = expected;
        receivedToken = received;
        passageName = psgName;
    }

    override const (char)[] message () const {
        auto app = appender!string;

        app.put ("Unexpected \"");
        app.put (receivedToken.value);
        app.put ("\" (");
        app.put (to!string (receivedToken.type));
        if (expectedTokens && expectedTokens.length > 0) {
            app.put ("), expected ");

            if (expectedTokens.length == 1)
                app.put (TwineToken.typeToString (expectedTokens [0]));
            else {
                app.put ("one of [ ");
                bool first = true;
                foreach (type; expectedTokens) {
                    if (!first)
                        app.put (", ");

                    app.put (TwineToken.typeToString (type));
                    first = false;
                }
                app.put (" ]");
            }
        } else
            app.put (")");

        return app [];
    }
}

/// An exception raised when an unclosed "if" command is encountered while parsing the .twee file.
class TweeParserException_UnclosedIf : TweeParserException {
    /// The token of the unclosed "if" command.
    TwineToken ifToken;

    this (TwineToken ifTok, string psgName, string file = __FILE__, int _line = __LINE__) { // @suppress(dscanner.style.undocumented_declaration)
        super ("Unclosed \"if\"", ifTok.line, ifTok.column, file, _line);

        ifToken = ifTok;
        passageName = psgName;
    }
}

/// An exception raised when an unknown command or special is encountered while parsing the .twee file.
class TweeParserException_UnknownCommand : TweeParserException {
    /// The name of the command or special.
    string commandName;
    /// Whether it was a command or a special.
    bool isSpecial;

    this (TwineToken cmdTok, bool special, string psgName, string file = __FILE__, int _line = __LINE__) { // @suppress(dscanner.style.undocumented_declaration)
        super ("", cmdTok.line, cmdTok.column, file, _line);

        commandName = cmdTok.value;
        isSpecial = special;
        passageName = psgName;
    }

    override const (char)[] message () const {
        auto app = appender!string;


        app.put ("Unknown ");
        app.put (isSpecial ? "special" : "command");
        app.put (" \"");
        app.put (commandName);
        app.put ("\"");

        return app [];
    }
}

/// A Twine parser.
class TwineParser {
    protected {
        TwineTokenizer tokenizer;
        ParserPassage* curParserPassage;
        ParserExpr atomExpr;
        ParserExpr unaryExpr;
        ParserExpr mulDivExpr;
        ParserExpr addSubExpr;
        ParserExpr comparisonExpr;
        ParserExpr equalityExpr;
        ParserExpr condExpr;
    }

    this () { // @suppress(dscanner.style.undocumented_declaration)
        tokenizer = new TwineTokenizer ();
        curParserPassage = null;

        atomExpr = ParserExpr (ParserExprType.Atom, null, [
            createExprInput (TwineTokenType.Identifier, null, &parseAtomExpr_VariableOrCall),
            createExprInput (TwineTokenType.String, null,
                (TwineParser p, TwineToken token) => new TwineExpr_String (token.value [1 .. $-1]) // @suppress(dscanner.suspicious.unused_parameter)
            ),
            createExprInput (TwineTokenType.Number, null,
                (TwineParser p, TwineToken token) => new TwineExpr_Integer (to!int (token.value)) // @suppress(dscanner.suspicious.unused_parameter)
            ),
            createExprInput (TwineTokenType.True, null,
                (TwineParser p, TwineToken t) => new TwineExpr_Bool (true) // @suppress(dscanner.suspicious.unused_parameter)
            ),
            createExprInput (TwineTokenType.False, null,
                (TwineParser p, TwineToken t) => new TwineExpr_Bool (false) // @suppress(dscanner.suspicious.unused_parameter)
            ),
        ]);
        unaryExpr = ParserExpr (ParserExprType.Unary, &atomExpr, [
            createExprInput!(TwineExpr_LogicalNot, TwineTokenType.Identifier, "not") (),
            createExprInput!(TwineExpr_Negate, TwineTokenType.Subtract  , null ) (),
        ]);
        mulDivExpr = ParserExpr (ParserExprType.Binary, &unaryExpr, [
            createExprInput!(TwineExpr_Multiply , TwineTokenType.Multiply , null) (),
            createExprInput!(TwineExpr_Division , TwineTokenType.Divide   , null) (),
            createExprInput!(TwineExpr_Remainder, TwineTokenType.Remainder, null) (),
        ]);
        addSubExpr = ParserExpr (ParserExprType.Binary, &mulDivExpr, [
            createExprInput!(TwineExpr_Add     , TwineTokenType.Add     , null) (),
            createExprInput!(TwineExpr_Subtract, TwineTokenType.Subtract, null) (),
        ]);
        comparisonExpr = ParserExpr (ParserExprType.Binary, &addSubExpr, [
            createExprInput!(TwineExpr_LesserThan , TwineTokenType.LesserThan  , null) (),
            createExprInput!(TwineExpr_GreaterThan, TwineTokenType.GreaterThan , null) (),
            createExprInput!(TwineExpr_LesserEq   , TwineTokenType.LesserEqual , null) (),
            createExprInput!(TwineExpr_GreaterEq  , TwineTokenType.GreaterEqual, null) (),
        ]);
        equalityExpr = ParserExpr (ParserExprType.Binary, &comparisonExpr, [
            createExprInput!(TwineExpr_Equals  , TwineTokenType.Equals       , null) (),
            createExprInput!(TwineExpr_Equals  , TwineTokenType.Is           , null) (),
            createExprInput!(TwineExpr_NotEqual, TwineTokenType.NotEqual     , null) (),
            createExprInput!(TwineExpr_NotEqual, TwineTokenType.NotEqualWeird, null) (),
        ]);
        condExpr = ParserExpr (ParserExprType.Binary, &equalityExpr, [
            createExprInput!(TwineExpr_Or , TwineTokenType.Or , null) (),
            createExprInput!(TwineExpr_And, TwineTokenType.And, null) (),
        ]);
    }

    protected alias ParserPassage = Tuple!(string, "passageName", string, "passageContents", int, "lineCountOffset");

    protected ParserPassage[] preprocessTweeFile (string input) {
        import std.array : replace;
        import stringstream : StringStream;

        input = input.replace ("\r\n", "\n");
        input = input.replace ("\r", "\n");

        StringStream stream = StringStream (input);

        ParserPassage[] passages;

        auto curPassage = ParserPassage ();
        int curContentStart = -1;
        int curLabelLen = 0;
        int lineCount = 1;

        // Ignore everything until we hit the first passage marker.
        while (!stream.eof ()) {
            auto curPos = stream.getPosition ();

            if (curPos == 0 || stream.peek () == '\n') {
                if (stream.peek () == '\n') {
                    stream.read ();
                    curPos++;
                    lineCount++;
                }

                auto peek = stream [curPos .. min (curPos + 2, $)];
                if (peek == "::") {
                    // Finish the previous passage, if any.
                    if (curContentStart > -1) {
                        curPassage.passageContents = stripRight (stream [curContentStart .. curPos], " \r\n");
                        passages ~= curPassage;
                    }

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

                    stream.read (); // Read the newline.
                    lineCount++;
                    curPassage.passageName = strip (stream [curPos .. curPos + curLabelLen]);
                    curPassage.lineCountOffset = lineCount;
                    curContentStart = stream.getPosition ();
                } else if (curPos == 0)
                    stream.read ();
            } else
                stream.read ();
        }

        if (curContentStart > -1) {
            curPassage.passageContents = stripRight (stream [curContentStart .. stream.getPosition ()], " \r\n");
            passages ~= curPassage;
        }

        return passages;
    }

    protected void setTokenizerInput (ParserPassage* passage) {
        if (!passage) {
            tokenizer.setInput (null);
            curParserPassage = null;
            return;
        }

        tokenizer.setInput (passage.passageContents);
        curParserPassage = passage;
    }

    /// Parses the .twee file contained in the input string.
    TwineGameData parseTweeFile (string input) {
        ParserPassage[] splitPassages = preprocessTweeFile (input); // @suppress(dscanner.suspicious.unmodified)

        auto gameData = new TwineGameData ();

        foreach (parserPassage; splitPassages) {
            auto passage = new TwinePassage ();
            passage.passageName = parserPassage.passageName;

            setTokenizerInput (&parserPassage);
            tokenizer.setLineCount (curParserPassage.lineCountOffset);
            tokenizer.commandMode = false;

            parsePassage (passage);

            gameData.passages [parserPassage.passageName] = passage;
        }

        scope (exit)
            setTokenizerInput (null);

        return gameData;
    }

    void parsePassage (TwinePassage passage) {
        auto commands = parseCommands!(false) ();
        passage.commands = commands;
    }

    TwineToken readToken(TwineTokenType[] expected, bool peek = false, bool errorOut = true) () {
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
                    throw new TweeParserException_UnexpectedToken (expected, tk, curParserPassage.passageName);
                else
                    return TwineToken (); // Return an invalid token.
        }

        assert (0);
    }

    /// Reads a token from the current passage.
    TwineToken readToken(bool peek = false, bool errorOut = true) (TwineTokenType[] expected) {
        TwineToken tk;
        static if (!peek)
            tk = tokenizer.next ();
        else
            tk = tokenizer.peek ();

        foreach (tkType; expected) {
            if (tk.type == tkType)
                return tk;
        }

        static if (errorOut)
            throw new TweeParserException_UnexpectedToken (expected, tk, curParserPassage.passageName);
        else
            return TwineToken (); // Return an invalid token.
    }

    TwineCommand[] parseCommands(bool parsingIf) () {
        auto commands = appender!(TwineCommand[]);

        parseLoop:
        do {
            tokenizer.commandMode = false;

            auto tk = readToken!([ TwineTokenType.Text, TwineTokenType.CommandStart, TwineTokenType.SpecialOpen,
                TwineTokenType.Asterisk, TwineTokenType.EOF
            ]) ();

            switch (tk.type) {
                case TwineTokenType.Text:
                    commands.put (new TwineCommand_PrintText (tk.value));
                    break;

                case TwineTokenType.CommandStart:
                    static if (parsingIf) {
                        tokenizer.commandMode = true;

                        auto tkPeek = cast (const) readToken!([ TwineTokenType.Identifier ], true, false) ();
                        if (tkPeek.type != TwineTokenType.Invalid && tkPeek.value == "endif") {
                            // Read the "endif" token.
                            readToken!([ TwineTokenType.Identifier ]) ();
                            // Read the ">>".
                            auto tkClose = cast (const) readToken!([ TwineTokenType.CommandEnd ]) ();
                            // Remove any newline right after the command.
                            int curPos = cast (const) (tkClose.startPos + tkClose.value.length);
                            if (!tokenizer.eof () && curParserPassage.passageContents [curPos] == '\n')
                                tokenizer.readChar ();

                            tokenizer.commandMode = false;
                            break parseLoop;
                        }

                        tokenizer.commandMode = false;
                    }

                    commands.put (parseCommand ());
                    break;

                case TwineTokenType.SpecialOpen:
                    commands.put (parseSpecial ());
                    break;

                case TwineTokenType.Asterisk:
                    tokenizer.ignoreWhitespace = true;
                    auto tkPeek = readToken!([ TwineTokenType.SpecialOpen ], true, false) ();
                    tokenizer.ignoreWhitespace = false;
                    if (tkPeek.type != TwineTokenType.Invalid &&
                        (tkPeek.startPos - (tk.startPos + tk.value.length)) == 1 &&
                        curParserPassage.passageContents [tkPeek.startPos - 1] == ' '
                      ) {
                        tokenizer.ignoreWhitespace = true;

                        // Read the "[" token.
                        readToken!([ TwineTokenType.SpecialOpen ]) ();
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
                        auto tkClose = readToken!([ TwineTokenType.SpecialClose ]) ();

                        // Ensure there's a newline at the end.
                        if (!tokenizer.eof () && curParserPassage.passageContents [tkClose.startPos + 1] != '\n') {
                            throw new TweeParserException ("Expected new line after selection",
                                tkPeek.line, tkPeek.column
                            );
                        }

                        tokenizer.readChar ();

                        tokenizer.ignoreWhitespace = false;

                        // Emit the command.
                        commands.put (new TwineCommand_AddSelection (tkText.value, tkTarget.value));
                    } else
                        goto case TwineTokenType.Text;
                    break;

                case TwineTokenType.EOF:
                    static if (parsingIf)
                        return null;
                    else
                        break parseLoop;

                default:
                    assert (0);
            }
        } while (true);

        return commands [];
    }

    TwineCommand[] parseCommand () {
        TwineCommand[] ret = null;
        bool doReadCommandEnd = true;

        // Enable command mode.
        tokenizer.commandMode = true;
        // Read the command's name.
        auto tkCmdName = readToken!([ TwineTokenType.Identifier ]) ();

        switch (tkCmdName.value) {
            case "pause":
                ret = [ new TwineCommand_Pause () ];
                break;

            case "jump": {
                    // Disable command mode.
                    tokenizer.commandMode = false;
                    tokenizer.ignoreWhitespace = true;
                    // Read the target passage's name.
                    auto tkTargetName = readToken!([ TwineTokenType.Text ]) ();
                    // Enable command mode.
                    tokenizer.commandMode = true;
                    tokenizer.ignoreWhitespace = false;

                    ret = [ new TwineCommand_JumpToPassage (tkTargetName.value) ];
                }
                break;

            case "call": {
                    // Disable command mode.
                    tokenizer.commandMode = false;
                    tokenizer.ignoreWhitespace = true;
                    // Read the target passage's name.
                    auto tkTargetName = readToken!([ TwineTokenType.Text ]) ();
                    // Enable command mode.
                    tokenizer.commandMode = true;
                    tokenizer.ignoreWhitespace = false;

                    ret = [ new TwineCommand_CallPassage (tkTargetName.value) ];
                }
                break;

            case "return":
                ret = [ new TwineCommand_ReturnPassage () ];
                break;

            case "music": {
                    // Read the music's name.
                    auto tkMusicName = readToken!([ TwineTokenType.String ]) ();

                    TwineExpression trackNum = null;
                    // Check if the next token is a comma, and if so, parse the track number.
                    auto peek = readToken!([ TwineTokenType.Comma ], true, false) ();
                    if (peek.type != TwineTokenType.Invalid) {
                        // Read the comma.
                        readToken!([ TwineTokenType.Comma ]) ();
                        // Parse the track number expression.
                        trackNum = parseExpression ();
                    } else
                        trackNum = new TwineExpr_Integer (0);

                    ret = [ new TwineCommand_SetMusic (tkMusicName.value [1 .. $-1], trackNum) ];
                }
                break;

            case "if": {
                    // Read the music's name.
                    auto cond = parseExpression ();
                    // Read the closing ">>" token.
                    auto tkClose = cast (const) readToken!([ TwineTokenType.CommandEnd ]) ();
                    doReadCommandEnd = false;

                    // Remove any newline right after the command.
                    int curPos = cast (const) (tkClose.startPos + tkClose.value.length);
                    if (!tokenizer.eof () && curParserPassage.passageContents [curPos] == '\n')
                        tokenizer.readChar ();

                    // Read the "if" command's commands
                    auto ifCMDs = parseCommands!(true) ();

                    if (!ifCMDs)
                        throw new TweeParserException_UnclosedIf (tkCmdName, curParserPassage.passageName);

                    ret = new TwineCommand[ifCMDs.length + 1];
                    ret [0] = new TwineCommand_If (cond, ifCMDs.length+1);
                    ret [1 .. $] = ifCMDs [];
                }
                break;

            case "set": {
                    // Read the variable's name.
                    auto tkVarName = readToken!([ TwineTokenType.Identifier ]) ();
                    // Read the "=" token.
                    readToken!([ TwineTokenType.Assign ]) ();
                    // Parse the expression.
                    auto expr = parseExpression ();

                    ret = [ new TwineCommands_SetVariable (tkVarName.value, expr) ];
                }
                break;

            case "print": {
                    // Parse the expression.
                    auto expr = parseExpression ();

                    readToken!([ TwineTokenType.CommandEnd ]) ();
                    doReadCommandEnd = false;

                    ret = [ new TwineCommand_PrintResult (expr) ];
                }
                break;

            default:
                throw new TweeParserException_UnknownCommand (tkCmdName, false, curParserPassage.passageName);
        }

        // Disable command mode.
        tokenizer.commandMode = false;
        // Read the closing ">>" token.
        if (doReadCommandEnd) {
            auto tkClose = cast (const) readToken!([ TwineTokenType.CommandEnd ]) ();

            // Remove any newline right after the command.
            int curPos = cast (const) (tkClose.startPos + tkClose.value.length);
            if (!tokenizer.eof () && curParserPassage.passageContents [curPos] == '\n')
                tokenizer.readChar ();
        }

        return ret;
    }

    TwineCommand[] parseSpecial () {
        TwineCommand[] ret = null;

        // Read the special's name.
        tokenizer.commandMode = true;
        auto tkSpcName = readToken!([ TwineTokenType.Identifier ]) ();
        tokenizer.commandMode = false;

        switch (tkSpcName.value) {
            case "img": {
                    // Read the "[" token.
                    readToken!([ TwineTokenType.SpecialOpen ]) ();
                    // Read the image's name.
                    auto tkImgName = readToken!([ TwineTokenType.Text ]) ();
                    // Read the "]" token.
                    readToken!([ TwineTokenType.SpecialClose ]) ();

                    ret = [ new TwineCommand_SetImage (tkImgName.value) ];
                }
                break;

            default:
                throw new TweeParserException_UnknownCommand (tkSpcName, true, curParserPassage.passageName);
        }

        // Read the closing "]" token.
        auto tkClose = readToken!([ TwineTokenType.SpecialClose ]) ();
        // Remove any newline right after the special.
        int curPos = cast (const) (tkClose.startPos + tkClose.value.length);
        if (!tokenizer.eof () && curParserPassage.passageContents [curPos] == '\n')
            tokenizer.readChar ();

        return ret;
    }

    static TwineExpression parseAtomExpr_VariableOrCall (TwineParser parser, TwineToken idTok) {
        auto parenPeek = cast (const) parser.readToken!([ TwineTokenType.ParenOpen ], true, false) ();
        if (parenPeek.type != TwineTokenType.Invalid) {
            // Read the "(" token.
            parser.readToken!([ TwineTokenType.ParenOpen ]) ();

            auto argList = appender!(TwineExpression[]);
            int argsCount = 0;

            // Make sure we're in command mode.
            parser.tokenizer.commandMode = true;

            // Used to check for the closing parenthesis.
            auto argsPeek = parser.readToken!([ TwineTokenType.ParenClose ], true, false) ();

            while (true) {
                if (argsPeek.type == TwineTokenType.ParenClose) {
                    // Read the closing parenthesis token.
                    parser.readToken!([ TwineTokenType.ParenClose ]) ();
                    break;
                } else if (argsPeek.type == TwineTokenType.Comma) {
                    // Read the comma token.
                    parser.readToken!([ TwineTokenType.Comma ]) ();
                } else if (argsCount > 0) {
                    // This will always error out, and that's on purpose.
                    parser.readToken!([ TwineTokenType.Comma, TwineTokenType.ParenClose ]) ();
                }

                // Read the argument expression.
                argList.put (parser.parseExpression ());
                // Make sure we're in command mode.
                parser.tokenizer.commandMode = true;
                // Peek the comma or closing parenthesis token.
                argsPeek = parser.readToken!([ TwineTokenType.Comma, TwineTokenType.ParenClose ], true, false) ();

                argsCount++;
            }

            return new TwineExpr_FunctionCall (idTok.value, argList []);
        } else
            return new TwineExpr_Variable (idTok.value);
    }

    TwineExpression parseExpression () {
        tokenizer.commandMode = true;
        return doParseExpression (condExpr);
    }

    TwineExpression doParseExpression (ParserExpr expr) {
        import std.algorithm : cmp;

        if (expr.type == ParserExprType.Binary) {
            auto curExpr = doParseExpression (*expr.lowerExpr);

            while (true) {
                auto op = readToken!(true, false) (expr.acceptedTokens);

                if (op.type != TwineTokenType.Invalid) {
                    bool foundMatch = false;
                    ParserExprBinaryFunc func = null;

                    foreach (input; expr.inputsByToken [op.type]) {
                        if (!input.val || cmp (input.val, op.value) == 0) {
                            // Read the token.
                            readToken (expr.acceptedTokens);

                            func = input.binaryExprFunc;

                            foundMatch = true;
                            break;
                        }
                    }

                    if (!foundMatch) {
                        throw new TweeParserException_UnexpectedToken (
                            expr.acceptedTokens, op, curParserPassage.passageName
                        );
                    }

                    auto rhs = doParseExpression (*expr.lowerExpr);

                    curExpr = func (curExpr, rhs);
                } else
                    return curExpr;
            }
        } else if (expr.type == ParserExprType.Unary) {
            import chr_tools.stack : Stack;
            auto funcStack = new Stack!(ParserExprUnaryFunc, true) (5);

            while (true) {
                auto op = readToken!(true, false) (expr.acceptedTokens);
                bool foundMatch = false;

                if (op.type != TwineTokenType.Invalid) {
                    foreach (input; expr.inputsByToken [op.type]) {
                        if (!input.val || cmp (input.val, op.value) == 0) {
                            // Read the token.
                            readToken (expr.acceptedTokens);

                            funcStack.push (input.unaryExprFunc);

                            foundMatch = true;
                            break;
                        }
                    }
                }

                if (!foundMatch) {
                    auto innerExpr = doParseExpression (*expr.lowerExpr);

                    if (!innerExpr) {
                        throw new TweeParserException_UnexpectedToken (
                            null, tokenizer.next (), curParserPassage.passageName
                        );
                    }

                    while (!funcStack.isEmpty)
                        innerExpr = (funcStack.pop ()) (innerExpr);

                    return innerExpr;
                }
            }
        } else if (expr.type == ParserExprType.Atom) {
            auto tok = readToken!(true, false) (expr.acceptedTokens);
            bool foundMatch = false;
            ParserExprAtomFunc func;

            if (tok.type != TwineTokenType.Invalid) {
                auto toks = tok.type in expr.inputsByToken;
                foreach (input; *toks) {
                    if (!input.val || cmp (input.val, tok.value) == 0) {
                        // Read the token.
                        readToken (expr.acceptedTokens);

                        func = input.atomExprFunc;

                        foundMatch = true;
                        break;
                    }
                }

                if (!foundMatch) {
                    throw new TweeParserException_UnexpectedToken (
                        expr.acceptedTokens, tok, curParserPassage.passageName
                    );
                }

                return func (this, tok);
            }

            return null;
        }

        assert (0);
    }
}
