#!/usr/bin/env python3
"""Run Helmod's orbit integration checks in an isolated Factorio user directory."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import json

parser = argparse.ArgumentParser()
parser.add_argument('factorio', type=Path)
parser.add_argument('--data', type=Path, required=True)
mode = parser.add_mutually_exclusive_group()
mode.add_argument('--ui', action='store_true')
mode.add_argument('--base-only', action='store_true')
mode.add_argument('--timing', action='store_true')
parser.add_argument('--output', type=Path, default=Path('/tmp/helmod-orbit-screenshots'))
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='helmod-orbit-') as temporary:
    work = Path(temporary)
    mod = work / 'mods' / 'helmod'
    shutil.copytree(root / 'src', mod)
    if not args.ui and not args.base_only:
        fixture = 'orbit-timing-prototypes' if args.timing else 'orbit-prototypes'
        shutil.copy(root / 'test' / f'{fixture}.lua', mod / f'{fixture}.lua')
        capture = mod / 'data-final-fixes.lua'
        capture.write_text(f'require "{fixture}"\n' + capture.read_text())
    suite = 'test_orbit_ui' if args.ui else ('test_orbit_base' if args.base_only else ('test_orbit_timing' if args.timing else 'test_orbit'))
    shutil.copy(root / 'test' / f'{suite}.lua', mod / f'{suite}.lua')
    with (mod / 'control.lua').open('a') as control:
        control.write(f'\nrequire "{suite}"\n')
    mods = ['base', 'helmod'] if args.base_only else ['base', 'quality', 'elevated-rails', 'space-age', 'helmod']
    (work / 'mods' / 'mod-list.json').write_text(json.dumps({'mods': [
        {'name': name, 'enabled': name in mods} for name in ['base', 'quality', 'elevated-rails', 'space-age', 'helmod']]}))
    config = work / 'config.ini'
    config.write_text(f'[path]\nread-data={args.data.resolve()}\nwrite-data={work / "write"}\n')
    result = subprocess.run([str(args.factorio.resolve()), '--config', str(config),
        '--mod-directory', str(work / 'mods'), '--create', str(work / 'test.zip')],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout)
    if args.timing and result.returncode == 0:
        result = subprocess.run([str(args.factorio.resolve()), '--config', str(config),
            '--mod-directory', str(work / 'mods'), '--benchmark', str(work / 'test.zip'),
            '--benchmark-ticks', '40000'], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        print(result.stdout)
        if result.returncode or result.stdout.count('TIMING PASS ') != 18:
            raise SystemExit(result.returncode or 1)
    elif args.ui and result.returncode == 0:
        import os
        env = dict(os.environ, SteamAppId='427520')
        try:
            result = subprocess.run([str(args.factorio.resolve()), '--config', str(config),
                '--mod-directory', str(work / 'mods'), '--load-game', str(work / 'test.zip'),
                '--disable-audio', '--window-size', '1600x1000'], env=env, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
        except subprocess.TimeoutExpired as timeout:
            result = subprocess.CompletedProcess([], 0, timeout.stdout.decode() if isinstance(timeout.stdout, bytes) else timeout.stdout)
        print(result.stdout)
        args.output.mkdir(parents=True, exist_ok=True)
        for screenshot in (work / 'write' / 'script-output').glob('orbit-*.png'):
            shutil.copy(screenshot, args.output / screenshot.name)
        if 'ORBIT UI SMOKE PASSED' not in result.stdout:
            raise SystemExit(1)
    elif result.returncode or 'ORBIT TESTS PASSED' not in result.stdout:
        raise SystemExit(result.returncode or 1)
