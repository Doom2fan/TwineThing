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

module stringstream;

/// A string stream class.
struct StringStream {
    protected {
        int curPos;
        string inputStr;
    }
    
    /// Creates an instance of the stream class from the specified input.
    this (in string input) {
        inputStr = input;
        curPos = 0;
    }

    string opSlice (int start, int end) { // @suppress(dscanner.style.undocumented_declaration)
        return inputStr [start .. end];
    }

    immutable (char) opIndex (int idx) { // @suppress(dscanner.style.undocumented_declaration)
        return inputStr [idx];
    }

    int opDollar () { // @suppress(dscanner.style.undocumented_declaration)
        return inputStr.length;
    }

    /// Seeks the stream to the specified point from the start of the stream.
    void seek (int newPos) {
        curPos = newPos;
    }

    /// Gets the current position of the stream.
    int getPosition () {
        return curPos;
    }

    /// Checks if the end of the stream has been reached.
    bool eof () {
        return curPos >= inputStr.length;
    }

    /// Gets a character from the stream without moving the current position.
    char peek () {
        if (eof ())
            return '\0';

        return inputStr [curPos];
    }

    /// Reads a character from the stream.
    char read () {
        if (eof ())
            return '\0';

        auto c = inputStr [curPos];
        curPos++;

        return c;
    }
}