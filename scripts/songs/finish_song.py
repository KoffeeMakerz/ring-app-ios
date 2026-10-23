#!/usr/bin/env python3
"""Finish an ElevenLabs song for the app.

  analyse:  python3 finish_song.py analyse song.mp3
            -> estimated key (is it C-compatible for 528?) and a loudness map to find the
               choruses (cue markers) and the break (handover between feelings).
  finish:   python3 finish_song.py finish song.mp3 out.mp3 [--tone-db -36] [--no-tone] [--title "Home (chill)"]
            -> retunes A=440 -> A=444 (+15.67 cents, tempo unchanged) so C = 528 Hz,
               adds a very quiet 528 Hz + 264 Hz layer that slowly swells and fades,
               normalises to -16 LUFS and exports 192 kbps MP3.
            Use --no-tone when the song's key doesn't contain C (the 528 layer would clash);
            the A=444 tuning is still applied.
            Use --no-tone when the song's key doesn't contain C (the 528 layer would clash);
            the A=444 tuning is still applied.

Needs ffmpeg (with rubberband) and numpy. No health claims: in the app it's "tuned to 528 Hz".
"""
import subprocess, sys, json
import numpy as np

SR = 44100
NOTES = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
MAJOR = np.array([6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88])
MINOR = np.array([6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17])

def decode(path):
    raw = subprocess.run(["ffmpeg","-v","error","-i",path,"-ac","1","-ar",str(SR),"-f","f32le","-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)

def analyse(path):
    x = decode(path); dur = len(x)/SR
    # chroma from long FFT frames
    n = 16384; hop = 8192; chroma = np.zeros(12)
    freqs = np.fft.rfftfreq(n, 1/SR); ok = (freqs > 60) & (freqs < 2000)
    pc = (np.round(12*np.log2(freqs[ok]/440.0)) + 9) % 12
    win = np.hanning(n)
    for i in range(0, len(x)-n, hop):
        mag = np.abs(np.fft.rfft(x[i:i+n]*win))[ok]
        np.add.at(chroma, pc.astype(int), mag)
    chroma /= chroma.sum()
    best = []
    for k in range(12):
        for name, prof in (("major", MAJOR), ("minor", MINOR)):
            best.append((np.corrcoef(np.roll(prof, k), chroma)[0,1], f"{NOTES[k]} {name}"))
    best.sort(reverse=True)
    # loudness map, 2 s windows
    w = 2*SR
    rms = [20*np.log10(np.sqrt(np.mean(x[i:i+w]**2))+1e-9) for i in range(0, len(x)-w+1, w)]
    print(json.dumps({"duration_s": round(dur,1),
                      "key_candidates": [(k, round(c,3)) for c,k in best[:3]],
                      "c_strength": round(float(chroma[0]),3),
                      "rms_db_per_2s": [round(float(r),1) for r in rms]}))

def finish(src, dst, tone_db=-36.0, with_tone=True, title=None):
    dur = len(decode(src))/SR
    ratio = 444/440
    retune = (f"aresample={SR},aformat=channel_layouts=stereo,"
              f"rubberband=pitch={ratio}:pitchq=quality:transients=mixed:formant=preserved")
    loud = "loudnorm=I=-16:TP=-1.5:LRA=11"
    if with_tone:
        # quiet 528/264 layer: slow swell (0.04 Hz) between 40% and 100% of its level, fades with the song
        amp = 10**(tone_db/20)
        tone = (f"aevalsrc='{amp}*(0.7+0.3*sin(2*PI*0.04*t))*(0.75*sin(2*PI*528*t)+0.25*sin(2*PI*264*t))"
                f"':s={SR}:d={dur:.2f},afade=t=in:d=8,afade=t=out:st={max(0,dur-10):.2f}:d=10,aformat=channel_layouts=stereo")
        fc = f"[0:a]{retune}[m];{tone}[t];[m][t]amix=inputs=2:weights=1 1:normalize=0,{loud}[o]"
    else:
        fc = f"[0:a]{retune},{loud}[o]"
    # The source's tags are dropped (-map_metadata -1) and replaced with the app's own.
    meta = ["-map_metadata","-1","-id3v2_version","3",
            "-metadata",f"title={title or dst.rsplit('/',1)[-1].rsplit('.',1)[0]}",
            "-metadata","artist=PulseLoop","-metadata","album=PulseLoop Feel Songs",
            "-metadata","comment=Tuned to A=444 (C=528 Hz)"]
    subprocess.run(["ffmpeg","-v","error","-y","-i",src,"-filter_complex",fc,"-map","[o]",
                    "-ar",str(SR),"-c:a","libmp3lame","-b:a","192k",*meta,dst], check=True)
    print("wrote", dst)

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "analyse": analyse(sys.argv[2])
    elif cmd == "finish":
        db = float(sys.argv[sys.argv.index("--tone-db")+1]) if "--tone-db" in sys.argv else -36.0
        title = sys.argv[sys.argv.index("--title")+1] if "--title" in sys.argv else None
        finish(sys.argv[2], sys.argv[3], db, "--no-tone" not in sys.argv, title)
