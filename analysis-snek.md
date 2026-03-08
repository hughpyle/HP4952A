# Snek Game Analysis

Analysis of the "snek" snake game for the HP4952A protocol analyzer, written in Z80 assembly.

## Architecture

The game is structured as:
- `snek.asm` — Main game loop, movement, hit detection, food spawning, borders
- `snek_getkey.asm` — Keyboard polling with timeout (includes `lib/keyb.asm`)
- `snek_tail.asm` — Circular buffer tail management and screen rendering
- `snek_score.asm` — Scoring, endgame screens, hi-score twinkle animation
- `xrnd.asm` — 16-bit XORShift PRNG (self-modifying code stores seed at `_xrnd+1`)
- `lib/` — HP4952A platform libraries (header, DLL loader, screen, keyboard, printf)

**Display:** 16×32 character cells. Each cell can hold 4 "pixels" (2×2 quadrants) using block graphics characters `0xB0`–`0xBF`. Playable area: 14×30 cells (rows 2–15, columns 2–31).

**Coordinate system:** Pixel coordinates (0–63 × 0–31) stored in `_position`. Screen coordinates (1–32 × 1–16) derived by dividing by 2. Borders at rows 1, 16 and columns 1, 32.


## Bugs Found

### 1. Tail off-by-one: stale pointer reads uninitialized memory

**Status:** Known bug (README), partially mitigated with guard buffer, root cause unfixed.

In `_tail_put_position` (snek_tail.asm:19–41), the head write position is computed as:

```z80
ld hl, (_tail_tail_location)    ; = _tail_buff at init
add hl, de                       ; de = actual_length (just incremented to 1)
add hl, de                       ; hl = _tail_buff + 2*actual_length
```

The first position is stored at `_tail_buff + 2`, leaving `_tail_buff[0..1]` unwritten (contains zeros from `defs`).

After 33 moves (when `actual_length` exceeds `target_length` of 0x20), `_tail_remove_end` reads `_tail_tail_location` = `_tail_buff[0..1]` = `(0, 0)`. This pixel position (0,0) maps to screen coordinates (0,0), which `_locxy` converts to memory address **0x80BE** — well outside the screen buffer (0x4000–0x43FF).

The code reads and writes to this out-of-bounds address, which could:
- Cause a visible artifact if it happens to alias screen memory
- Corrupt other memory-mapped state
- Be benign if the address is ROM (writes ignored)

**Root cause:** The head pointer formula `_tail_buff + actual_length*2` produces an off-by-one offset from the tail pointer at `_tail_buff`. The first stored position should be at `_tail_buff[0]`, not `_tail_buff[2]`.

**Potential fix:** Initialize `_tail_tail_location` to `_tail_buff - 2` (or equivalently, `TAIL_BUFF_END - 1`) so the first write lands at `_tail_buff[0]`. Or change the head formula to use `(actual_length - 1) * 2`.


### 2. `_go_faster`: register E is uninitialized

**File:** snek.asm:446–475

The speed calculation aims to reduce `_delay_ticks` by ~10% per food eaten. The algorithm multiplies delay by 26 then takes the high byte (dividing by 256):

```z80
ld a, (_delay_ticks)
ld d, 0         ; d = 0
ld h, d         ; h = 0
ld l, a         ; hl = delay
add hl,hl       ; 2*delay
add hl,de       ; 2*delay + de   ← BUG: e is garbage
add hl,hl       ; ...
add hl,hl
add hl,de       ; adds garbage again
add hl,hl
```

Register `e` is never set. It contains whatever was left from the calling context (typically a byte from `_locxy`'s screen address calculation or `_printf` internals). The intended code should set `e = a` (delay) so that `de = delay`:

```z80
ld d, 0
ld e, a         ; ← missing instruction
ld h, d
ld l, a
```

With the fix, the math computes `26 * delay`, giving `h = (26 * delay) / 256 ≈ 10%` reduction. Without it, the speed-up per food varies between ~5% and ~15% depending on the garbage in `e`. Not game-breaking, but produces inconsistent difficulty progression.


### 3. Twinkle animation iterates 7, not 8

**File:** snek_score.asm:143

```z80
_twinkle_animate:
    ...
    ld b, 7       ; ← should be 8
```

There are 8 twinkle slots (`_twinkle_data_len = 0x10` = 16 bytes / 2 bytes each = 8 entries). `_twinkle_make_one` correctly uses `ld b, 8`, but `_twinkle_animate` uses `ld b, 7`, so the 8th twinkle is created but never animated or cleaned up. It persists on screen as its initial character (0xA2) and is never cleared.


### 4. Twinkle data not fully zeroed on restart

**File:** snek.asm:436–441

```z80
ld b, _twinkle_data_len-1   ; = 15
ld hl, _twinkle_data
_init_twinkle_data:
    inc hl                    ; skip byte 0
    ld (hl), 0
    djnz _init_twinkle_data
```

This zeros bytes 1–15 but skips byte 0 (the first twinkle's Y coordinate). On game restart (after game-over), a leftover twinkle from the previous hi-score screen may appear briefly. The `defs` initializer only applies at assembly time; after the first game, byte 0 could contain any Y coordinate.

**Fix:** Start the loop at byte 0 instead of byte 1:

```z80
ld b, _twinkle_data_len
ld hl, _twinkle_data
_init_twinkle_data:
    ld (hl), 0
    inc hl
    djnz _init_twinkle_data
```


### 5. App won't load from disk

**Status:** Known bug (README), hack attempted in commit 1f8b4ba.

The "Hack to allow save-app-to-disk" commit hard-coded the file size (`defw 0020h`) and padded the binary to 0x2100 bytes (seek 0x20FF). The app still doesn't load from disk according to the README.

The likely cause is the entry point mechanism. When loaded via serial remote (`comms` script), the data is written into application memory and execution starts via `EXAP`. When loaded from disk, the HP4952A's disk loader may use a different entry path. The `_entryaddr` at offset 0x0147 points to `__init`, which runs the DLL stub (patching ROM addresses into jump vectors). If the disk loader skips this initialization or expects a different memory layout, the patched function calls will fail.

David Kuder's [4952oss](https://github.com/dkgrizzly/4952oss) project successfully loads apps from disk using the same bootstrap structure, so the issue may be subtle — perhaps a missing ROM page setup or incorrect memory bank selection during the copy from disk to RAM.


## Non-Bug Observations

### Score limited to 8-bit (max 255)
`_cur_score` is `defb` (1 byte). Score increments by 1 per food. At score 255, the next `inc a` wraps to 0. Not likely to be reached in normal play, but a player who persists long enough would see their score reset.

### High score not persistent
`_high_score` survives across game-over/restart within a single session (it's in RAM), but is lost when the app is reloaded. Persisting to disk would require HP4952A file I/O that isn't currently implemented.

### Food placement can loop
`_find_empty_space` generates random coordinates and retries if the cell isn't empty (0x20). If the board is nearly full, this could spin for a long time. In practice, the 14×30 board is unlikely to be more than ~50% full with a max tail of 512 pixels.

### Self-modifying PRNG
`_xrnd` stores its seed at `_xrnd+1` (the operand of its own `ld hl,nnnn` instruction). This is standard practice for Z80 PRNGs and works correctly since the code runs from RAM.

### Stack depth in `_die`
A comment at snek.asm:232 notes `; TODO pop the stack fwiw? (I forget what called us)`. The `_die` function is reached via `jr _die` from `_move_one_step`, which was called from the main loop. The stack still has a return address from `_move_one_step`. The `_endgame` → `_app_start` path resets the game and re-enters the main loop, so the orphaned return address leaks one stack entry per death. Over many games, this could exhaust the stack, though it would take hundreds of deaths.
