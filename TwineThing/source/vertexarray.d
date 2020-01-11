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

module vertexarray;

import dsfml.graphics;

class TwineVertexArray : Drawable {
    private {
        Vertex[] vertices;
        size_t vertCount;
    }

    PrimitiveType primitiveType;

    this (PrimitiveType type, uint initialCapacity = 0) {
        primitiveType = type;
        vertices = new Vertex [initialCapacity];
    }

    /**
     ** Computes the bounding rectangle of the vertex array.
     **
     ** This function returns the axis-aligned rectangle that contains all the vertices of the array.
     **
     ** Returns: The bounding rectangle of the vertex array.
     */
    FloatRect getBounds () {
        if (vertCount <= 0)
            return FloatRect (0, 0, 0, 0);

        float left = vertices [0].position.x;
        float top = vertices [0].position.y;
        float right = vertices [0].position.x;
        float bottom = vertices [0].position.y;

        for (size_t i = 1; i < vertices.length; i++) {
            auto position = cast (const) vertices [i].position;

            // Update left and right
            if (position.x < left)
                left = position.x;
            else if (position.x > right)
                right = position.x;

            // Update top and bottom
            if (position.y < top)
                top = position.y;
            else if (position.y > bottom)
                bottom = position.y;
        }

        return FloatRect (left, top, right - left, bottom - top);
    }

    /**
     ** Gets the capacity of the array.
     **
     ** Returns: The current capacity of the array.
     */
    size_t getCapacity () {
        return vertices.length;
    }

    /**
     ** Gets the vertex count.
     **
     ** Returns: The number of vertices in the array.
     */
    size_t getCount () {
        return vertCount;
    }

    /**
     ** Adds a vertex to the array.
     **
     ** Params:
     **  vertex = The vertex to add.
     */
    void append (Vertex newVertex) {
        if (vertCount >= vertices.length) {
            import std.algorithm : max;
            resize (vertCount + max (vertCount >> 2, 1));
        }

        vertices [vertCount++] = newVertex;
    }

    /**
     ** Adds an array of vertices to the array.
     **
     ** Params:
     **  vertArr = The vertices to add.
     */
    void append (Vertex[] vertArr) {
        auto newCount = (vertCount + vertArr.length);
        if (newCount >= vertices.length) {
            import std.algorithm : max;
            resize (vertCount + max (vertCount >> 2, vertArr.length));
        }

        import std.algorithm : copy;
        copy (vertArr, vertices [vertCount .. newCount]);
        vertCount = newCount;
    }

    /**
     ** Adds the vertices from another TwineVertexArray to this instance.
     **
     ** Params:
     **  vertArr = The vertex array to append to this instance.
     */
    void append (TwineVertexArray vertArr) {
        append (vertArr.vertices);
    }

    /**
     ** Resizes the vertex array.
     **
     ** If vertexCount is greater than the current size, the previous vertices are kept and new (default-constructed)
     ** vertices are added. If vertexCount is less than the current size, existing vertices are removed from the end
     ** of the array.
     **
     ** Params:
     **  vertexCount = The new size of the array (number of vertices).
     */
    void resize (uint length) {
        import std.algorithm : min;

        vertices.length = length;
        vertCount = min (vertCount, vertices.length);
    }

    /**
     ** Clears the vertex array.
     **
     ** This function removes all the vertices from the array. It doesn't deallocate the corresponding memory, so that
     ** adding new vertices after clearing doesn't involve reallocating all the memory.
     */
    void clear () {
        vertCount = 0;
    }

    /**
     ** Gets a slice containing the vertex array.
     */
    Vertex[] getArray () {
        return vertices [0 .. vertCount];
    }

    /**
     ** Draws the object to a rendertarget.
     **
     ** Params:
     **  renderTarget = The rendertarget to draw to.
     **  renderStates = The current render states.
     */
    override void draw (RenderTarget renderTarget, RenderStates renderStates) {
        if (vertices.length == 0)
            return;

        renderTarget.draw (getArray (), primitiveType, renderStates);
    }

    Vertex[] opSlice (int start, int end)
        in { assert (start >= 0 && start <= end && end < vertCount); }
    body {
        return vertices [start .. end];
    }

    ref Vertex opIndex (size_t idx)
        in { assert (idx >= 0 && idx < vertCount); }
    body {
        return vertices [idx];
    }
}