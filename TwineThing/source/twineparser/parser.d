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

import std.string : strip;
import gamedata;
import twineparser.tokenizer;

class TweeParserException : Exception {
    import std.typecons : Tuple;

    protected Tuple!(string, "file", int, "line", int, "column") _position;

    public this (string message, string errFile, int errLine, int errColumn, string file = __FILE__, int _line = __LINE__) {
        super (message, file, _line);

        this._position.file = errFile;
        this._position.line = errLine;
        this._position.column = errColumn;
    }

    /**
     ** Gets the position (line and column) where the parsing expection
     ** has occured.
    */
    public pure nothrow @property @safe @nogc auto position () {
        return this._position;
    }
}

public class TwineParser {
    protected struct ParserPassage {
        string passageName;
        string passageContents;
    }

    protected TwineTokenizer tokenizer;
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

    public TwineGameData parseTweeFile (string input) {
        ParserPassage[] splitPassages = preprocessTweeFile (input); // @suppress(dscanner.suspicious.unmodified)

        auto gameData = new TwineGameData ();

        auto pass = new TwinePassage ();
        pass.passageName = "Start";

        auto imageCMD = new TwineCommand_SetImage ();
        imageCMD.imageName = "TEST1.png";
        pass.commands ~= imageCMD;

        auto textCMD = new TwineCommand_PrintText ();
        textCMD.text ~= "test aaaa bbbb cccc dddd\neeee fffff gggg\nhhhh iii jjjjj\nkkkkkkkkkk llllllllllll\nmmmmmmmmmm\nnnnnnnnnnn\nooooooo\npppppp\nqqqqq\nrrrrrr\nsssss\nttttttttttt\nuuuuuuuuu\nmaxkek";
        pass.commands ~= textCMD;

        pass.commands ~= new TwineCommand_Pause ();

        auto selCMD = new TwineCommand_AddSelection ();
        selCMD.selectionText = "Fak";
        selCMD.targetPassage = "Start";
        pass.commands ~= selCMD;

        selCMD = new TwineCommand_AddSelection ();
        selCMD.selectionText = "Fug";
        selCMD.targetPassage = "Start";
        pass.commands ~= selCMD;

        imageCMD = new TwineCommand_SetImage ();
        imageCMD.imageName = "TEST2.png";
        pass.commands ~= imageCMD;

        textCMD = new TwineCommand_PrintText ();
        textCMD.text ~= "aaaaaa\nbbbbbb\ncccccc";
        pass.commands ~= textCMD;

        pass.commands ~= new TwineCommand_Pause ();

        gameData.passages ["Start"] = pass;

        return gameData;
    }
}
