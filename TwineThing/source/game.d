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

module game;

import std.file : exists, readText, thisExePath;
import std.path : buildPath;
import std.format : format;
import dsfml.system;
import dsfml.window;
import dsfml.graphics;
import toml : parseTOML, TOMLDocument, TOMLParserException;
import gamedata;
import twineparser.parser;
import twinevm.vm;
import utilities : wrap;

class TwineGame {
    protected const string gameInfoFile = "gameinfo.toml";

    protected RenderWindow mainWindow;
    protected bool windowFocused = false;

    TwineGameInfo gameInfo;
    TwineVirtualMachine virtualMachine;

    protected Font systemFont;

    protected Texture imageTex;
    protected Sprite imageSprite;
    protected bool imageHidden;
    protected string imageError;
    protected Text imageText;

    protected string thisExeDir () {
        import std.path : dirName;
        return dirName (thisExePath ());
    }

    final void initialize () {
        // Create the window
        auto contextSet = cast (const (ContextSettings)) ContextSettings (24, 8, 0, 3, 0);
        mainWindow = new RenderWindow (VideoMode (256, 192), "TwineThing"d, Window.Style.DefaultStyle, contextSet);

        // Load the system font
        systemFont = new Font ();
        systemFont.loadFromFile (buildPath (thisExeDir (), "resources/CourierPrime.ttf"));

        // Create the image data
        imageTex = new Texture ();
        imageSprite = new Sprite ();
        imageSprite.position (Vector2f (0, 0));
        imageText = new Text ();
        imageText.setFont (systemFont);
        imageText.setCharacterSize (12);
        imageText.setColor (Color.White);

        // Load the game data
        loadGameInfo ();

        Joystick.update ();
    }

    protected final void loadGameInfo () {
        import std.file : FileException;
        import std.path : isAbsolute, absolutePath;

        auto gameInfoPath = buildPath (thisExeDir (), gameInfoFile);

        // Error out if gameinfo.toml is missing
        if (!exists (gameInfoPath)) {
            displayFatalError ("Could not find gameinfo.toml");
            return;
        }

        gameInfo = TwineGameInfo ();

        try {
            string gameinfoText = readText (gameInfoPath);
            auto gameinfoToml = cast (const (TOMLDocument)) (parseTOML (gameinfoText));

            if (auto name = "gameName" in gameinfoToml)
                gameInfo.gameName = name.str;

            if (auto path = "tweePath" in gameinfoToml)
                gameInfo.tweePath = path.str;
        } catch (FileException e) {
            auto errorString = format ("Could not read gameinfo.toml.");
            displayFatalError (errorString);
            return;
        } catch (std.utf.UTFException e) {
            auto errorString = format ("Encountered a UTF-8 error while decoding gameinfo.toml.");
            displayFatalError (errorString);
            return;
        } catch (TOMLParserException e) {
            auto errorString = format ("TOML parsing error at line %d:%d:\n  %s", e.position.line, e.position.column, e.message);
            displayFatalError (errorString);
            return;
        }

        if (!isAbsolute (gameInfo.tweePath))
            gameInfo.tweePath = absolutePath (gameInfo.tweePath, thisExeDir ());

        if (!gameInfo.tweePath) {
            displayFatalError ("Game info key \"tweePath\" not set.");
            return;
        }

        if (gameInfo.tweePath.length < 1) {
            displayFatalError ("Game info key \"tweePath\" cannot be empty.");
            return;
        }

        if (!exists (gameInfo.tweePath)) {
            displayFatalError (format ("Could not find twee file \"%s\"", gameInfo.tweePath));
            return;
        }

        string tweeFileContents;
        try {
            tweeFileContents = readText (gameInfo.tweePath);
        } catch (FileException e) {
            auto errorString = format ("Could not read twee file \"%s\".", gameInfo.tweePath);
            displayFatalError (errorString);
            return;
        } catch (std.utf.UTFException e) {
            auto errorString = format ("Encountered a UTF-8 error while decoding twee file \"%s\".", gameInfo.tweePath);
            displayFatalError (errorString);
            return;
        }

        if (tweeFileContents.length >= 3 && tweeFileContents [0 .. 2] == [ 0xEF, 0xBB, 0xBF ]) {
            tweeFileContents = tweeFileContents [2 .. $];
        }

        TwineParser parser = new TwineParser ();

        TwineGameData gameData;
        try {
            gameData = parser.parseTweeFile (tweeFileContents);
        } catch (TweeParserException e) {
            auto errorString = format ("Twee parsing error at line %d:%d:\n  %s", e.position.line, e.position.column, e.message);
            displayFatalError (errorString);
            return;
        }

        virtualMachine = new TwineVirtualMachine (gameData);
        virtualMachine.setImageCallback = &setImage;
        virtualMachine.showFatalErrorCallback = &displayFatalError;

        mainWindow.setTitle (gameInfo.gameName);
    }

    protected void setImage (string name) {
        if (!name || name.length == 0) {
            imageHidden = true;
            imageError = null;

            return;
        }

        auto filePath = buildPath (thisExeDir (), "images/", name);
        if (!exists (filePath)) {
            imageError = format ("Could not find image file \"%s\"", name);
            return;
        }

        if (!imageTex.loadFromFile (filePath)) {
            imageError = format ("Image file \"%s\" could not be loaded.", name);
            return;
        }

        imageSprite.setTexture (imageTex);
        imageHidden = false;
        imageError = null;
    }

    protected final void displayFatalError (string err) {
        imageError = err.wrap (36);
        imageHidden = true;
    }

    protected void focusLost () {
        windowFocused = false;
    }

    protected void focusGained () {
        windowFocused = true;
    }

    final void run () {
        while (mainWindow.isOpen ()) {
            /* Check all the window's events that were triggered since the last iteration of the loop */
            Event event;
            while (mainWindow.pollEvent (event)) {
                // "Close requested" event: we close the window
                switch (event.type) {
                    case Event.EventType.Closed:
                        mainWindow.close ();
                    break;

                    case Event.EventType.LostFocus:
                        focusLost ();
                    break;

                    case Event.EventType.GainedFocus:
                        focusGained ();
                    break;

                    case Event.EventType.KeyPressed:
                    break;

                    default:
                    break;
                }
            }

            virtualMachine.run ();
            doRender ();
        }
    }

    protected void doRender () {
        /* Clear the window */
        mainWindow.clear (Color.Black);

        if (!imageError && !imageHidden)
            mainWindow.draw (imageSprite);
        else if (imageError) {
            imageText.setString (imageError);
            mainWindow.draw (imageText);
        }

        /* Display the window */
        mainWindow.display ();
    }
}
