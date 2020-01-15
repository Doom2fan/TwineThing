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

module gme;

import core.stdc.stdlib;
import core.stdc.config : c_long;
import std.string : fromStringz, toStringz;
import std.variant : Algebraic;
import std.uni : toLower;

enum GmeType {
    Unknown,

    AY,
    GBS,
    GYM,
    HES,
    KSS,
    NSF,
    NSFE,
    SAP,
    SPC,
    VGM,
    VGZ,
}

alias GmeError = Algebraic!(GmeErrorType, string);

enum GmeErrorType {
    None,
    NoEmu,
    WrongFileType,
}

private GmeError identifyError (gme_err_t errStr) {
    if (!errStr)
        return GmeError (GmeErrorType.None);
    else if (errStr == gme_wrong_file_type)
        return GmeError (GmeErrorType.WrongFileType);
    else
        return GmeError (fromStringz (errStr).idup);
}

class GmeMusicEmu {
    private {
        gme_MusicEmu musicEmu;
        gme_cstr filePath;
        int _sampleRate;
    }

    this () {
        musicEmu = null;
        _sampleRate = 0;
    }

    ~this () {
        deleteEmu ();
    }

    GmeError openFile (string path, int newSampleRate) {
        if (musicEmu)
            gme_delete (musicEmu);

        filePath = toStringz (path);

        auto errStr = gme_open_file (filePath, &musicEmu, newSampleRate);
        auto gmeErr = identifyError (errStr);

        if (gmeErr != GmeErrorType.None)
            deleteEmu ();
        else {
            _sampleRate = newSampleRate;
        }

        return gmeErr;
    }

    GmeError openFile (void[] data, int newSampleRate) {
        if (musicEmu)
            gme_delete (musicEmu);

        auto errStr = gme_open_data (&(data [0]), data.length, &musicEmu, newSampleRate);
        auto gmeErr = identifyError (errStr);

        if (gmeErr != GmeErrorType.None)
            deleteEmu ();
        else {
            _sampleRate = newSampleRate;
        }

        return gmeErr;
    }

    @property int sampleRate () {
        if (!musicEmu)
            return 0;

        return _sampleRate;
    }

    int getTrackCount () {
        if (!musicEmu)
            return 0;

        return gme_track_count (musicEmu);
    }

    GmeError startTrack (int idx) {
        if (!musicEmu)
            return GmeError (GmeErrorType.NoEmu);

        auto errStr = gme_start_track (musicEmu, idx);
        auto gmeErr = identifyError (errStr);

        if (gmeErr != GmeErrorType.None)
            deleteEmu ();

        return gmeErr;
    }

    GmeError getSamples (short[] samples, int count = -1) {
        if (!musicEmu)
            return GmeError (GmeErrorType.NoEmu);

        if (count == -1)
            count = samples.length;

        if (count > samples.length)
            return GmeError ("Count cannot be greater than the length of the samples array.");

        auto errStr = gme_play (musicEmu, count, &(samples [0]));
        auto gmeErr = identifyError (errStr);

        if (gmeErr != GmeErrorType.None)
            deleteEmu ();

        return gmeErr;
    }

    bool trackEnded () {
        if (!musicEmu)
            return true;

        return gme_track_ended (musicEmu) != 0;
    }

    void deleteEmu () {
        if (musicEmu)
            gme_delete (musicEmu);

        musicEmu = null;
        _sampleRate = 0;
    }

    static GmeType identifyFile (string fileName) {
        import std.file : read;

        auto bytes = read (fileName, 16);
        return identifyFile (bytes);
    }

    static GmeType identifyFile (void[] bytes) {
        auto cTypeStr = gme_identify_header (&(bytes [0]));
        auto typeStr = fromStringz (cTypeStr);

        free (cast (void*) cTypeStr);

        switch (typeStr.toLower ()) {
            case "ay"  : return GmeType.AY;
            case "gbs" : return GmeType.GBS;
            case "gym" : return GmeType.GYM;
            case "hes" : return GmeType.HES;
            case "kss" : return GmeType.KSS;
            case "nsf" : return GmeType.NSF;
            case "nsfe": return GmeType.NSFE;
            case "sap" : return GmeType.SAP;
            case "spc" : return GmeType.SPC;
            case "vgm" : return GmeType.VGM;
            case "vgz" : return GmeType.VGZ;

            default: return GmeType.Unknown;
        }
    }
}

private alias gme_cstr = const (char)*;
private alias gme_err_t = gme_cstr;
private alias gme_MusicEmu = void*;

extern (C) {
    // Identifies the file type.
    private gme_cstr gme_identify_header (const void* header);

    // Create emulator and load game music data into it. Sets *out to new emulator.
    private gme_err_t gme_open_file (gme_cstr path, gme_MusicEmu* emu, int sample_rate);

    // Same as gme_open_file(), but uses file data already in memory. Makes copy of data.
    // The resulting Music_Emu object will be set to single channel mode.
    private gme_err_t gme_open_data (const (void*) data, c_long size, gme_MusicEmu* emu, int sample_rate);

    // Number of tracks available.
    private int gme_track_count (const (gme_MusicEmu) emu);

    // Start a track, where 0 is the first track.
    private gme_err_t gme_start_track (gme_MusicEmu, int index);

    // Generate 'count' 16-bit signed samples info 'out'. Output is in stereo.
    private gme_err_t gme_play (gme_MusicEmu, int count, short* output);

    // True if a track has reached its end.
    private int gme_track_ended (const (gme_MusicEmu));

    // Finish using emulator and free memory.
    private void gme_delete (gme_MusicEmu);

    // Error types.
    private __gshared const (const (char)*)  gme_wrong_file_type;

}
