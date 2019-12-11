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

private void wrapLine (Appender!string wrapped, in string text, in int lineWidth) {
    import std.algorithm : splitter;
    import std.algorithm.comparison : min;

    auto words = text.splitter (" ");

    if (words.empty)
        return;

    int spaceLeft = lineWidth;

    bool firstWord = true;
    foreach (word; words) {
        if ((word.length + 1) > spaceLeft) {
            if (word.length <= lineWidth) {
                wrapped.put ('\n');
                wrapped.put (word);
                spaceLeft = lineWidth - word.length;
            } else {
                if (!firstWord) {
                    wrapped.put (' ');
                    spaceLeft--;
                }

                int i = 0;
                bool insertLine = false;
                while (i < word.length) {
                    int count = min (word.length - i, spaceLeft);

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