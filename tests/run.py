from pathlib import Path
import os
from lupa.lua54 import LuaRuntime

root=Path(__file__).resolve().parents[1]
os.chdir(root)
for file in [*root.glob('*.lua'),*root.glob('client/*.lua'),*root.glob('server/*.lua')]:
    LuaRuntime().execute('assert(load(...))',file.read_text(encoding='utf-8'))
print('PASS: all resource Lua files parse')
for file in sorted((root/'tests').glob('*_spec.lua')):
    LuaRuntime().execute(file.read_text(encoding='utf-8'))
