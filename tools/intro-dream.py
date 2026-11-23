"""Make the dream of the intro: src/intro/dream.bin (make intro-art), loaded at $c000, and src/intro/dream_text.asm.

  $c000  the screen (empty)          $c400  sprites: figures of the clock, Pixel
  $c7c0  the age of every star       $c800  characters: 1-64 = one pixel each, then the letters, two per letter
  $cc00  the stars: x, y, speed (8.8 numbers), then the speed and place they start again with, 64 bytes per table
A star's x counts in steps of two pixels (0-159), so that it fits in a byte; the fraction gives the odd pixel.
"""
import importlib.util
import math
import random
import numpy as np
from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location('room', 'tools/intro-room.py')
room = importlib.util.module_from_spec(spec)
spec.loader.exec_module(room)
FONT = dict(room.FONT)
FONT.update({
    '2': '.xxxx. x....x .....x .....x ....x. ...x.. ..x... .x.... x..... xxxxxx',
    '3': '.xxxx. x....x .....x .....x ..xxx. .....x .....x .....x x....x .xxxx.',
    '0': '.xxxx. x....x x....x x....x x....x x....x x....x x....x x....x .xxxx.',
    ':': '...... ...... ...... ..xx.. ..xx.. ...... ...... ..xx.. ..xx.. ......',
    'T': 'xxxxxx ..xx.. ..xx.. ..xx.. ..xx.. ..xx.. ..xx.. ..xx.. ..xx.. ..xx..',
    'c': '...... ...... ...... .xxxx. x....x x..... x..... x..... x....x .xxxx.',
    'm': '...... ...... ...... xxxxx. x.xx.x x.xx.x x.xx.x x.xx.x x.xx.x x.xx.x',
    'u': '...... ...... ...... x....x x....x x....x x....x x....x x....x .xxxxx',
    'g': '...... ...... ...... .xxxxx x....x x....x x....x x....x .xxxxx .....x .....x .xxxx.',
})
LINES = [('text_a', 21, 'It is 23:00.'), ('text_b', 23, 'The computer is still on.'), ('text_c', 22, 'Hold on until morning.')]
letters = sorted(set(''.join(t for _, _, t in LINES)) - {' '})
code = {ch: 65 + 2 * i for i, ch in enumerate(letters)}
code[' '] = 0

mem = bytearray(0x1000)
for y in range(8):                          # characters 1-64: one pixel
    for x in range(8):
        mem[0x800 + (1 + y * 8 + x) * 8 + y] = 0x80 >> x
for ch in letters:
    g = np.zeros((16, 8), bool)
    for y, line in enumerate(FONT[ch].split()):
        for x, p in enumerate(line):
            g[2 + y, 1 + x] = p == 'x'
    mem[0x800 + code[ch] * 8:0x800 + code[ch] * 8 + 16] = np.packbits(g, axis=1).tobytes()
assert 0x800 + (65 + 2 * len(letters)) * 8 <= 0xc00


def sprite(n, draw):
    im = Image.new('1', (24, 21))
    draw(ImageDraw.Draw(im))
    mem[0x400 + n * 64:0x400 + n * 64 + 63] = np.packbits(np.array(im), axis=1).tobytes()


SEGMENTS = {'a': (5, 0, 18, 2), 'b': (18, 2, 20, 9), 'c': (18, 11, 20, 18), 'd': (5, 18, 18, 20),
            'e': (3, 11, 5, 18), 'f': (3, 2, 5, 9), 'g': (5, 9, 18, 11)}
for n, parts in enumerate(('abcdef', 'abged', 'abgcd', 'afgcd', 'abcdfg')):     # 0 2 3 5 9
    sprite(n, lambda d: [d.rectangle(SEGMENTS[p], fill=1) for p in parts])
sprite(5, lambda d: (d.rectangle((10, 5, 12, 7), fill=1), d.rectangle((10, 13, 12, 15), fill=1)))
# Pixel: a block of warm light, 14 x 14. Sprites 6-8: the eye closed, half open, open. 9: the block. 10, 11: the glow
sprite(6, lambda d: d.line((9, 11, 14, 11), fill=1))
sprite(7, lambda d: d.rectangle((9, 10, 14, 11), fill=1))
sprite(8, lambda d: (d.rectangle((10, 7, 13, 12), fill=1), d.rectangle((9, 8, 14, 11), fill=1), d.rectangle((10, 8, 11, 9), fill=0)))


def block(d):
    d.rectangle((5, 3, 18, 16), fill=1)
    for p in ((5, 3), (18, 3), (5, 16), (18, 16)):
        d.point(p, fill=0)


sprite(9, block)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def halo(radius, power):
    def draw(d):
        for y in range(21):
            for x in range(24):
                v = max(0, 1 - math.hypot(x - 11.5, y - 9.5) / radius) ** power
                if v * 16 > BAYER[y % 4][x % 4] + .5:
                    d.point((x, y), fill=1)
    return draw


sprite(10, halo(15, .8))
sprite(11, halo(11, 1.2))

rnd = random.Random(23)
N = 48
CENTER = (80 * 256, 87 * 256)
tables = [[0] * 64 for _ in range(16)]


def half_up(v):                             # the same sum as the program does: an eighth is added
    return v + (v >> 3)


for i in range(N):
    angle = rnd.random() * 2 * math.pi
    speed = rnd.uniform(30, 70)
    v0 = [round(math.cos(angle) * speed * .8), round(math.sin(angle) * speed)]
    v0 = [v if abs(v) >= 9 else (9 if v >= 0 else -9) for v in v0]
    p0 = [CENTER[k] + v0[k] * rnd.randint(16, 60) for k in (0, 1)]
    p, v, age = list(p0), list(v0), 0
    for step in range(rnd.randint(0, 260)):
        p = [p[0] + v[0], p[1] + v[1]]
        if step % 8 == 0:
            v, age = [half_up(v[0]), half_up(v[1])], min(age + 1, 31)
        if not (0 <= p[0] < 160 * 256 and 24 * 256 <= p[1] < 168 * 256):
            p, v, age = list(p0), list(v0), 0
    for t, value in enumerate((p[0], p[1], v[0], v[1], v0[0], v0[1], p0[0], p0[1])):
        tables[t * 2][i] = value & 255
        tables[t * 2 + 1][i] = value >> 8 & 255
    mem[0x7c0 + i] = age
for t, values in enumerate(tables):
    mem[0xc00 + t * 64:0xc00 + t * 64 + 64] = bytes(values)
open('src/intro/dream.bin', 'wb').write(mem)

with open('src/intro/dream_text.asm', 'w') as f:
    f.write('; made by tools/intro-dream.py: the sentences of the dream as character codes (the lower half of a letter is +1)\n')
    for name, row, text in LINES:
        f.write(f'{name.upper()}_POS = {row} * 40 + {(40 - len(text)) // 2}\n{name.upper()}_LEN = {len(text)}\n')
        f.write(f'{name} !byte ' + ', '.join(str(code[c]) for c in text) + '\n')
