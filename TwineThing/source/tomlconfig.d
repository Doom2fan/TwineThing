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

module tomlconfig;

import std.variant : Algebraic;
import std.format : format;

import toml : TOML_TYPE;

class TomlConfigException : Exception {
    @disable this ();

    protected this (string message, string file = __FILE__, int _line = __LINE__) {
        super (message, file, _line);
    }
}

class TomlConfigException_TomlParsingError : TomlConfigException {
    Exception innerException;

    public this (Exception inner, string file = __FILE__, int _line = __LINE__) {
        super ("", file, _line);

        innerException = inner;
    }
}

class TomlConfigException_MissingRequiredKey : TomlConfigException {
    string tomlKeyName;

    public this (string keyName, string file = __FILE__, int _line = __LINE__) {
        super ("Required key \"" ~ keyName ~ "\" not present", file, _line);

        tomlKeyName = keyName;
    }
}

class TomlConfigException_KeyTypeMismatch : TomlConfigException {
    string tomlKeyName;
    string receivedType;
    string expectedType;

    public this (string keyName, string expected, string received, string file = __FILE__, int _line = __LINE__) {
        auto msg = format ("Type mismatch for key \"%s\": Expected %s, got %s", keyName, expected, received);
        super (msg, file, _line);

        tomlKeyName = keyName;
        expectedType = expected;
        receivedType = received;
    }
}

enum TomlConfigFlag {
    Required = 1,
}

struct TomlConfigMember {
    Algebraic!(int*, bool*, string*, float*) memberPtr;
    package string tomlKey;
    package int flags;

    @disable this ();

    private this (string keyName, int flags) {
        tomlKey = keyName;
        this.flags = flags;
    }

    this (int* member, string keyName, int flags = 0) {
        this (keyName, flags);
        memberPtr = member;
    }

    this (bool* member, string keyName, int flags = 0) {
        this (keyName, flags);
        memberPtr = member;
    }

    this (string* member, string keyName, int flags = 0) {
        this (keyName, flags);
        memberPtr = member;
    }
}

string tomlTypeToString (TOML_TYPE type) {
    switch (type) {
        case TOML_TYPE.STRING: return "string";
        case TOML_TYPE.INTEGER: return "integer";
        case TOML_TYPE.FLOAT: return "float";
        case TOML_TYPE.TRUE: return "boolean";
        case TOML_TYPE.FALSE: return "boolean";

        case TOML_TYPE.OFFSET_DATETIME: return "date-time offset";
        case TOML_TYPE.LOCAL_DATETIME: return "local date-time";
        case TOML_TYPE.LOCAL_DATE: return "local date";
        case TOML_TYPE.LOCAL_TIME: return "local time";

        case TOML_TYPE.ARRAY: return "array";
        case TOML_TYPE.TABLE: return "table";

        default: return "UNKNOWN TYPE";
    }
}

void parseTomlConfig (string tomlText, TomlConfigMember[] members) {
    import toml : parseTOML, TOMLDocument, TOMLParserException;

    TOMLDocument tomlContents;

    try {
        tomlContents = parseTOML (tomlText);
    } catch (TOMLParserException e) {
        throw new TomlConfigException_TomlParsingError (e);
    }

    foreach (member; members) {
        auto tomlData = member.tomlKey in tomlContents;

        if (!tomlData) {
            if (member.flags & TomlConfigFlag.Required)
                throw new TomlConfigException (member.tomlKey);

            continue;
        }

        if (auto intPtr = member.memberPtr.peek!(int*)) {
            if (tomlData.type != TOML_TYPE.INTEGER)
                throw new TomlConfigException_KeyTypeMismatch (member.tomlKey, "integer", tomlTypeToString (tomlData.type));

            **intPtr = cast (int) tomlData.integer;
        } if (auto intPtr = member.memberPtr.peek!(float*)) {
            if (tomlData.type != TOML_TYPE.FLOAT)
                throw new TomlConfigException_KeyTypeMismatch (member.tomlKey, "float", tomlTypeToString (tomlData.type));

            **intPtr = tomlData.floating;
        } else if (auto boolPtr = member.memberPtr.peek!(bool*)) {
            if (tomlData.type != TOML_TYPE.FALSE && tomlData.type != TOML_TYPE.TRUE)
                throw new TomlConfigException_KeyTypeMismatch (member.tomlKey, "boolean", tomlTypeToString (tomlData.type));

            **boolPtr = (tomlData.type == TOML_TYPE.TRUE);
        } else if (auto strPtr = member.memberPtr.peek!(string*)) {
            if (tomlData.type != TOML_TYPE.STRING)
                throw new TomlConfigException_KeyTypeMismatch (member.tomlKey, "string", tomlTypeToString (tomlData.type));

            **strPtr = tomlData.str;
        }
    }
}