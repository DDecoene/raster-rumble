"""Make the title, a film poster: src/intro/title.bin (make intro-art), loaded at $9000. It is packed; the program unpacks
it to $d000, under the I/O chips and the KERNAL, where the VIC can see it:
  $d000 the colours    $d400 the colours when the light of the window flickers    $e000 the hires bitmap
Packed: 1-127 = that many bytes follow; 128-255 = copy (n - 125) bytes from a distance (2 bytes) back; 0 = the end.
"""
import importlib.util
import random
import subprocess
import numpy as np
from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location('dream', 'tools/intro-dream.py')
dream = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dream)
FONT = dict(dream.FONT)
FONT.update({
    'F': 'xxxxxx x..... x..... x..... xxxxx. x..... x..... x..... x..... x.....',
    'A': '.xxxx. x....x x....x x....x xxxxxx x....x x....x x....x x....x x....x',
    'D': 'xxxxx. x....x x....x x....x x....x x....x x....x x....x x....x xxxxx.',
    'C': '.xxxx. x....x x..... x..... x..... x..... x..... x..... x....x .xxxx.',
    'M': 'x....x xx..xx x.xx.x x.xx.x x....x x....x x....x x....x x....x x....x',
    'W': 'x....x x....x x....x x....x x....x x.xx.x x.xx.x x.xx.x xx..xx x....x',
    'S': '.xxxx. x....x x..... x..... .xxxx. .....x .....x .....x x....x .xxxx.',
    'a': '...... ...... ...... .xxxx. .....x .xxxxx x....x x....x x....x .xxxxx',
    'b': 'x..... x..... x..... xxxxx. x....x x....x x....x x....x x....x xxxxx.',
    '1': '..x... .xx... ..x... ..x... ..x... ..x... ..x... ..x... ..x... .xxx..',
    '4': '....x. ...xx. ..x.x. .x..x. x...x. xxxxxx ....x. ....x. ....x. ....x.',
    '5': 'xxxxxx x..... x..... xxxxx. .....x .....x .....x .....x x....x .xxxx.',
    '6': '.xxxx. x....x x..... x..... xxxxx. x....x x....x x....x x....x .xxxx.',
    '7': 'xxxxxx .....x .....x ....x. ....x. ...x.. ...x.. ..x... ..x... ..x...',
    '8': '.xxxx. x....x x....x x....x .xxxx. x....x x....x x....x x....x .xxxx.',
    '9': '.xxxx. x....x x....x x....x .xxxxx .....x .....x .....x x....x .xxxx.',
})
room = dream.room
version = subprocess.run(['tools/version.sh'], capture_output=True, text=True, check=True).stdout.strip()
rect, poly, oval, mask, xx, yy = room.rect, room.poly, room.oval, room.mask, room.xx, room.yy

# ------------------------------------------------------------------ the picture, brightness 0 to 4 as in intro-room.py
P = np.zeros((200, 320))
sky = np.clip((yy - 76) / 46, 0, 1)
P[:] = sky
MX, MY = 58, 103                            # the moon
r = np.hypot(xx - MX, yy - MY)
P = np.minimum(P + 0.9 * np.exp(-(r / 24) ** 2), 1)
P[r < 13] = 3.7 - np.hypot(xx - MX + 4, yy - MY + 4)[r < 13] / 16
for x, y, n in ((53, 99, 3), (63, 107, 4), (57, 110, 2), (64, 98, 2)):
    P[np.hypot(xx - x, yy - y) < n] -= .7
rnd = random.Random(5)
for n in range(60):                         # stars
    x, y = rnd.randint(0, 319), rnd.randint(0, 112)
    if P[y, x] < .3:
        P[y, x] = rnd.choice((1, 2, 2, 3))
far = yy > 139 + 5 * np.sin(xx / 31) + 3 * np.sin(xx / 13 + 1)          # hills far away
P[far] = .4
for x in range(8, 200, 48):                 # a row of poles along the road, with their wires
    P[rect(x, 126 + (x // 48), x + 1, 148)] = 0
    P[rect(x - 4, 128 + (x // 48), x + 5, 128 + (x // 48))] = 0
near = yy > 150 - 20 * np.exp(-((xx - 226) / 70) ** 2) + 2 * np.sin(xx / 9)   # the hill of the house
P[near] = 0

# the house: gable, chimney, porch
house = (poly((186, 140), (186, 106), (180, 108), (216, 76), (252, 108), (246, 106), (246, 140))
         | rect(234, 78, 242, 100) | poly((246, 140), (246, 116), (274, 124), (274, 140)))
P[house] = 0
edge = house & ~(np.roll(house, 1, 1) & np.roll(house, 1, 0))
P[edge & (yy < 136)] = 2
P[rect(233, 76, 243, 78)] = 0
P[rect(233, 76, 243, 76)] = 1.9
WX, WY = 216, 101                           # the window of the attic, and its light on the wall
glow = 1.5 * np.exp(-(np.hypot(xx - WX, yy - WY) / 16) ** 2)
inside = house & ~edge
P[inside] = np.minimum(glow, 1)[inside]
P[rect(204, 91, 228, 112)] = 0
win = rect(206, 93, 226, 110)
P[win] = (4 - np.hypot(xx - WX, yy - WY) / 8)[win]
P[rect(215, 93, 216, 110)] = 0
P[rect(206, 101, 226, 101)] = 0
small = oval(213, 101, 220, 108) | rect(211, 107, 222, 110)             # somebody sits there
P[small] = 0
P[rect(202, 112, 230, 113)] = 1.6
P[rect(196, 120, 206, 130)] = 0
P[rect(226, 120, 236, 130)] = 0
P[rect(212, 121, 221, 139)] = 0
# its light falls on the grass
cone = near & poly((150, 152), (196, 138), (236, 138), (262, 152))
P[cone] = (1.5 * np.exp(-np.abs(xx - 212) / 34) * np.clip((153 - yy) / 12, 0, 1))[cone]
# a bare tree in front on the left, a fence on the right
trunk = poly((104, 156), (110, 128), (108, 112), (113, 112), (115, 128), (120, 156))


def branch(d, x, y, angle, length, width):
    if length < 4:
        return
    x2, y2 = x + length * np.cos(angle), y - length * np.sin(angle)
    d.line((x, y, x2, y2), fill=1, width=width)
    branch(d, x2, y2, angle + .5, length * .72, max(1, width - 1))
    branch(d, x2, y2, angle - .42, length * .7, max(1, width - 1))


tree = trunk | mask(lambda d: branch(d, 111, 120, 1.6, 15, 4))
P[tree] = 0
for x in range(268, 320, 9):
    P[rect(x, 138, x + 2, 152)] = 0
P[rect(264, 142, 319, 143)] = 0
P[152:] = 0
P = np.clip(P, 0, 4)
P[:78] = np.where(P[:78] >= 1, P[:78], 0)
P[16:40, 32:288] = P[48:72, 32:288] = 0     # room for the letters
picture = Image.new('1', (320, 200))

# ------------------------------------------------------------------ the letters: 32 x 24, drawn 32 x 40 and pressed
BARS = {
    'R': [((0, 0), (31, 8)), ((0, 0), (8, 39)), ((23, 0), (31, 22)), ((0, 16), (31, 24))],
    'A': [((0, 0), (31, 8)), ((0, 0), (8, 39)), ((23, 0), (31, 39)), ((0, 18), (31, 26))],
    'S': [((0, 0), (31, 8)), ((0, 0), (8, 22)), ((0, 16), (31, 24)), ((23, 16), (31, 39)), ((0, 31), (31, 39))],
    'T': [((0, 0), (31, 8)), ((12, 0), (20, 39))],
    'E': [((0, 0), (31, 8)), ((0, 0), (8, 39)), ((0, 16), (25, 24)), ((0, 31), (31, 39))],
    'U': [((0, 0), (8, 39)), ((23, 0), (31, 39)), ((0, 31), (31, 39))],
    'M': [((0, 0), (8, 39)), ((23, 0), (31, 39))],
    'B': [((0, 0), (31, 8)), ((0, 0), (8, 39)), ((23, 0), (31, 39)), ((0, 16), (31, 24)), ((0, 31), (31, 39))],
    'L': [((0, 0), (8, 39)), ((0, 31), (31, 39))],
}
EXTRA = {'R': [(10, 24), (21, 24), (31, 39), (20, 39)], 'M': [(0, 0), (9, 0), (16, 12), (22, 0), (31, 0), (16, 27)]}
CUT = {'R': [(31, 0, -1, 1), (31, 24, -1, -1)], 'A': [(0, 0, 1, 1), (31, 0, -1, 1)], 'U': [(0, 39, 1, -1), (31, 39, -1, -1)],
       'S': [(0, 0, 1, 1), (31, 39, -1, -1)], 'B': [(31, 0, -1, 1), (31, 39, -1, -1)]}
for word, top in (('RASTER', 16), ('RUMBLE', 48)):
    for i, ch in enumerate(word):
        letter = Image.new('1', (32, 40))
        ld = ImageDraw.Draw(letter)
        for box in BARS[ch]:
            ld.rectangle(box, fill=1)
        if ch in EXTRA:
            ld.polygon(EXTRA[ch], fill=1)
        for x, y, dx, dy in CUT.get(ch, ()):
            ld.polygon([(x, y), (x + 5 * dx, y), (x, y + 8 * dy)], fill=0)
        if ch == 'B':                       # its waist
            ld.polygon([(31, 16), (31, 24), (27, 20)], fill=0)
        picture.paste(letter.resize((32, 24), 0), (40 + i * 40 + 4, top))
letters = np.array(picture)
letters[3::4] = False                       # drawn by a beam: every fourth line is dark

bits, pairs = room.fit(P, clock=False)
A = np.array([[room.RAMP[b] << 4 | room.RAMP[a] for a, b in row] for row in pairs.tolist()])
flicker = A.copy()
places = [(r, c) for r in (11, 12, 13) for c in range(25, 29)] + [(r, c) for r in (17, 18) for c in range(19, 33)]
for row, col in places:                     # the window, and its light on the grass
    a, b = pairs[row, col]
    flicker[row, col] = room.RAMP[max(0, b - 1)] << 4 | room.RAMP[max(0, a - 1)]


def both(row, cols, value):
    A[row, cols] = flicker[row, cols] = value


for top in (2, 6):
    for n, colour in enumerate((1, 3, 14)):
        bits[(top + n) * 8:(top + n) * 8 + 8, 32:288] = letters[(top + n) * 8:(top + n) * 8 + 8, 32:288]
        both(top + n, slice(4, 36), colour << 4)


def write(text, row, colour, col=None):
    col = (40 - len(text)) // 2 if col is None else col
    bits[row * 8:row * 8 + 16, col * 8:(col + len(text)) * 8] = False
    for i, ch in enumerate(text):
        for y, line in enumerate(FONT[ch].split() if ch != ' ' else ()):
            for x, p in enumerate(line):
                bits[row * 8 + 2 + y, (col + i) * 8 + 1 + x] = p == 'x'
    for n in (0, 1):
        both(row + n, slice(col, col + len(text)), colour << 4)


write('Fire to begin', 19, 0)
write('A game by Dennis Decoene', 21, 14)
write('Music made with WebSidTracker', 23, 11)
write('v' + version, 0, 11, 39 - len(version))

mem = bytearray(0x2f40)
mem[0x000:0x3e8] = bytes(A.flatten().tolist())
mem[0x400:0x7e8] = bytes(flicker.flatten().tolist())
for base in (0x3f8, 0x7f8):
    mem[base:base + 8] = bytes([28] * 8)    # the sprites of the beam
mem[0x1000:0x2f40] = room.cells(bits)


def pack(data):
    out, lit, i, seen = bytearray(), bytearray(), 0, {}

    def flush():
        while lit:
            part = lit[:127]
            del lit[:127]
            out.append(len(part))
            out.extend(part)

    def note(at):
        seen.setdefault(bytes(data[at:at + 3]), []).append(at)

    while i < len(data):
        best, where = 0, 0
        for j in reversed(seen.get(bytes(data[i:i + 3]), [])[-600:]):
            n = 0
            while n < 130 and i + n < len(data) and data[j + n] == data[i + n]:
                n += 1
            if n > best:
                best, where = n, j
        if best >= 4:
            flush()
            out.append(best + 125)
            out.extend((i - where).to_bytes(2, 'little'))
        else:
            best = 1
            lit.append(data[i])
        for k in range(i, i + best):
            note(k)
        i += best
    flush()
    out.append(0)
    return bytes(out)


packed = pack(mem)
open('src/intro/title.bin', 'wb').write(packed)
print('title:', len(packed), 'bytes')
assert len(packed) <= 0x1000
