#!/usr/bin/env python3
"""Run the orbit smoke suite with an existing, isolated Factorio mod set."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

parser=argparse.ArgumentParser()
parser.add_argument('factorio',type=Path)
parser.add_argument('--data',type=Path,required=True)
parser.add_argument('--mods',type=Path,required=True)
parser.add_argument('--launches',action='store_true')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='helmod-compat-') as temporary:
    work=Path(temporary)
    mods=work/'mods'
    mods.mkdir()
    for source in args.mods.resolve().iterdir():
        if source.name in ('mod-list.json','mod-settings.dat'): shutil.copy(source,mods/source.name)
        elif source.suffix=='.zip': (mods/source.name).symlink_to(source)
    mod=mods/'helmod'
    shutil.copytree(root/'src',mod)
    shutil.copy(root/'test'/'test_orbit_compatibility.lua',mod/'test_orbit_compatibility.lua')
    with (mod/'control.lua').open('a') as control: control.write('\nrequire "test_orbit_compatibility"\n')
    if args.launches:
        shutil.copy(root/'test'/'test_orbit_compatibility_launches.lua',mod/'test_orbit_compatibility_launches.lua')
        with (mod/'control.lua').open('a') as control: control.write('\nrequire "test_orbit_compatibility_launches"\n')
    config=work/'config.ini'
    config.write_text(f'[path]\nread-data={args.data.resolve()}\nwrite-data={work/"write"}\n')
    result=subprocess.run([str(args.factorio.resolve()),'--config',str(config),'--mod-directory',str(mods),'--create',str(work/'test.zip')],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    print(result.stdout)
    if result.returncode or 'ORBIT COMPATIBILITY PASSED' not in result.stdout: raise SystemExit(result.returncode or 1)
    if args.launches:
        result=subprocess.run([str(args.factorio.resolve()),'--config',str(config),'--mod-directory',str(mods),'--benchmark',str(work/'test.zip'),'--benchmark-ticks','16000'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        print(result.stdout)
        if result.returncode or 'COMPAT LAUNCH PASS' not in result.stdout: raise SystemExit(result.returncode or 1)
