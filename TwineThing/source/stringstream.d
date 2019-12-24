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

public struct StringStream {
    protected int curPos;
    protected string inputStr;

    public this (in string input) {
        inputStr = input;
        curPos = 0;
    }

    public string opSlice (int start, int end)
        in { assert (start >= 0 && end < inputStr.length && start <= end); }
    body {
        return inputStr [start .. end];
    }

    public immutable (char) opIndex (int idx)
        in { assert (idx >= 0 && idx < inputStr.length); }
    body {
        return inputStr [idx];
    }

    public void seek (int newPos) {
        curPos = newPos;
    }

    public int getPosition () {
        return curPos;
    }

    public bool eof () {
        return curPos >= inputStr.length;
    }

    public char peek () {
        if (eof ())
            return '\0';

        return inputStr [curPos];
    }

    public char read () {
        if (eof ())
            return '\0';

        auto c = inputStr [curPos];
        curPos++;

        return c;
    }
}