/*
 *  TwineThing
 *  Copyright (C) 2019-2020 Chronos "phantombeta" Ouroboros
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

module gmemusic;

import dsfml.system : Duration;
import dsfml.audio.soundstream;
import dsfml.system.mutex : Mutex;
import dsfml.system.lock : Lock;

import gme;

class GmeErrorException : Exception {
    this (string message, string file = __FILE__, int _line = __LINE__) { // @suppress(dscanner.style.undocumented_declaration)
        super (message, file, _line);
    }
}

class GmeMusic : SoundStream {
    private {
        GmeMusicEmu _emu;
        int _sampleRate;

        Mutex _mutex;
        short[] _samples;
    }

    this (int sampleRate = 44_100) {
        _emu = new GmeMusicEmu ();
        _sampleRate = sampleRate;

        _mutex = new Mutex ();

        super ();
    }

    static void[] decompressGzip (const (void)[] data) {
        import std.zlib : uncompress;

        static const ubyte[] gzipMagic = [ 0x1f, 0x8B ];

        auto dataAsBytes = cast (const (ubyte)[]) data;
        if (dataAsBytes [0 .. 2] != gzipMagic)
            return null;

        int destLen = *(cast (uint*)&(data [$ - 4]));

        return uncompress (data, destLen, 30);
    }

    /**
     ** Open a music from a video game music file.
     **
     ** This function doesn't start playing the music (call `play ()` to do so).
     **
     ** Supports pretty much anything GME was built with support for.
     **
     ** Params:
     **  filename = Path of the music file to open.
     **  trackNum = The number of the track to play.
     **
     ** Returns: true if loading succeeded, false if it failed.
    */
    bool openFromFile (string filePath, int trackNum = 0) {
        import std.file : read;

        // Stop music if already playing
        stop ();

        initialize ();

        auto fileType = GmeMusicEmu.identifyFile (filePath);
        _emu.deleteEmu ();

        GmeError errType;
        if (fileType != GmeType.Unknown && fileType != GmeType.VGZ)
            errType = _emu.openFile (filePath, _sampleRate);
        else if (fileType == GmeType.VGZ) {
            auto data = decompressGzip (read (filePath));
            errType = _emu.openFile (data, _sampleRate);
        } else
            return false;

        if (errType == GmeErrorType.None)
            _emu.startTrack (trackNum);

        return true;
    }

    /**
     ** Open a music from a video game music file in memory.
     **
     ** This function doesn't start playing the music (call `play ()` to do so).
     **
     ** Supports pretty much anything GME was built with support for.
     **
     ** Params:
     **  data = The music file in memory to open.
     **  trackNum = The number of the track to play.
     **
     ** Returns: true if loading succeeded, false if it failed.
    */
    bool openFromMemory (void[] data, int trackNum = 0) {
        import std.file : read;

        // Stop music if already playing
        stop ();

        initialize ();

        auto fileType = GmeMusicEmu.identifyFile (data);
        _emu.deleteEmu ();

        if (fileType == GmeType.VGZ)
            data = decompressGzip (data);

        GmeError errType;
        if (fileType != GmeType.Unknown)
            errType = _emu.openFile (data, _sampleRate);
        else
            return false;

        if (errType == GmeErrorType.None)
            _emu.startTrack (trackNum);

        return true;
    }

    /**
     ** Starts a new track.
     **
     ** Params:
     **  trackNum = The number of the track to play.
    */
    void setTrack (int trackNum) {
        _emu.startTrack (trackNum);
    }

    protected {
        /**
         ** Request a new chunk of audio samples from the stream source.
         **
         ** This function fills the chunk from the next samples to read from the
         ** audio file.
         **
         ** Params:
         **  samples = Array of samples to fill.
         **
         ** Returns: true to continue playback, false to stop.
        */
        override bool onGetData (ref const (short)[] samples) {
            auto lock = Lock (_mutex); // @suppress(dscanner.suspicious.unused_variable)

            _emu.getSamples (_samples);
            samples = _samples [0 .. $];

            return true;//!_emu.trackEnded ();
        }

        /// NOT IMPLEMENTED
        override void onSeek (Duration timeOffset) { }
    }

    private {
        /**
         * Define the audio stream parameters.
         *
         * This function must be called by derived classes as soon as they know
         * the audio settings of the stream to play. Any attempt to manipulate
         * the stream (play (), ...) before calling this function will fail.
         *
         * It can be called multiple times if the settings of the audio stream
         * change, but only when the stream is stopped.
         */
        void initialize () {
            const uint channelCount = 2; // GME is always stereo.
            // Resize the internal buffer so that it can contain 1 second of audio samples.
            _samples.length = _sampleRate * channelCount;

            // Initialize the stream
            super.initialize (channelCount, _sampleRate);
        }
    }
}