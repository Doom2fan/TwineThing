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

module smsfont;

import std.format : format;

import dsfml.graphics : Texture;

/// An exception raised when errors are encountered while parsing a SMS font.
class TwineSMSFontException : Exception {
    this (string message, string file = __FILE__, int _line = __LINE__) { // @suppress(dscanner.style.undocumented_declaration)
        super (message, file, _line);
    }
}

/// A SMS font.
class TwineSMSFont {
    static const {
        /// The format of a font line.
        string lineFormat = ".DB %xxxxxxxx"; // For printing messages and checking length. Do not use for correctness checking.
        /// The regex for matching a font line.
        string lineFormatRegex = r".DB %([01]{8})"; // For checking the input's correctness. Must contain a capture group that
                                                    // contains the bits.
        /// The first character of the character set.
        int charsStart = 0x20;
        /// The last character of the character set.
        int charsEnd   = 0x7F;
        /// The amount of characters in the character set.
        int charsCount = (charsEnd - charsStart) + 1;

        /// The glyph for a missing character.
        ubyte[8] charsMissingChar = [
            0b10000001,
            0b01000010,
            0b00100100,
            0b00011000,
            0b00011000,
            0b00100100,
            0b01000010,
            0b10000001,
        ];
    }

    protected Texture charGlyphs;

    protected this () { }

    Texture getGlyphsTex () {
        return charGlyphs;
    }

    /// Parses and creates an instance of a SMS font.
    static TwineSMSFont create (string text) {
        import std.string : lineSplitter, indexOf, strip;

        // Split the file into lines.
        auto lines = text.lineSplitter ();

        ubyte[charsCount * 8] charData;
        int dataIdx = 0;

        // Process the lines.
        foreach (line; lines) {
            // Remove any comments.
            auto commentIdx = line.indexOf (';');
            if (commentIdx >= 0)
                line = line [0 .. commentIdx];

            // Trim any whitespace.
            line = line.strip ();

            // Error out if the line isn't like lineFormat or is empty.
            if (line.length != lineFormat.length && line.length != 0) {
                throw new TwineSMSFontException (
                    "Invalid font. Font files cannot contain anything other than \"" ~
                    lineFormat ~
                    "\" and comments, and there must be only one per line"
                );
            }

            if (line.length == lineFormat.length) {
                if (dataIdx >= (charsCount * 8)) {
                    throw new TwineSMSFontException (
                        format ("Invalid font. Too many pixel rows. (expected %d)", charsCount * 8)
                    );
                }

                ubyte row = 0;

                import std.regex : ctRegex, match;
                auto formatRegEx = ctRegex!lineFormatRegex;

                auto m = match (line, formatRegEx);

                if (!m) {
                    throw new TwineSMSFontException (
                        "Invalid font. Row format is \"" ~ lineFormat ~ "\", where the 'x'es can be zeroes or ones."
                    );
                }

                if (m.captures.length != 2) {
                    throw new TwineSMSFontException (
                        "Internal error in font parsing code: Invalid regex for line format"
                    );
                }

                auto rowStr = m.captures [1];
                for (int i = 0; i < 8; i++) {
                    if (rowStr [i] == '1')
                        row |= ((1 << 7) >> i);
                }

                charData [dataIdx] = row;

                dataIdx++;
            }
        }

        if (dataIdx < (charsCount * 8)) {
            throw new TwineSMSFontException (
                format ("Invalid font. Not enough pixel rows. (got %d, expected %d)", dataIdx, charsCount * 8)
            );
        }

        auto font = new TwineSMSFont ();
        uint[8][charData.length + charsMissingChar.length] pixels;

        for (int j = 0; j < charData.length; j++) {
            const (ubyte) row = charData [j];

            for (int i = 0; i < 8; i++) {
                const (bool) isSet = (row & ((1 << 7) >> i)) != 0;

                if (isSet)
                    pixels [j] [i] = 0xFFFFFFFF;
                else
                    pixels [j] [i] = 0x00000000;
            }
        }

        for (int j = 0; j < charsMissingChar.length; j++) {
            const (ubyte) row = charsMissingChar [j];

            for (int i = 0; i < 8; i++) {
                const (bool) isSet = (row & ((1 << 7) >> i)) != 0;

                if (isSet)
                    pixels [charData.length + j] [i] = 0xFFFFFFFF;
                else
                    pixels [charData.length + j] [i] = 0x00000000;
            }
        }

        auto tex = new Texture ();
        tex.create (8, charData.length + charsMissingChar.length);
        tex.updateFromPixels (cast (const (ubyte)[]) pixels, 8, charData.length + charsMissingChar.length, 0, 0);

        font.charGlyphs = tex;

        return font;
    }
}