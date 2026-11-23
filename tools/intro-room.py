"""Draw the room of the intro and write it as C64 data: src/intro/room.bin (make intro-art).

room.bin is loaded at $4000:
  $4000  seven colour screens of 1 KB: 0 = dark ... 5 = full light, 6 = full light with a flicker
  $5c00  sprites (the head of the boy: black shape, rim of light), then empty
  $6000  the hires bitmap
door.bin is loaded at $8000: the same room with the door open. Three colour screens (the door opens further and
further), the sprites at $8c00, the bitmap at $a000.
bed.bin is loaded at $3800: the cells that change when the boy is in bed. Per cell its number (2 bytes), the bitmap
(8) and the colour in the seven screens (7), and $ffff at the end. The program swaps them with what is there.
text.bin is loaded at $1800, $600 bytes per shot: four rows of bitmap with the sentences (1280 bytes), then the
three cells of the clock (24 bytes).
One pixel holds a brightness from 0 to 4: a place on the ramp black, blue, light blue, cyan, white.
"""
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

# bedside table with the clock
L[rect(262, 116, 296, 140)] = 0
L[rect(262, 116, 296, 116)] = 1
L[rect(266, 104, 290, 115)] = 0
base = L.copy()                             # the room without bed, chair and boy

# bed in front on the right
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

# the same room, later: he is in bed, the chair is empty
LB = base.copy()
LB[rect(148, 119, 190, 121)] = 0            # the keyboard
LB[rect(148, 118, 190, 118)] = 3
chair = mask(lambda d: d.rounded_rectangle((148, 134, 188, 156), 4, fill=1)) | rect(164, 150, 172, 168)
LB[chair] = 0
LB[chair & ~np.roll(chair, 1, 0)] = 2
bed2 = bed | poly((234, 150), (246, 139), (258, 131), (270, 127), (284, 127), (292, 133), (300, 137), (300, 150))
pillow = poly((292, 134), (297, 126), (320, 122), (320, 140), (296, 140))
LB[bed2 | pillow] = 0
for shape, light in ((bed2, 1.8), (pillow, 1.3)):
    e = shape & ~np.roll(shape, 1, 0)
    LB[e] = light
    LB[np.roll(e, 1, 0)] = light * .7
head2 = oval(294, 113, 314, 131)
LB[head2] = 0
LB[head2 & ~np.roll(head2, 1, 1) & (yy < 128)] = 2.2

# the door is open: warm light from behind us on the left, with the shadow of a grown-up
LD = L.copy()
patch = rect(0, 24, 95, 167)
LD[patch] = 2
LD[patch & (yy >= 138) & (yy < 141)] = .8
for m, v in ((rect(24, 38, 84, 100), 1.0), (rect(28, 42, 80, 96), 1.4), (rect(53, 42, 55, 96), .9), (rect(28, 66, 80, 68), .9)):
    LD[m] = v
LD[rect(20, 102, 88, 104)] = 1
LD[rect(12, 30, 94, 31)] = .8
for x0, x1 in ((14, 25), (83, 93)):
    c = rect(x0, 32, x1, 110)
    LD[c] = (1 + (xx % 5 < 2))[c]
shade = (oval(36, 33, 58, 60) | rect(42, 56, 52, 68)
         | poly((22, 78), (34, 66), (60, 66), (72, 78), (75, 116), (67, 118), (64, 92), (63, 128), (72, 168), (52, 168),
                (48, 130), (44, 130), (30, 168), (10, 168), (31, 128), (30, 92), (27, 118), (19, 116)))
LD[shade & patch] = 0

for picture in (L, LB, LD):
    picture[:TOP] = 0
    picture[BOTTOM:] = 0
    np.clip(picture, 0, 4, out=picture)

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
    'I': '.xxx.. ..x... ..x... ..x... ..x... ..x... ..x... ..x... ..x... .xxx..',
    's': '...... ...... ...... .xxxx. x....x x..... .xxxx. .....x x....x .xxxx.',
    'o': '...... ...... ...... .xxxx. x....x x....x x....x x....x x....x .xxxx.',
    'w': '...... ...... ...... x....x x....x x....x x.xx.x x.xx.x xx..xx x....x',
    'k': 'x..... x..... x..... x...x. x..x.. x.x... xxx... x..x.. x...x. x....x',
    'h': 'x..... x..... x..... xxxxx. x....x x....x x....x x....x x....x x....x',
    'T': 'xxxxxx ..xx.. ..xx.. ..xx.. ..xx.. ..xx.. ..xx.. ..xx.. ..xx.. ..xx..',
    'a': '...... ...... ...... .xxxx. .....x .xxxxx x....x x....x x....x .xxxxx',
    'm': '...... ...... ...... xxxxx. x.xx.x x.xx.x x.xx.x x.xx.x x.xx.x x.xx.x',
    'B': 'xxxxx. x....x x....x x....x xxxxx. x....x x....x x....x x....x xxxxx.',
    'N': 'x....x xx...x xx...x x.x..x x.x..x x..x.x x..x.x x...xx x...xx x....x',
    '"': '.x..x. .x..x. .x..x. ...... ...... ...... ...... ...... ...... ......',
    '.': '...... ...... ...... ...... ...... ...... ...... ...... .xx... .xx...',
}
# per shot: the time on the clock, then the sentences with their row (21 to 23) in the bar below the picture
SHOTS = [
    ('22:41', [(22, 'He typed it in. Every line.')]),
    ('22:52', [(21, 'It does not work.'), (23, 'He does not know why.')]),
    ('22:52', [(22, '"Bed. Now."')]),
    ('22:58', []),
    ('22:59', []),
]


def cells(bits):
    """8 x 8 cells, the order the VIC wants"""
    out = bytearray()
    for r in range(bits.shape[0] // 8):
        for c in range(bits.shape[1] // 8):
            out += np.packbits(bits[r * 8:r * 8 + 8, c * 8:c * 8 + 8], axis=1).tobytes()
    return out


def texts():
    data = bytearray()
    for clock, lines in SHOTS:
        data += (cells(bar_bits(lines)) + cells(clock_face(clock))).ljust(0x600, b'\0')
    return bytes(data)


def bar_bits(lines):
    """the bar below the picture with its sentences"""
    bar = np.zeros((32, W), bool)
    for row, text in lines:
        col = (40 - len(text)) // 2
        for i, ch in enumerate(text):
            for y, line in enumerate(FONT[ch].split() if ch != ' ' else ()):
                for x, p in enumerate(line):
                    bar[(row - 21) * 8 + 2 + y, (col + i) * 8 + 1 + x] = p == 'x'
    return bar


def clock_face(clock):
    digits = {'2': '110 001 010 100 111', '4': '101 101 111 001 001', '1': '010 110 010 010 111',
              '8': '111 101 111 101 111', '9': '111 101 111 001 110', '3': '111 001 011 001 111', '0': '111 101 101 101 111', '5': '111 100 110 001 110', ':': '0 1 0 1 0'}
    face = np.zeros((8, 24), bool)
    x = 3
    for ch in clock:
        rows = digits[ch].split()
        for y, line in enumerate(rows):
            for i, p in enumerate(line):
                face[2 + y, x + i] = p == '1'
        x += len(rows[0]) + 1
    return face


def fit(picture, clock=True):
    """per cell the two colours that come closest, and the pixels (an ordered dither between the two)"""
    bits = np.zeros((H, W), bool)
    pairs = np.zeros((25, 40, 2), int)
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])
    thr = (np.tile(bayer, (2, 2)) + .5) / 16
    for r in range(25):
        for c in range(40):
            v = picture[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
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
    if clock:
        bits[104:112, 264:296] = False      # the clock: the program puts the figures there
    return bits, pairs


def colour(pairs, r, c, level):
    """the colours of one cell at a level of light"""
    a, b = pairs[r, c]
    tube_cell = 8 <= r <= 13 and 16 <= c <= 25
    if level == 0 or r >= 21:
        return 0
    if r == 13 and c in (33, 34, 35):       # the clock: red
        return 0x20
    if level == 6:
        if not tube_cell:
            a, b = (max(1, v - 1) if v else 0 for v in (a, b))
    else:
        s = max(0, 5 - level - (2 if tube_cell else 0))
        a, b = max(0, a - s), max(0, b - s)
    return RAMP[b] << 4 | RAMP[a]


def spark():
    im = np.zeros((21, 24), bool)
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(21):
        for x in range(24):
            r = np.hypot(x - 11.5, y - 10)
            im[y, x] = r < 3.6 or (1 - r / 10) * 13 > bayer[y % 4][x % 4] + .5
    return np.packbits(im, axis=1).tobytes()


def screen(values, first_sprite, spark_sprite=0):
    scr = bytearray(values).ljust(1024, b'\0')
    scr[0x3f8:0x400] = bytes([first_sprite, first_sprite + 1, first_sprite + 2, first_sprite + 3] + [spark_sprite or first_sprite + 4] * 4)
    return scr


PLACES = [(r, c) for r in range(25) for c in range(40)]


def room():
    bits, pairs = fit(L)
    screens = b''.join(screen([colour(pairs, r, c, level) for r, c in PLACES], 112, 127) for level in range(7))
    extra = bytearray(head_sprites())
    words = cells(bar_bits([(22, 'Then he dreams.')])[8:24]) + cells(clock_face('23:00'))
    extra[0x100:0x100 + len(words)] = words
    extra[0x3c0:0x3c0 + 63] = spark()
    return screens + bytes(extra) + cells(bits)


def door():
    bits, pairs = fit(LD)
    bits[104:112, 264:288] = clock_face('22:52')
    warm = [0, 9, 8, 7, 1]
    out = b''
    for edge in (28, 60, 400):              # how far to the right the light of the door reaches
        values = []
        for r, c in PLACES:
            part = patch[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
            if part.mean() > .3 and TOP / 8 <= r < BOTTOM / 8:
                a, b = pairs[r, c]
                shown = c * 8 < edge
                values.append(warm[b] << 4 | warm[a] if shown else 0)
            else:
                values.append(colour(pairs, r, c, 4))
        out += screen(values, 48)
    return (out + head_sprites()).ljust(0x2000, b'\0') + cells(bits)


def bed_cells():
    bits_a, pairs_a = fit(L)
    bits_b, pairs_b = fit(LB)
    data_a, data_b = cells(bits_a), cells(bits_b)
    out = bytearray()
    for r, c in PLACES:
        n = r * 40 + c
        new = data_b[n * 8:n * 8 + 8]
        if r < 21 and (r, c) not in ((13, 33), (13, 34), (13, 35)) and (
                new != data_a[n * 8:n * 8 + 8] or tuple(pairs_a[r, c]) != tuple(pairs_b[r, c])):
            out += n.to_bytes(2, 'little') + new + bytes(colour(pairs_b, r, c, level) for level in range(7))
    return bytes(out + b'\xff\xff')


def head_sprites():
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
    return bytes(sprites)


for name, data, most in (('room', room(), 0x4000), ('door', door(), 0x4000), ('bed', bed_cells(), 0x800),
                         ('text', texts(), 0x2000)):
    assert len(data) <= most, name
    open(f'src/intro/{name}.bin', 'wb').write(data)
