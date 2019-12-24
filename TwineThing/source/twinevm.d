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

module twinevm;

import std.algorithm : min;
import std.typecons : Tuple;
import std.format : format;
import gamedata;
import utilities : wrap;

enum TwineVMState {
    Running,
    ScreenPause,
    WaitingForSelection,
    Stopped,
}

alias TwineSelection = Tuple!(string, "text", TwinePassage, "passage");

class TwineVMException : Exception {
    public this (string message, string file = __FILE__, int _line = __LINE__) {
        super (message, file, _line);
    }
}

class TwineVirtualMachine {
    // Game data
    protected TwineGameData gameData;
    protected Object[string] gameVariables;

    // VM state
    protected TwineVMState vmState;
    protected TwinePassage curPassage;
    protected int curCommand;
    protected string curTextBuffer;
    protected string[] curTextLines;
    protected TwineSelection[] selections;

    // Callbacks
    public void delegate (string) setTextCallback;
    public void delegate (string) setImageCallback;
    public void delegate (string) setMusicCallback;
    public void delegate (string) showFatalErrorCallback;

    public this (TwineGameData data) {
        // Game data
        gameData = data;

        // VM state
        vmState = TwineVMState.Running;
        curPassage = gameData.passages ["Start"];
        curCommand = 0;
        curTextBuffer = null;
        curTextLines = null;
        selections = null;
    }

    public TwineVMState getVMState () {
        return vmState;
    }

    public const (TwineSelection[]) getSelections () {
        return cast (const (TwineSelection[])) (selections);
    }

    public void playerInput (int selection) {
        if (vmState == TwineVMState.ScreenPause) {
            if (curTextLines.length < 1) {
                vmState = TwineVMState.Running;
                return;
            }
            showText ();
        }
    }

    protected void startShowText () {
        import std.array : split;

        vmState = TwineVMState.ScreenPause;

        curTextLines = curTextBuffer.wrap (30).split ('\n');
        curTextBuffer = null;

        showText ();
    }

    protected void showText () {
        import std.array : join;

        auto text = curTextLines [0 .. min (6, $)];
        curTextLines = curTextLines [min (6, $) - 1 .. $];
        setTextCallback (text.join ('\n'));
    }

    public void run () {
        if (
            vmState == TwineVMState.ScreenPause ||
            vmState == TwineVMState.WaitingForSelection ||
            vmState == TwineVMState.Stopped
            )
            return;

        while (curCommand < curPassage.commands.length) {
            auto cmd = curPassage.commands [curCommand];

            if (auto textCMD = cast (TwineCommand_PrintText) cmd) {
                curTextBuffer ~= textCMD.text;
            } else if (auto pauseCMD = cast (TwineCommand_Pause) cmd) {
                startShowText ();

                return;
            } else if (auto jumpCMD = cast (TwineCommand_JumpToPassage) cmd) {
                if (auto jumpTarget = (jumpCMD.targetPassage in gameData.passages))  {
                    curPassage = *jumpTarget;
                    curCommand = 0;
                } else
                    showFatalErrorCallback (format ("Unknown jump target \"%s\".", jumpCMD.targetPassage));
            } else if (auto callCMD = cast (TwineCommand_CallPassage) cmd) {
                throw new TwineVMException ("\"Call\" ain't implemented yet.");
                /*if (auto jumpTarget = (gameData.passages [callCMD.targetPassage]))  {

                } else
                    showFatalErrorCallback (format ("Unknown call target \"%s\".", jumpCMD.targetPassage));*/
            } else if (auto returnCMD = cast (TwineCommand_ReturnPassage) cmd) {
                throw new TwineVMException ("\"Return\" ain't implemented yet.");
            } else if (auto setMusicCMD = cast (TwineCommand_SetMusic) cmd) {
                setMusicCallback (setMusicCMD.musicName);
            } else if (auto setImageCMD = cast (TwineCommand_SetImage) cmd) {
                setImageCallback (setImageCMD.imageName);
            } else if (auto addSelectionCMD = cast (TwineCommand_AddSelection) cmd) {
                if (auto jumpTarget = (gameData.passages [addSelectionCMD.targetPassage]))  {
                    auto selection = TwineSelection ();

                    selection.text = addSelectionCMD.selectionText;
                    selection.passage = jumpTarget;

                    selections ~= [ selection ];
                } else
                    showFatalErrorCallback (format ("Unknown passage \"%s\" in selection.", addSelectionCMD.targetPassage));
            } else if (auto ifCMD = cast (TwineCommand_If) cmd) {
                throw new TwineVMException ("\"If\" ain't implemented yet.");
            } else if (auto setVarCMD = cast (TwineCommands_SetVariable) cmd) {
                throw new TwineVMException ("\"Set\" ain't implemented yet.");
            } else if (auto printCMD = cast (TwineCommand_PrintResult) cmd) {
                throw new TwineVMException ("\"Print\" ain't implemented yet.");
            } else {
                throw new TwineVMException (format ("Unknown command class \"%s\" encountered.", ));
            }

            curCommand++;
        }

        if (vmState == TwineVMState.WaitingForSelection) {

        } else
            vmState = TwineVMState.Stopped;
    }
}