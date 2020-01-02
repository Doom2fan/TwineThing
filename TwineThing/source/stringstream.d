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

struct StringStream {
    protected {
        int curPos;
        string inputStr;
    }

    this (in string input) {
        inputStr = input;
        curPos = 0;
    }

    string opSlice (int start, int end) {
        return inputStr [start .. end];
    }

    immutable (char) opIndex (int idx) {
        return inputStr [idx];
    }

    int opDollar () {
        return inputStr.length;
    }

    void seek (int newPos) {
        curPos = newPos;
    }

    int getPosition () {
        return curPos;
    }

    bool eof () {
        return curPos >= inputStr.length;
    }

    char peek () {
        if (eof ())
            return '\0';

        return inputStr [curPos];
    }

    char read () {
        if (eof ())
            return '\0';

        auto c = inputStr [curPos];
        curPos++;

        return c;
    }
}