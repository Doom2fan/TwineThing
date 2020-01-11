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

module twinevm.twinevalue;

import std.variant : Algebraic;
import std.conv : to;

import twinevm.common;

enum TwineValueType {
    Int,
    Bool,
    String,
}

/// A Twine value.
struct TwineValue {
    Algebraic!(int, bool, string) value;
    TwineValueType type;

    TwineValueType getType () const {
        return type;
    }

    this (int val) {
        value = val;
        type = TwineValueType.Int;
    }
    this (bool val) {
        value = val;
        type = TwineValueType.Bool;
    }
    this (string val) {
        value = val;
        type = TwineValueType.String;
    }
    this (TwineValue other) {
        value = other.value;
        type = other.type;
    }

    bool asBool () const {
        switch (type) {
            case TwineValueType.Int:
                return value.get!(int) != 0;
            case TwineValueType.Bool:
                return value.get!(bool);
            case TwineValueType.String:
                return value.get!(string).length > 0;

            default:
                assert (0);
        }
    }

    int asInt () const {
        switch (type) {
            case TwineValueType.Int:
                return value.get!(int);
            case TwineValueType.Bool:
                return (value.get!(bool) ? 1 : 0);
            case TwineValueType.String:
                return ((value.get!(string).length > 0) ? 1 : 0);

            default:
                assert (0);
        }
    }

    string asString () const {
        switch (type) {
            case TwineValueType.Int:
                return to!string (value.get!(int));
            case TwineValueType.Bool:
                return (value.get!(bool) ? "true" : "false");
            case TwineValueType.String:
                return value.get!(string);

            default:
                assert (0);
        }
    }

    bool opEquals(S) (auto ref const S rhs) const {
        return value.opEquals (rhs.value);
    }

    ulong toHash () const {
        return value.toHash ();
    }


    int opCmp (ref const TwineValue rhs) const {
        if (type != rhs.type)
            throw new TwineVMException ("Cannot compare values of different types.");
        if (type != TwineValueType.Int)
            throw new TwineVMException ("Cannot compare non-int values.");

        return value.opCmp (rhs.value);
    }

    TwineValue opBinary(string op) (TwineValue rhs) const {
        import std.typecons : Nullable;

        Nullable!int lhsInt, rhsInt;
        string lhsStr = null, rhsStr = null;

        lhsInt.nullify ();
        rhsInt.nullify ();

        if (type == TwineValueType.Int || type == TwineValueType.Bool)
            lhsInt = asInt ();
        else if (type == TwineValueType.String)
            lhsInt = asInt ();

        if (rhs.type == TwineValueType.Int || rhs.type == TwineValueType.Bool)
            rhsInt = rhs.asInt ();
        else if (rhs.type == TwineValueType.String)
            rhsInt = rhs.asInt ();

        if (!lhsInt.isNull && !rhsInt.isNull)
            return TwineValue (mixin ("lhsInt.get " ~ op ~ "rhsInt.get"));
        else if (type == TwineValueType.String && rhs.type == TwineValueType.String) {
            static if (op == "~")
                return TwineValue (lhsStr ~ rhsStr);
            else
                assert (0, "Operator " ~ op ~ " not implemented for strings");
        }

        assert (0);
    }

    void toString (scope void delegate (const (char)[]) sink) const {
        switch (type) {
            case TwineValueType.Int:
                sink (value.get!(bool) ? "true" : "false");
                break;
            case TwineValueType.Bool:
                sink (to!string (value.get!(int)));
                break;
            case TwineValueType.String:
                sink (value.get!(string));
                break;

            default:
                assert (0);
        }
    }
}