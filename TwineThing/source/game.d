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

import std.algorithm : min, max;
import std.file : exists, readText, thisExePath;
import std.path : buildPath;
import std.format : format;

import dsfml.system;
import dsfml.window;
import dsfml.graphics;
import dsfml.audio;

import gamedata;
import tomlconfig;
import smsfont;
import smstext;
import gme : GmeMusicEmu, GmeType;
import gmemusic : GmeMusic;
import utilities : wrap, ParseColourError, parseColourString, dsfmlColorFromArgbInt;

import twineparser.parser;
import twinevm.vm;

/**
 ** The main game class.
*/
class TwineGame {
    /* Protected members */
    protected {
        static const string gameInfoFile = "gameinfo.toml";

        bool initFailed;
        RenderWindow mainWindow;
        View curView;
        bool windowFocused = false;

        // Controls
        bool zPressed     = false;
        bool xPressed     = false;
        bool upPressed    = false;
        bool downPressed  = false;
        bool leftPressed  = false;
        bool rightPressed = false;

        // System
        Font systemFont;

        // Image
        Texture imageTex;
        Sprite imageSprite;
        bool imageHidden;
        string imageError;
        Text imageText;

        // Text
        TwineSMSFont textFont;
        TwineSMSText textData;
        RectangleShape textBackground;

        // Selection
        int selectionIndex = 0;
        int maxSelectionIndex = 0;
        TwineSelection[] curSelections;
        TwineSMSText selectionMarker;
        Sound selectionBeepSound;

        SoundBuffer selectionBeepSoundBuffer;

        // Music
        GmeMusic gmeMusicPlayer;
        Music dsfmlMusicPlayer;

        TwineVMState prevVMState;
    }

    /* Public members */
    public {
        /// The game info.
        TwineGameInfo gameInfo;
        /// The game data.
        TwineGameData gameData;
        /// The Twine VM.
        TwineVirtualMachine virtualMachine;
    }

    /* Protected methods */
    protected {
        string thisExeDir () {
            import std.path : dirName;
            return dirName (thisExePath ());
        }

        final string loadTextLump (string path, string fileType) {
            import std.file : FileException;
            import std.path : isAbsolute, absolutePath;

            if (!isAbsolute (path))
                path = absolutePath (path, thisExeDir ());

            if (!exists (path)) {
                displayFatalError (format ("Could not find %s \"%s\"", fileType, path));
                return null;
            }

            try {
                string fileContents = readText (path);

                if (!fileContents)
                    return "";

                if (fileContents.length >= 3 && fileContents [0 .. 3] == [ 0xEF, 0xBB, 0xBF ])
                    fileContents = fileContents [3 .. $];

                return fileContents;
            } catch (FileException e) {
                displayFatalError (format ("Could not read %s \"%s\".", fileType, path));
                return null;
            } catch (std.utf.UTFException e) {
                displayFatalError (format ("Encountered a UTF-8 error while decoding %s \"%s\".", fileType, path));
                return null;
            }

            assert (0);
        }

        final bool parseColourVar (in string colStr, out uint colVar) {
            auto parsedCol = cast (const) parseColourString (colStr);

            if (auto errCode = parsedCol.peek!ParseColourError) {
                string errMsg = null;

                if (*errCode == ParseColourError.InvalidHexColour)
                    errMsg = format ("Invalid hex colour \"%s\"", colStr);
                else if (*errCode == ParseColourError.InvalidRGBTriplet)
                    errMsg = format ("Invalid RGB triplet \"%s\"", colStr);
                else if (*errCode == ParseColourError.RGBTripletOutOfRange)
                    errMsg = format ("RGB triplet \"%s\" out of range [0-255]", colStr);

                displayFatalError (format ("Invalid colour code in game info key \"backgroundColour\": %s.", errMsg));
                return false;
            }

            colVar = parsedCol.get!uint;
            return true;
        }

        final void loadGameInfo () {
            import std.file : FileException;

            auto gameInfoPath = buildPath (thisExeDir (), gameInfoFile);

            // Error out if gameinfo.toml is missing.
            if (!exists (gameInfoPath)) {
                displayFatalError ("Could not find gameinfo.toml");
                initFailed = true;
                return;
            }

            // Create the game info struct.
            gameInfo = TwineGameInfo ();

            /* Load the game info */
            string bgColourString = "#000000";
            string textColourString = "#FFFFFF";
            try {
                string gameinfoText = readText (gameInfoPath);

                parseTomlConfig (gameinfoText, [
                    TomlConfigMember (&gameInfo.gameName, "gameName"),

                    TomlConfigMember (&gameInfo.tweePath, "tweePath", TomlConfigFlag.Required),
                    TomlConfigMember (&gameInfo.fontPath, "fontPath", TomlConfigFlag.Required),

                    TomlConfigMember (&gameInfo.selectionBeepPath, "selectionBeepPath", TomlConfigFlag.Required),

                    TomlConfigMember (&bgColourString, "backgroundColour"),
                    TomlConfigMember (&textColourString, "textColour"),

                    TomlConfigMember (&gameInfo.imageWidth, "imageWidth", TomlConfigFlag.Required),
                    TomlConfigMember (&gameInfo.imageHeight, "imageHeight", TomlConfigFlag.Required),

                    TomlConfigMember (&gameInfo.windowWidth, "windowWidth", TomlConfigFlag.Required),
                    TomlConfigMember (&gameInfo.windowHeight, "windowHeight", TomlConfigFlag.Required),

                    TomlConfigMember (&gameInfo.textStartHeight, "textStartHeight", TomlConfigFlag.Required),
                ]);
            } catch (FileException e) {
                displayFatalError ("Could not read gameinfo.toml");
                initFailed = true;
                return;
            } catch (std.utf.UTFException e) {
                displayFatalError ("Encountered a UTF-8 error while decoding gameinfo.toml");
                initFailed = true;
                return;
            } catch (TomlConfigException_TomlParsingError e) {
                import toml : TOMLParserException;

                auto tomlException = cast (TOMLParserException) e.innerException;

                displayFatalError (
                    format ("TOML parsing error at line %d:%d:\n  %s",
                        tomlException.position.line,
                        tomlException.position.column,
                        tomlException.message
                    )
                );
                initFailed = true;

                return;
            } catch (TomlConfigException_MissingRequiredKey e) {
                displayFatalError (format ("Game info key \"%s\" is required and cannot be missing.", e.tomlKeyName));
                initFailed = true;
                return;
            } catch (TomlConfigException_KeyTypeMismatch e) {
                displayFatalError (format ("Game info key \"%s\" type mismatch: Expected %s, got %s.", e.tomlKeyName,
                    e.expectedType, e.receivedType
                ));
                initFailed = true;
                return;
            }

            if (!parseColourVar (bgColourString, gameInfo.backgroundColour))
                return;
            if (!parseColourVar (textColourString, gameInfo.textColour))
                return;

            static const keysToValidate = [
                "gameInfo.imageWidth",
                "gameInfo.imageHeight",
                "gameInfo.windowWidth",
                "gameInfo.windowHeight"
            ];
            static foreach (keyName; keysToValidate) {
                if (mixin (keyName) < 1) {
                    displayFatalError (format ("Game info key \"%s\" cannot be zero or negative", keyName));
                    initFailed = true;
                    return;
                }
            }

            /* Load the font */
            if (gameInfo.fontPath.length < 1) {
                displayFatalError ("Game info key \"fontPath\" is required and cannot be empty.");
                initFailed = true;
                return;
            }

            try {
                string fontFileContents = loadTextLump (gameInfo.fontPath, "font");
                textFont = TwineSMSFont.create (fontFileContents);
            } catch (TwineSMSFontException e) {
                displayFatalError (cast (string) e.message);
                initFailed = true;
                return;
            }

            /* Load the twee file */
            if (gameInfo.tweePath.length < 1) {
                displayFatalError ("Game info key \"tweePath\" is required and cannot be empty.");
                initFailed = true;
                return;
            }

            try {
                string tweeFileContents = loadTextLump (gameInfo.tweePath, "twee");

                TwineParser parser = new TwineParser ();
                gameData = parser.parseTweeFile (tweeFileContents);
            } catch (TweeParserException e) {
                displayFatalError (
                    format (
                        "Twee parsing error at line %d:%d:\n  %s",
                        e.position.line,
                        e.position.column,
                        e.message
                    )
                );
                initFailed = true;
                return;
            }

            if (!("Start" in gameData.passages)) {
                displayFatalError ("The twee file has no \"Start\" passage.");
                initFailed = true;
                return;
            }

            /* Load sounds */
            if (gameInfo.selectionBeepPath && gameInfo.selectionBeepPath.length > 0) {
                selectionBeepSoundBuffer = new SoundBuffer ();

                if (!selectionBeepSoundBuffer.loadFromFile (gameInfo.selectionBeepPath)) {
                    displayFatalError (format ("Sound file \"%s\" could not be loaded.", gameInfo.selectionBeepPath));
                    initFailed = true;
                    return;
                }

                selectionBeepSound = new Sound ();
                selectionBeepSound.setBuffer (selectionBeepSoundBuffer);
            } else {
                selectionBeepSoundBuffer = null;
                selectionBeepSound = null;
            }

            /* Calculate some things */
            gameInfo.lineMaxLen = gameInfo.windowWidth - 2;

            /* Create the virtual machine */
            virtualMachine = new TwineVirtualMachine (gameInfo, gameData);
            virtualMachine.setTextCallback = &setText;
            virtualMachine.setImageCallback = &setImage;
            virtualMachine.setMusicCallback = &setMusic;
            virtualMachine.setSelectionsCallback = &setSelections;
            virtualMachine.showFatalErrorCallback = &displayFatalError;

            /* Update the render elements */
            textData.font = textFont;
            textData.position = Vector2f (8, gameInfo.textStartHeight * 8);

            selectionMarker.font = textFont;

            mainWindow.setTitle (gameInfo.gameName);
            mainWindow.size = Vector2u (gameInfo.windowWidth * CHARBLOCKSIZE, gameInfo.windowHeight * CHARBLOCKSIZE);
            curView = mainWindow.view.dup;
            resized (mainWindow.size.x, mainWindow.size.y);

            textBackground.size = Vector2f (
                gameInfo.windowWidth * CHARBLOCKSIZE,
                (gameInfo.windowHeight - gameInfo.textStartHeight) * CHARBLOCKSIZE
            );
            textBackground.position = Vector2f (0, gameInfo.textStartHeight * CHARBLOCKSIZE);
            textBackground.fillColor = dsfmlColorFromArgbInt (gameInfo.backgroundColour);

            initFailed = false;
        }

        void setImage (string name) {
            if (!name || name.length == 0) {
                imageHidden = true;
                imageError = null;

                return;
            }

            auto filePath = buildPath (thisExeDir (), "images/", name);
            if (!exists (filePath)) {
                displayFatalError (format ("Could not find image file \"%s\"", name));
                return;
            }

            if (!imageTex.loadFromFile (filePath)) {
                displayFatalError (format ("Image file \"%s\" could not be loaded.", name));
                return;
            }

            imageSprite.setTexture (imageTex);
            imageHidden = false;
            imageError = null;
        }

        void setText (string text) {
            textData.text = text;
        }

        void setMusic (string music, int trackNum) {
            if (!music || music.length == 0) {
                gmeMusicPlayer.stop ();
                dsfmlMusicPlayer.stop ();

                return;
            }

            auto filePath = buildPath (thisExeDir (), "music/", music);
            if (!exists (filePath)) {
                gmeMusicPlayer.stop ();
                dsfmlMusicPlayer.stop ();

                displayFatalError (format ("Could not find music file \"%s\"", music));
                return;
            }

            gmeMusicPlayer.stop ();
            dsfmlMusicPlayer.stop ();

            if (gmeMusicPlayer.openFromFile (filePath, trackNum)) {
                gmeMusicPlayer.play ();
            } else if (dsfmlMusicPlayer.openFromFile (music)) {
                dsfmlMusicPlayer.play ();
            } else {
                displayFatalError (format ("Music file \"%s\" could not be read.", music));
                return;
            }
        }

        void setSelections (TwineSelection[] selections) {
            import std.array : appender;

            if (!selections || selections.length < 1) {
                curSelections = null;

                selectionIndex = 0;
                maxSelectionIndex = 0;

                selectionMarker.text = "";

                return;
            }

            curSelections = selections;
            selectionIndex = 0;
            maxSelectionIndex = selections.length;

            auto newText = appender!string ("");
            newText.reserve (50);
            foreach (selection; selections) {
                newText.put (selection.text);
                newText.put ('\n');
            }
            setText (newText []);

            selectionMarker.text = "~";
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

        void resized (uint width, uint height) {
            double screenWidth = gameInfo.windowWidth * CHARBLOCKSIZE;
            double screenHeight = gameInfo.windowHeight * CHARBLOCKSIZE;

            curView.size = Vector2f (screenWidth, screenHeight);

            double scale = min (width / screenWidth, height / screenHeight);

            auto finalW = (screenWidth * scale) / width;
            auto finalH = (screenHeight * scale) / height;

            auto left = (1. - finalW) / 2.;
            auto top = (1. - finalH) / 2.;

            curView.viewport = FloatRect (left, top, finalW, finalH);

            mainWindow.view = curView;
        }

        void keyPressed_Confirm () {
            if (selectionBeepSound && maxSelectionIndex > 1)
                selectionBeepSound.play ();

            virtualMachine.playerInput (selectionIndex);
        }

        void keyPressed_SelUp () {
            if (maxSelectionIndex < 1 || selectionIndex < 1)
                return;

            selectionIndex--;
            if (selectionBeepSound)
                selectionBeepSound.play ();
        }

        void keyPressed_SelDown () {
            if (maxSelectionIndex < 1 || selectionIndex >= (maxSelectionIndex - 1))
                return;

            selectionIndex++;
            if (selectionBeepSound)
                selectionBeepSound.play ();
        }
    }

    /// Initializes the game class.
    final void initialize () {
        // Create the window
        auto contextSet = cast (const (ContextSettings)) ContextSettings (24, 8, 0, 3, 0);
        mainWindow = new RenderWindow (VideoMode (256, 192), "TwineThing"d, Window.Style.DefaultStyle, contextSet);
        curView = new View (FloatRect (0, 0, 256, 192));

        // Load the system font
        systemFont = new Font ();
        systemFont.loadFromFile (buildPath (thisExeDir (), "resources/CourierPrime.ttf"));

        // Create the image data and elements
        imageTex = new Texture ();
        imageSprite = new Sprite ();
        imageSprite.position (Vector2f (0, 0));
        imageText = new Text ();
        imageText.setFont (systemFont);
        imageText.setCharacterSize (12);
        imageText.setColor (Color.White);

        // Create the text data and elements
        textData = new TwineSMSText ();
        textBackground = new RectangleShape (Vector2f (0, 0));

        // Create the selection data and elements
        selectionMarker = new TwineSMSText ();

        // Create the music data
        gmeMusicPlayer = new GmeMusic ();
        dsfmlMusicPlayer = new Music ();

        // Load the game data
        loadGameInfo ();

        Joystick.update ();
    }

    protected void doUpdate () {
        selectionMarker.position = Vector2f (0, (gameInfo.textStartHeight * 8) + (selectionIndex * 8));
    }

    protected void doRender () {
        /* Clear the window */
        mainWindow.clear (dsfmlColorFromArgbInt (gameInfo.backgroundColour));

        if (!imageError && !imageHidden)
            mainWindow.draw (imageSprite);
        else if (imageError) {
            imageText.setString (imageError);
            mainWindow.draw (imageText);
        }

        mainWindow.draw (textBackground);
        mainWindow.draw (textData);
        mainWindow.draw (selectionMarker);

        /* Display the window */
        mainWindow.display ();
    }

    /// Runs the game loop.
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

                    case Event.EventType.Resized:
                        resized (event.size.width, event.size.height);
                    break;

                    case Event.EventType.KeyPressed:
                        // Ignore input if the initialization failed
                        if (initFailed)
                            break;

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
                        // Ignore input if the initialization failed
                        if (initFailed)
                            break;

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

            if (!initFailed && virtualMachine)
                virtualMachine.run ();

            doUpdate ();
            doRender ();
        }
    }
}
