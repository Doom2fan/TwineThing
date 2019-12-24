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
import smsfont;
import smstext;
import utilities : wrap;

import twineparser.parser;
import twinevm.vm;

class TwineGame {
    /* Protected members */
    protected {
        const string gameInfoFile = "gameinfo.toml";

        RenderWindow mainWindow;
        bool windowFocused = false;

        bool zPressed     = false;
        bool xPressed     = false;
        bool upPressed    = false;
        bool downPressed  = false;
        bool leftPressed  = false;
        bool rightPressed = false;

        Font systemFont;

        Texture imageTex;
        Sprite imageSprite;
        bool imageHidden;
        string imageError;
        Text imageText;

        TwineSMSFont textFont;
        TwineSMSText textData;

        int selectionIndex = 0;
    }

    /* Public members */
    public {
        TwineGameInfo gameInfo;
        TwineGameData gameData;
        TwineVirtualMachine virtualMachine;
    }

    /* Protected methods */
    protected {
        string thisExeDir () {
            import std.path : dirName;
            return dirName (thisExePath ());
        }

        final void loadGameInfo () {
            import std.file : FileException;
            import std.path : isAbsolute, absolutePath;

            auto gameInfoPath = buildPath (thisExeDir (), gameInfoFile);

            // Error out if gameinfo.toml is missing.
            if (!exists (gameInfoPath)) {
                displayFatalError ("Could not find gameinfo.toml");
                return;
            }

            // Create the game info struct.
            gameInfo = TwineGameInfo ();

            /* Load the game info */
            try {
                string gameinfoText = readText (gameInfoPath);
                auto gameinfoToml = cast (const (TOMLDocument)) (parseTOML (gameinfoText));

                if (auto name = "gameName" in gameinfoToml)
                    gameInfo.gameName = name.str;

                if (auto path = "tweePath" in gameinfoToml)
                    gameInfo.tweePath = path.str;

                if (auto path = "fontPath" in gameinfoToml)
                    gameInfo.fontPath = path.str;
            } catch (FileException e) {
                displayFatalError ("Could not read gameinfo.toml");
                return;
            } catch (std.utf.UTFException e) {
                displayFatalError ("Encountered a UTF-8 error while decoding gameinfo.toml");
                return;
            } catch (TOMLParserException e) {
                displayFatalError (format ("TOML parsing error at line %d:%d:\n  %s", e.position.line, e.position.column, e.message));
                return;
            }

            /* Load the font */
            if (!gameInfo.fontPath || gameInfo.fontPath.length < 1) {
                displayFatalError ("Game info key \"fontPath\" is required and cannot be missing or empty.");
                return;
            }

            if (!isAbsolute (gameInfo.fontPath))
                gameInfo.fontPath = absolutePath (gameInfo.fontPath, thisExeDir ());

            if (!exists (gameInfo.fontPath)) {
                displayFatalError (format ("Could not find font file \"%s\"", gameInfo.fontPath));
                return;
            }

            // Try to load the font file.
            try {
                string fontFileContents = readText (gameInfo.fontPath);

                // Remove the UTF-8 BOM if there's any.
                if (fontFileContents.length >= 3 && fontFileContents [0 .. 3] == [ 0xEF, 0xBB, 0xBF ])
                    fontFileContents = fontFileContents [2 .. $];

                textFont = TwineSMSFont.create (fontFileContents);
            } catch (FileException e) {
                displayFatalError (format ("Could not read font file \"%s\".", gameInfo.fontPath));
                return;
            } catch (std.utf.UTFException e) {
                displayFatalError (format ("Encountered a UTF-8 error while decoding font file \"%s\".", gameInfo.fontPath));
                return;
            }

            /* Load the twee file */
            if (!gameInfo.tweePath || gameInfo.tweePath.length < 1) {
                displayFatalError ("Game info key \"tweePath\" is required and cannot be missing or empty.");
                return;
            }

            if (!isAbsolute (gameInfo.tweePath))
                gameInfo.tweePath = absolutePath (gameInfo.tweePath, thisExeDir ());

            if (!exists (gameInfo.tweePath)) {
                displayFatalError (format ("Could not find twee file \"%s\"", gameInfo.tweePath));
                return;
            }

            try {
                string tweeFileContents = readText (gameInfo.tweePath);

                if (tweeFileContents.length >= 3 && tweeFileContents [0 .. 3] == [ 0xEF, 0xBB, 0xBF ])
                    tweeFileContents = tweeFileContents [2 .. $];

                TwineParser parser = new TwineParser ();

                gameData = parser.parseTweeFile (tweeFileContents);
            } catch (FileException e) {
                displayFatalError (format ("Could not read twee file \"%s\".", gameInfo.tweePath));
                return;
            } catch (std.utf.UTFException e) {
                displayFatalError (format ("Encountered a UTF-8 error while decoding twee file \"%s\".", gameInfo.tweePath));
                return;
            } catch (TweeParserException e) {
                displayFatalError (format ("Twee parsing error at line %d:%d:\n  %s", e.position.line, e.position.column, e.message));
                return;
            }

            /* Create the virtual machine */
            virtualMachine = new TwineVirtualMachine (gameData);
            virtualMachine.setImageCallback = &setImage;
            virtualMachine.showFatalErrorCallback = &displayFatalError;

            mainWindow.setTitle (gameInfo.gameName);
        }

        void setImage (string name) {
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

        final void displayFatalError (string err) {
            imageError = err.wrap (36);
            imageHidden = true;
        }

        void focusLost () {
            windowFocused = false;
        }

        void focusGained () {
            windowFocused = true;
        }

        void keyPressed_Confirm () {
            virtualMachine.playerInput (selectionIndex);
        }

        void keyPressed_SelUp () {

        }

        void keyPressed_SelDown () {

        }
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

    final void run () {
        mainWindow.setFramerateLimit (60);

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
                        // Z and X (Confirmation keys)
                        if (event.key.code == Keyboard.Key.Z)
                            zPressed = true;
                        else if (event.key.code == Keyboard.Key.X)
                            xPressed = true;

                        // Arrow keys (Selection keys)
                        if (event.key.code == Keyboard.Key.Up)
                            upPressed = true;
                        else if (event.key.code == Keyboard.Key.Down)
                            downPressed = true;
                        else if (event.key.code == Keyboard.Key.Left)
                            leftPressed = true;
                        else if (event.key.code == Keyboard.Key.Right)
                            rightPressed = true;
                    break;

                    case Event.EventType.KeyReleased:
                        // Z and X (Confirmation keys)
                        if (event.key.code == Keyboard.Key.Z) {
                            if (zPressed)
                                keyPressed_Confirm ();

                            zPressed = false;
                        } else if (event.key.code == Keyboard.Key.X) {
                            if (xPressed)
                                keyPressed_Confirm ();

                            xPressed = false;
                        }

                        // Arrow keys (Selection keys)
                        if (event.key.code == Keyboard.Key.Up) {
                            if (upPressed)
                                keyPressed_SelUp ();

                            upPressed = false;
                        } else if (event.key.code == Keyboard.Key.Down) {
                            if (downPressed)
                                keyPressed_SelDown ();

                            downPressed = false;
                        } else if (event.key.code == Keyboard.Key.Left) {
                            if (leftPressed)
                                keyPressed_SelUp ();

                            leftPressed = false;
                        } else if (event.key.code == Keyboard.Key.Right) {
                            if (rightPressed)
                                keyPressed_SelDown ();

                            rightPressed = false;
                        }
                    break;

                    default:
                    break;
                }
            }

            if (virtualMachine)
                virtualMachine.run ();

            doRender ();
        }
    }
}
