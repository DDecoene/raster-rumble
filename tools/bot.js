// bot.js - a dodging bot for testing the game in the browser emulator (vc64web).
//
// It reads the sprite positions straight out of the emulated C64 (Module._wasm_peek) and steers the
// ship by sending the arrow keys, the same way a player does. Use it to get far into the game
// (chapters, the Glitch, later the boss) without playing by hand.
//
// Load it into the emulator page (paste it into the browser console, or inject it with a test
// tool), then:
//     bot.start()     start dodging (it also taps Space on the title and game over screens)
//     bot.start('enemy')   or  bot.start('glitch')   do not dodge: fly into that one, to test hits
//                     ('glitch' dodges the enemy until the Glitch is in the game, then rams the Glitch)
//     bot.status()    {playing, score, best, lives, chapter, games, ...}
//     bot.stop()      stop and release the keys
//
// The bot only moves left and right. It picks the X on the screen that is farthest from every
// falling thing (the enemy, and the Glitch once it is active) and walks there, preferring places
// that are close to where the ship already is. A drifting enemy (chapter 2, The Border) counts twice:
// where it is now, and where it will be when it reaches the height of the ship (bounces included).

(function () {
    // numbers that mirror src/config.asm and src/hardware.asm: keep them in step with those files
    const MIN_X = 24, MAX_X = 320;           // left edge of the ship can be 24 to 320
    const SPRITE = { ship: 0, enemy: 1, glitch: 7 };
    const ZP = { score: 0x04, enemySpeed: 0x07, lives: 0x0e, chapter: 0x31, glitchActive: 0x33, enemyDx: 0x35 };
    const VIC = { x: 0xd000, xhi: 0xd010, enable: 0xd015 };
    const ENEMY_DRIFT = 2;                   // pixels per frame a drifting enemy moves sideways
    const SIZE = 24;                        // sprite width and height in pixels

    const peek = (a) => Module._wasm_peek(a);
    const sprX = (n) => peek(VIC.x + 2 * n) + ((peek(VIC.xhi) >> n) & 1) * 256;
    const sprY = (n) => peek(VIC.x + 2 * n + 1);

    // --- keys -------------------------------------------------------------------------------
    const KEYS = {
        left:  { key: 'ArrowLeft',  code: 'ArrowLeft',  keyCode: 37 },
        right: { key: 'ArrowRight', code: 'ArrowRight', keyCode: 39 },
        fire:  { key: ' ',          code: 'Space',      keyCode: 32 },
    };
    const held = { left: false, right: false };
    const send = (type, k) =>
        document.dispatchEvent(new KeyboardEvent(type, { key: k.key, code: k.code, keyCode: k.keyCode, which: k.keyCode, bubbles: true }));

    function hold(dir) {                     // dir is 'left', 'right' or null (release both)
        for (const d of ['left', 'right']) {
            const want = d === dir;
            if (want && !held[d]) send('keydown', KEYS[d]);
            if (!want && held[d]) send('keyup', KEYS[d]);
            held[d] = want;
        }
    }

    function tapFire() {                     // a human sized tap: a zero length one is too short for the emulator
        send('keydown', KEYS.fire);
        setTimeout(() => send('keyup', KEYS.fire), 80);
    }

    // --- game state ---------------------------------------------------------------------------
    const score = () => peek(ZP.score) * 100 + peek(ZP.score + 1) * 10 + peek(ZP.score + 2);
    const playing = () => (peek(VIC.enable) & 3) === 3 && peek(ZP.lives) > 0;

    function enemyLandingX() {               // where a drifting enemy will be when it reaches the height of the ship
        const dx = ((peek(ZP.enemyDx) << 24) >> 24) * ENEMY_DRIFT;  // 0, 1 or $ff (a signed byte) times the pixels per frame
        const speed = Math.max(1, peek(ZP.enemySpeed));
        const frames = Math.max(0, Math.floor((sprY(SPRITE.ship) - sprY(SPRITE.enemy)) / speed));
        const span = MAX_X - MIN_X;                                 // it bounces between the edges, like a ball
        let pos = (sprX(SPRITE.enemy) - MIN_X + dx * frames) % (2 * span);
        if (pos < 0) pos += 2 * span;
        return MIN_X + (pos > span ? 2 * span - pos : pos);
    }

    function threats() {                     // everything that can hit the ship: [{x, y}]
        const list = [{ x: sprX(SPRITE.enemy), y: sprY(SPRITE.enemy) }];
        if (peek(ZP.enemyDx)) list.push({ x: enemyLandingX(), y: sprY(SPRITE.enemy) });   // a drifting enemy also threatens where it is heading
        if (peek(ZP.glitchActive) && (peek(VIC.enable) & 0x80)) list.push({ x: sprX(SPRITE.glitch), y: sprY(SPRITE.glitch) });
        const shipY = sprY(SPRITE.ship);
        return list.filter((t) => t.y < shipY + SIZE);   // one that has already fallen past the ship is no danger
    }

    function bestX(shipX, list) {            // the X with the best score: far from threats, near to us
        let best = shipX, bestScore = -Infinity;
        for (let x = MIN_X; x <= MAX_X; x += 4) {
            let clear = 120;                 // beyond this distance more room does not help
            for (const t of list) clear = Math.min(clear, Math.abs(x - t.x));
            const s = clear - 0.25 * Math.abs(x - shipX);
            if (s > bestScore) { bestScore = s; best = x; }
        }
        return best;
    }

    function targetX(shipX) {                // where the bot wants to be
        const glitchIn = peek(ZP.glitchActive) && (peek(VIC.enable) & 0x80);
        const ram = mode === 'glitch' && glitchIn ? SPRITE.glitch : mode === 'enemy' ? SPRITE.enemy : null;
        if (ram !== null && sprY(ram) < sprY(SPRITE.ship) + SIZE) return sprX(ram);   // ram it, until it has fallen past
        if (ram !== null) return shipX;                                               // fallen past: wait for the next one
        return bestX(shipX, threats());                                               // dodge mode (or no Glitch yet)
    }

    // --- the loop -----------------------------------------------------------------------------
    let mode = 'dodge';                      // 'dodge', 'enemy' or 'glitch': what the bot does with the falling things
    const stats = { running: false, best: 0, games: 0, maxChapter: 0, lastTap: 0, wasPlaying: false };
    let timer = null;

    function tick() {
        if (!stats.running) return;
        try {
            if (playing()) {
                stats.wasPlaying = true;
                const s = score();
                if (s > stats.best) stats.best = s;
                if (peek(ZP.chapter) > stats.maxChapter) stats.maxChapter = peek(ZP.chapter);
                const shipX = sprX(SPRITE.ship);
                const tx = targetX(shipX);
                hold(tx - shipX > 3 ? 'right' : tx - shipX < -3 ? 'left' : null);
            } else {
                hold(null);
                if (stats.wasPlaying) { stats.games++; stats.wasPlaying = false; }
                const now = Date.now();
                if (now - stats.lastTap > 2000) { stats.lastTap = now; tapFire(); }   // title or game over: start (again)
            }
        } catch (e) {
            console.error('bot stopped:', e);
            window.bot.stop();
            return;
        }
        timer = setTimeout(tick, 5);
    }

    window.bot = {
        start(m) {                           // m: 'dodge' (default), 'enemy' or 'glitch'
            mode = m || 'dodge';
            if (!stats.running) { stats.running = true; tick(); }
            return 'bot running, mode ' + mode;
        },
        stop() { stats.running = false; clearTimeout(timer); hold(null); return 'bot stopped'; },
        status() {
            return {
                running: stats.running, mode, playing: playing(), score: score(), best: stats.best,
                lives: peek(ZP.lives), chapter: peek(ZP.chapter), maxChapter: stats.maxChapter, games: stats.games,
            };
        },
    };
})();
