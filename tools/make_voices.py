"""Voices the NPC phrases of config/replics/language/sh_<lang>.lua with XTTS-v2 (the mlp-g5 pipeline's worker).

Writes sound/background_npcs/vo/<lang>/<line id>/<index>[_f].ogg, which actor/cl_actor_voice.lua plays:
  police lines (defense_police, police_*, police roles of conversations): a male voice through a radio filter
  with a squelch at both ends
  citizen lines (everything else): a male take and a female one (_f)
Speakers rotate by the phrase's index, so the crowd sounds like many people; in a conversation
(config/states/sh_conversations.lua) each participant keeps one voice.
Only changed lines are voiced again (tools/voices_state.json); clips of removed lines are deleted.

Run:  D:/mlp-g5-work/tools/tts_venv/Scripts/python tools/make_voices.py [--force] [--only <line id>]
Needs ffmpeg on PATH, the XTTS setup of D:/mlp-g5-work/pipeline/scripts/voice_tts.py (and its dxRevive for citizens).
"""
from pathlib import Path
import argparse, json, subprocess, sys, tempfile, wave
from lupa import LuaRuntime

sys.path.insert(0, 'D:/mlp-g5-work/pipeline/scripts')
import voice_tts as v  # synth_xtts (the worker), revive (dxRevive)

ROOT = Path(__file__).resolve().parent.parent
LANGS = {'english': 'en', 'russian': 'ru'}
SRC = ROOT / 'lua/background_npcs_core/config/replics/language'
OUT = ROOT / 'sound/background_npcs/vo'
STATE = Path(__file__).resolve().parent / 'voices_state.json'
CONVERSATIONS = ROOT / 'lua/background_npcs_core/config/states/sh_conversations.lua'

POLICE = ['Damien Black', 'Torcull Diarmuid']
MALE = ['Ilkin Urbano', 'Viktor Menelaos', 'Luis Moray']
FEMALE = ['Sofia Hellen', 'Ana Florence', 'Tammy Grit']

# a radio mask (our own take on a metrocop): narrow band, crushed, compressed, a little metallic ring
RADIO = ('asetrate=24000*0.92,atempo=1/0.92,aresample=24000,'
         'highpass=f=380,lowpass=f=3300,acompressor=threshold=-26dB:ratio=8:attack=3:release=50,'
         'acrusher=bits=9:mode=log:aa=1:mix=0.35,equalizer=f=1900:t=q:w=1.3:g=6,aecho=0.7:0.5:9:0.3,volume=1.6')
TRIM = ('silenceremove=start_periods=1:start_threshold=-50dB,areverse,'
        'silenceremove=start_periods=1:start_threshold=-50dB,areverse')
MONO = 'aresample=44100,aformat=sample_fmts=fltp:channel_layouts=mono'
OGG = ['-ac', '1', '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '3']


def is_police(line_id):
    return line_id == 'defense_police' or line_id.startswith('police_')


def load(lang):
    lua = LuaRuntime()
    lua.execute('bgNPC = { cfg = { replics = {} } }')
    lua.execute((SRC / f'sh_{lang}.lua').read_text(encoding='utf8'))
    tables = lua.eval('bgNPC.cfg.replics')
    return {k: [t[i] for i in range(1, len(t) + 1)] for k, t in tables.items()}


def conversations():
    """{'conv_<id>': [role of each phrase], [is that role police]} from config/states/sh_conversations.lua"""
    lua = LuaRuntime()
    lua.execute('bgNPC = { cfg = {} }')
    lua.execute(CONVERSATIONS.read_text(encoding='utf8'))
    out = {}
    for script in lua.eval('bgNPC.cfg.conversations').values():
        roles = [list(r.values()) if not isinstance(r, str) else [r] for r in script.roles.values()]
        out['conv_' + script.id] = ([line[1] for line in script.lines.values()], ['police' in r for r in roles])
    return out


def takes(line_id, i, conv):
    """[(file suffix, speaker, police)]: a conversation keeps one voice per participant (role), other lines
    rotate the speakers by index"""
    if line_id in conv:
        roles, police = conv[line_id]
        role = roles[i - 1]
        if police[role - 1]:
            return [('', POLICE[(role - 1) % len(POLICE)], True)]
        return [('', MALE[(role - 1) % len(MALE)], False), ('_f', FEMALE[(role - 1) % len(FEMALE)], False)]
    if is_police(line_id):
        return [('', POLICE[i % len(POLICE)], True)]
    return [('', MALE[i % len(MALE)], False), ('_f', FEMALE[i % len(FEMALE)], False)]


def jobs():
    """{relative clip path: (text, xtts lang, speaker, police)}"""
    out, conv, counts = {}, conversations(), {}
    for lang, code in LANGS.items():
        for line_id, lines in load(lang).items():
            counts.setdefault(line_id, set()).add(len(lines))
            for i, text in enumerate(lines, 1):
                for suffix, speaker, police in takes(line_id, i, conv):
                    out[f'{lang}/{line_id}/{i}{suffix}.ogg'] = (text, code, speaker, police)
    # a clip is played by index: the voice-only and conversation lines must match across languages
    odd = [k for k, n in counts.items() if len(n) > 1 and (k in conv or k.startswith(('police_', 'gangster_', 'stare_', 'brawl_')))]
    assert not odd, f'phrase counts differ between languages: {odd}'
    return out


def finish(raw, police, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    if police:
        # click-in, the voice, a burst of static: three branches joined
        graph = (f'[0]{TRIM},{RADIO},{MONO}[v];'
                 f'[1]volume=0.2,afade=t=out:st=0.025:d=0.02,{MONO}[a];'
                 f'[2]highpass=f=900,lowpass=f=4200,afade=t=in:d=0.01,afade=t=out:st=0.05:d=0.17,{MONO}[b];'
                 '[a][v][b]concat=n=3:v=0:a=1,loudnorm=I=-16:TP=-1.5:LRA=11[o]')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(raw),
                        '-f', 'lavfi', '-i', 'sine=f=1250:d=0.05:sample_rate=44100',
                        '-f', 'lavfi', '-i', 'anoisesrc=d=0.22:c=pink:a=0.4:r=44100',
                        '-filter_complex', graph, '-map', '[o]', *OGG, str(dest)], check=True)
        return
    mid, rv = raw.with_suffix('.mid.wav'), raw.with_suffix('.rv.wav')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(raw), '-af', TRIM, '-ac', '1', '-ar', '48000',
                    '-c:a', 'pcm_f32le', str(mid)], check=True)
    v.revive(mid, rv)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(rv), '-af', 'loudnorm=I=-18:TP=-2:LRA=11',
                    *OGG, str(dest)], check=True)
    mid.unlink()
    rv.unlink()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--force', action='store_true')
    ap.add_argument('--only', help='voice only this line id')
    args = ap.parse_args()

    state = json.loads(STATE.read_text(encoding='utf8')) if STATE.exists() else {}
    wanted = jobs()
    sig = {path: f'{text}|{speaker}|{RADIO if police else "revive"}' for path, (text, _, speaker, police) in wanted.items()}

    todo = [p for p in wanted if (args.force or state.get(p) != sig[p] or not (OUT / p).exists())
            and (not args.only or p.split('/')[1] == args.only)]
    print(f'{len(wanted)} clips, {len(todo)} to voice', flush=True)

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        batch = [(tmp / f'{n}.wav', wanted[p][0], wanted[p][1], (wanted[p][2],), OUT / p) for n, p in enumerate(todo)]
        if batch:
            v.synth_xtts(batch, tmp)
        for n, (raw, _, _, _, dest) in enumerate(batch):
            p = todo[n]
            finish(raw, wanted[p][3], dest)
            state[p] = sig[p]

    for p in list(state):
        if p not in wanted:
            (OUT / p).unlink(missing_ok=True)
            del state[p]
    STATE.write_text(json.dumps(state, ensure_ascii=False, indent=1, sort_keys=True), encoding='utf8')

    size = sum(f.stat().st_size for f in OUT.rglob('*.ogg'))
    print(f'done: {len(todo)} voiced, {len(wanted)} clips, {size / 1048576:.1f} MB', flush=True)


if __name__ == '__main__':
    main()
