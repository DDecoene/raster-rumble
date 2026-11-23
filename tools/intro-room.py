"""Draw the room of the intro and write it as C64 data: src/intro/room.bin (make intro-art).

room.bin is loaded at $4000:
  $4000  seven colour screens of 1 KB: 0 = dark ... 5 = full light, 6 = full light with a flicker
  $5c00  sprites (the head of the boy: black shape, rim of light), then empty
  $6000  the hires bitmap
One pixel holds a brightness from 0 to 4: a place on the ramp black, blue, light blue, cyan, white.
"""
import sys
import numpy as np
from PIL import Image, ImageDraw

RAMP = [0, 6, 14, 3, 1]
W, H = 320, 200
TOP, BOTTOM = 24, 168                       # the film bars are above and below these lines
yy, xx = np.mgrid[0:H, 0:W].astype(float)
CX, CY = 168, 88                            # the middle of the light


def mask(draw_fn):
    im = Image.new('1', (W, H))
    draw_fn(ImageDraw.Draw(im))
    return np.array(im)


def rect(x0, y0, x1, y1):
    return mask(lambda d: d.rectangle((x0, y0, x1, y1), fill=1))


def poly(*pts):
    return mask(lambda d: d.polygon(pts, fill=1))


def oval(x0, y0, x1, y1):
    return mask(lambda d: d.ellipse((x0, y0, x1, y1), fill=1))


dist = np.hypot((xx - CX) / 1.25, yy - CY)
glow = 2.5 * np.exp(-(dist / 62) ** 1.5)    # the light of the monitor on the wall
L = glow.copy()

# window: night sky, a frame, curtains
L[rect(22, 36, 86, 102)] = 0
sky = rect(26, 40, 82, 98)
L[sky] = (0.9 * np.clip((yy - 70) / 26, 0, 1))[sky]
for x, y, v in ((31, 45, 3), (44, 43, 2), (49, 58, 4), (36, 62, 2), (29, 56, 2), (60, 62, 2), (78, 63, 3), (47, 48, 2), (59, 44, 2)):
    L[y, x] = v
L[oval(65, 44, 76, 55) & ~oval(61, 42, 72, 53)] = 4     # the moon
hills = poly((26, 98), (26, 90), (38, 85), (52, 92), (66, 87), (82, 93), (82, 98))
L[hills] = 0
L[rect(53, 40, 55, 98)] = 1
L[rect(26, 66, 82, 68)] = 1
for pts in (((16, 32), (34, 32), (29, 66), (24, 110), (16, 110)), ((74, 32), (92, 32), (92, 110), (84, 110), (79, 66))):
    c = poly(*pts)
    L[c] = (0.15 + 0.35 * (((xx + yy / 20) % 6) < 2))[c] * (0.4 + (xx / 110))[c]
L[rect(12, 30, 96, 32)] = 0
L[rect(20, 102, 88, 104)] = 1.1

# shelf with books and a toy rocket
for x, w, h, lit in ((232, 6, 18, 0), (239, 5, 22, 1), (245, 7, 16, 0), (253, 4, 20, 0), (258, 8, 14, 1)):
    L[rect(x, 59 - h, x + w - 1, 58)] = 0
    L[rect(x, 59 - h, x, 58)] = 1.2 if lit else .6
L[poly((282, 58), (285, 45), (289, 36), (293, 45), (296, 58))] = 0
L[rect(286, 44, 286, 56)] = .9
L[rect(226, 59, 304, 62)] = 0
L[rect(226, 59, 304, 59)] = 1.2

# floor: a pool of light, with the shadow of the boy in it
floor = yy > 140
pool = 1.35 * np.exp(-(((xx - CX) / 95) ** 2 + ((yy - 138) / 34) ** 2))
L[floor] = pool[floor]
L[rect(0, 138, 319, 140)] = 0

# desk
L[poly((96, 118), (242, 118), (250, 125), (88, 125))] = 0
top = poly((96, 118), (242, 118), (250, 124), (88, 124))
L[top] = (3.3 * np.exp(-np.abs(xx - CX) / 42))[top]
L[rect(88, 125, 250, 128)] = 0
L[rect(92, 129, 97, 157)] = 0
L[rect(241, 129, 246, 157)] = 0
L[rect(210, 129, 240, 150)] = 0             # drawers
L[rect(98, 129, 209, 139)] = 0.0

# monitor
L[mask(lambda d: d.rounded_rectangle((125, 56, 211, 118), 4, fill=1))] = 0
tube = mask(lambda d: d.rounded_rectangle((131, 61, 205, 111), 6, fill=1))
L[tube] = (4.1 - 1.5 * (np.hypot((xx - CX) / 38, (yy - 86) / 26) ** 2))[tube]
L[tube & (yy % 4 == 0)] -= 0.5
L[rect(126, 55, 210, 55)] = 2

# magazine on a stand, and a joystick
L[poly((99, 119), (103, 99), (122, 102), (121, 119))] = 0
page = poly((101, 117), (105, 101), (120, 104), (119, 117))
L[page] = (1.4 + (xx - 101) / 14)[page]
for y in range(105, 117, 2):
    L[y, 107:118 - (y * 7 % 5)] = 0.5
L[rect(222, 115, 234, 119)] = 0
L[rect(227, 104, 229, 115)] = 0
L[oval(225, 101, 231, 106)] = 0
L[rect(226, 103, 226, 113)] = 1.6

# bed in front on the right, bedside table with the clock
L[rect(262, 116, 296, 140)] = 0
L[rect(262, 116, 296, 116)] = 1
L[rect(266, 104, 290, 115)] = 0
bed = poly((226, 168), (230, 150), (242, 143), (262, 139), (276, 134), (290, 131), (306, 129), (320, 129), (320, 168))
L[bed] = 0
edge = bed & ~np.roll(bed, 1, axis=0)
L[edge] = 1.6 - (xx[edge] - 226) / 120
L[np.roll(edge, 1, axis=0)] = .8

# chair and boy, from the back
boy = (oval(141, 125, 195, 175) | rect(141, 148, 195, 168) | rect(161, 118, 175, 130)
       | poly((144, 136), (132, 146), (133, 152), (146, 154)) | poly((192, 136), (204, 146), (203, 152), (190, 154)))
rim = boy & ~(np.roll(boy, 1, 0) & np.roll(boy, 1, 1) & np.roll(boy, -1, 1))
L[boy] = 0
L[rim & (yy > 122) & (yy < 147)] = 3
chair = mask(lambda d: d.rounded_rectangle((146, 143, 190, 163), 4, fill=1))
L[chair] = 0
L[chair & ~np.roll(chair, 1, 0)] = 1.3
shadow = poly((146, 160), (190, 160), (206, 168), (130, 168))
L[shadow] = 0

L[:TOP] = 0
L[BOTTOM:] = 0
L = np.clip(L, 0, 4)

# the text: 8 x 16 pixels per letter, drawn here and made visible by the program, letter by letter
FONT = {
    'H': 'x....x x....x x....x x....x xxxxxx x....x x....x x....x x....x x....x',
    'E': 'xxxxxx x..... x..... x..... xxxxx. x..... x..... x..... x..... xxxxxx',
    'e': '...... ...... ...... .xxxx. x....x x....x xxxxxx x..... x....x .xxxx.',
    't': '...... .x.... .x.... xxxxx. .x.... .x.... .x.... .x.... .x..x. ..xx..',
    'y': '...... ...... ...... x....x x....x x....x x....x x....x .xxxxx .....x .....x .xxxx.',
    'p': '...... ...... ...... xxxxx. x....x x....x x....x x....x x....x xxxxx. x..... x.....',
    'd': '.....x .....x .....x .xxxxx x....x x....x x....x x....x x....x .xxxxx',
    'i': '..x... ...... ...... .xx... ..x... ..x... ..x... ..x... ..x... .xxx..',
    'n': '...... ...... ...... xxxxx. x....x x....x x....x x....x x....x x....x',
    'v': '...... ...... ...... x....x x....x x....x .x..x. .x..x. ..xx.. ..xx..',
    'r': '...... ...... ...... x.xxx. xx...x x..... x..... x..... x..... x.....',
    'l': '.xx... ..x... ..x... ..x... ..x... ..x... ..x... ..x... ..x... .xxx..',
    '.': '...... ...... ...... ...... ...... ...... ...... ...... .xx... .xx...',
}
TEXT = 'He typed it in. Every line.'
TEXT_ROW, TEXT_COL = 22, (40 - len(TEXT)) // 2


def build():
    bits = np.zeros((H, W), bool)
    pairs = np.zeros((25, 40, 2), int)
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])
    thr = (np.tile(bayer, (2, 2)) + .5) / 16
    for r in range(25):
        for c in range(40):
            v = L[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
            best = None
            for a in range(5):
                for b in range(a + 1, 5):
                    t = np.clip((v - a) / (b - a), 0, 1)
                    on = t > thr
                    err = ((np.clip(v, a, b) - v) ** 2).sum() * 3 + ((np.where(on, b, a) - v) ** 2).sum()
                    if best is None or err < best[0]:
                        best = err, a, b, on
            _, a, b, on = best
            bits[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = on
            pairs[r, c] = a, b
    for i, ch in enumerate(TEXT):
        for y, line in enumerate(FONT.get(ch, '').split()):
            for x, p in enumerate(line):
                bits[TEXT_ROW * 8 + 2 + y, (TEXT_COL + i) * 8 + 1 + x] = p == 'x'
    # the clock: red figures, 22:41, in cells of their own
    digits = {'2': '110 001 010 100 111', '4': '101 101 111 001 001', '1': '010 110 010 010 111', ':': '0 1 0 1 0'}
    bits[104:112, 264:296] = False
    x = 267
    for ch in '22:41':
        rows = digits[ch].split()
        for y, line in enumerate(rows):
            for i, p in enumerate(line):
                bits[106 + y, x + i] = p == '1'
        x += len(rows[0]) + 1
    clock = {(13, c) for c in (33, 34, 35)}
    screens = bytearray()
    for level in (0, 1, 2, 3, 4, 5, 6):
        scr = bytearray(1024)
        for r in range(25):
            for c in range(40):
                a, b = pairs[r, c]
                tube_cell = 8 <= r <= 13 and 16 <= c <= 25
                if level == 0:
                    a = b = 0
                elif level == 6:
                    if not tube_cell:
                        a, b = (max(1, v - 1) if v else 0 for v in (a, b))
                else:
                    s = max(0, 5 - level - (2 if tube_cell else 0))
                    a, b = max(0, a - s), max(0, b - s)
                value = RAMP[b] << 4 | RAMP[a]
                if (r, c) in clock:
                    value = 0x20 if level else 0
                if r >= 21:
                    value = 0
                scr[r * 40 + c] = value
        scr[0x3f8:0x400] = bytes([112, 113, 114, 115, 116, 116, 116, 116])
        screens += scr
    # head: 24 x 30 pixels over two sprites, the rim of light first (sprites 0, 1: in front), then the black shape
    head = Image.new('1', (24, 42))
    d = ImageDraw.Draw(head)
    d.ellipse((2, 1, 21, 24), fill=1)
    d.rectangle((0, 12, 2, 16), fill=1)     # ears
    d.rectangle((21, 12, 23, 16), fill=1)
    d.rectangle((7, 22, 16, 30), fill=1)    # neck
    for p in ((8, 0), (9, 0), (13, 0), (6, 1), (17, 1)):   # hair
        d.point(p, fill=1)
    h = np.array(head)
    p = np.pad(h, 1)
    rimh = h & ~(p[:-2, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
    rimh[26:] = False
    sprites = bytearray()
    for part in (rimh[:21], rimh[21:], h[:21], h[21:]):
        sprites += np.packbits(part, axis=1).tobytes() + b'\0'
    sprites = sprites.ljust(0x400, b'\0')
    bitmap = bytearray()
    for r in range(25):
        for c in range(40):
            bitmap += np.packbits(bits[r * 8:r * 8 + 8, c * 8:c * 8 + 8], axis=1).tobytes()
    return bytes(screens + sprites + bitmap)


open('src/intro/room.bin', 'wb').write(build())
