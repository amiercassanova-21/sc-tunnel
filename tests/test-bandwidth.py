#!/usr/bin/env python3
import importlib.util
from pathlib import Path

path = Path(__file__).resolve().parents[1] / 'modules' / 'cassanova-bandwidth.py'
spec = importlib.util.spec_from_file_location('cassanova_bandwidth', path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

sample = '''stat: {\n name: "user>>>alice>>>traffic>>>uplink"\n value: 1024\n}\nstat: {\n name: "user>>>alice>>>traffic>>>downlink"\n value: 2048\n}\n'''
assert mod.parse_stats(sample) == 3072
assert mod.parse_stats('') == 0
print('Bandwidth parser unit tests passed.')
