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

module utilities;

import std.array : Appender, appender;
import std.variant : Algebraic;

static import dsfml.graphics;

enum ParseColourError {
    InvalidHexColour,
    InvalidRGBTriplet,
    RGBTripletOutOfRange
}

alias ParseColourReturn = Algebraic!(ParseColourError, uint);
ParseColourReturn parseColourString (string colStr) {
    import std.conv : to, ConvException;

    int rInt, gInt, bInt;

    if (colStr [0] == '#') {
        if (colStr.length != 7)
            return ParseColourReturn (ParseColourError.InvalidHexColour);

        colStr = colStr [1 .. $];
        auto rStr = colStr [0 .. 2];
        auto gStr = colStr [2 .. 4];
        auto bStr = colStr [4 .. 6];

        try {
            rInt = rStr.to!int (16);
            gInt = gStr.to!int (16);
            bInt = bStr.to!int (16);
        } catch (ConvException e) {
            return ParseColourReturn (ParseColourError.InvalidHexColour);
        }
    } else {
        import std.array : split;
        auto colStrSplit = colStr.split (':');

        if (colStrSplit.length != 3)
            return ParseColourReturn (ParseColourError.InvalidRGBTriplet);

        try {
            rInt = colStrSplit [0].to!int (10);
            gInt = colStrSplit [1].to!int (10);
            bInt = colStrSplit [2].to!int (10);
        } catch (ConvException e) {
            return ParseColourReturn (ParseColourError.InvalidRGBTriplet);
        }

        if (
            rInt < 0 || rInt > 255 ||
            gInt < 0 || gInt > 255 ||
            bInt < 0 || bInt > 255
        ) {
            return ParseColourReturn (ParseColourError.RGBTripletOutOfRange);
        }
    }

    return ParseColourReturn (
        rInt << 16 |
        gInt <<  8 |
        bInt       |
        0xFF000000
    );
}

dsfml.graphics.Color dsfmlColorFromArgbInt (uint col) {
    dsfml.graphics.Color ret;

    ret.a = cast (ubyte) ((col & 0xFF000000) >> 24);
    ret.r = cast (ubyte) ((col & 0x00FF0000) >> 16);
    ret.g = cast (ubyte) ((col & 0x0000FF00) >>  8);
    ret.b = cast (ubyte)  (col & 0x000000FF)       ;

    return ret;
}

private void wrapLine (Appender!string wrapped, in string text, in int lineWidth) {
    import std.algorithm : splitter;
    import std.algorithm.comparison : min;

    auto words = text.splitter (" ");

    if (words.empty)
        return;

    int spaceLeft = lineWidth;

    bool firstWord = true;
    foreach (word; words) {
        if (cast (int) (word.length) >= spaceLeft) {
            if (word.length < lineWidth) {
                wrapped.put ('\n');
                
                if (word.length > 0) {
                    wrapped.put (word);
                    spaceLeft = lineWidth - word.length;
                } else {
                    firstWord = true;
                    spaceLeft = lineWidth;
                    continue;
                }
            } else {
                if (!firstWord) {
                    wrapped.put (' ');
                    spaceLeft--;
                }

                int i = 0;
                bool insertLine = false;
                while (i < word.length) {
                    const (int) count = min (word.length - i, spaceLeft);

                    if (insertLine)
                        wrapped.put ('\n');
                    wrapped.put (word [i .. i + count]);

                    i += count;
                    spaceLeft -= count;
                    if (spaceLeft < 1) {
                        spaceLeft = lineWidth;
                        insertLine = true;
                    } else
                        insertLine = false;
                }
            }
        } else {
            if (!firstWord)
                wrapped.put (' ');
            wrapped.put (word);
            spaceLeft -= 1 + word.length;
        }

        firstWord = false;
    }
}

string wrap (in string text, in int lineWidth) {
    import std.array : appender;
    import std.string : lineSplitter;

    auto wrapped = appender!string;
    auto lines = text.lineSplitter ();

    bool firstLine = true;
    foreach (line; lines) {
        if (!firstLine)
            wrapped.put ('\n');

        wrapLine (wrapped, line, lineWidth);

        firstLine = false;
    }

    return wrapped.data;
}