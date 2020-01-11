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

module smstext;

import std.typecons : Rebindable;

import dsfml.graphics;

import smsfont;
import vertexarray;

/// A DSFML text element that uses a SMS font.
class TwineSMSText : Drawable, Transformable {
    mixin NormalTransformable;

    protected {
        TwineSMSFont _font;
        Color _color;
        string _text;

        bool isDirty;
        TwineVertexArray vertArr;
        Rebindable!Texture tex;
    }

    this () { // @suppress(dscanner.style.undocumented_declaration)
        isDirty = true;
        vertArr = new TwineVertexArray (PrimitiveType.Triangles);
    }

    @property {
        /// Gets the current font.
        TwineSMSFont font () { return _font; }
        /// Sets the current font.
        TwineSMSFont font (TwineSMSFont newFont) {
            _font = newFont;
            isDirty = true;

            return newFont;
        }

        /// Gets the current text colour.
        Color color () const { return _color; }
        /// Sets the current text colour.
        Color color (Color newColor) {
            _color = newColor;
            isDirty = true;

            return newColor;
        }

        /// Gets the current text.
        string text () const { return _text; }
        /// Sets the current text.
        string text (string newText) {
            _text = newText;
            isDirty = true;

            return newText;
        }
    }

    protected int[] getLineCharIndices (string line) {
        int[] indices = new int[line.length];

        int curIdx = 0;
        foreach (c; line) {
            if (c < _font.charsStart || c > _font.charsEnd) {
                indices [curIdx++] = _font.charsCount + 1;
                continue;
            }

            indices [curIdx++] = (c - _font.charsStart);
        }

        return indices;
    }

    protected void buildVertArray () {
        import std.string : lineSplitter;

        vertArr.clear ();

        if (!_font || !_text)
            return;

        auto splitLines = lineSplitter (text);

        int lineCount = 0;
        foreach (line; splitLines) {
            auto charIndices = getLineCharIndices (line);
            auto verts = new Vertex[charIndices.length * 6];

            for (int i = 0; i < charIndices.length; i++) {
                auto charIdx = charIndices [i];
                auto charOrigin = Vector2f (i * 8, lineCount * 8);
                auto charVerts = [
                    Vertex (charOrigin + Vector2f (0, 0), Vector2f (0, charIdx * 8    )),
                    Vertex (charOrigin + Vector2f (0, 8), Vector2f (0, charIdx * 8 + 8)),
                    Vertex (charOrigin + Vector2f (8, 8), Vector2f (8, charIdx * 8 + 8)),
                    Vertex (charOrigin + Vector2f (8, 0), Vector2f (8, charIdx * 8    ))
                ];

                verts [i * 6    ] = charVerts [0];
                verts [i * 6 + 1] = charVerts [1];
                verts [i * 6 + 2] = charVerts [2];

                verts [i * 6 + 3] = charVerts [0];
                verts [i * 6 + 4] = charVerts [2];
                verts [i * 6 + 5] = charVerts [3];
            }

            vertArr.append (verts);

            lineCount++;
        }

        tex = _font.getGlyphsTex ();
    }

    override void draw (RenderTarget renderTarget, RenderStates renderStates) {
        if (isDirty) {
            buildVertArray ();
            isDirty = false;
        }

        if (tex) {
            renderStates.transform *= getTransform ();
            renderStates.texture = tex;
            vertArr.draw (renderTarget, renderStates);
        }
    }
}