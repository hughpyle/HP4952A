# Remote Protocol Analysis

Analysis of the HP4952A remote control protocol and the Python `comms` implementation.

## Protocol Summary

The protocol controls an HP4952A protocol analyzer over a serial "Remote/Printer" port. Each message has:

```
Preamble:   0x96 0x96 0x96 0x96     (4 bytes, sync)
Cmd Header: intro1 intro2 cont seqno spare1 spare2  (6 bytes)
CRC-16:     2 bytes (over Cmd Header)
Cmd Data:   variable length (if intro1 == 0x81)
CRC-16:     2 bytes (over Cmd Data, if data present)
```

**Header types:**
- `0x81 <len> ...` — message with data; len=0 means 256 bytes
- `0x05 <status> ...` — message with no data; status: 0x01=ok, 0x02=nack/retry

**Continuation flags:**
- `0xC0` — complete (final, standalone)
- `0x40` — expect continuation
- `0x41` — partial data packet (mid-stream)
- `0xC1` — final data packet

**CRC-16:** polynomial 0x8005, reflect in/out, no XOR, little-endian. Verified correct against all captured samples.

25 commands documented (CKDR, DEAP, ENKB, EXAP, EXRU, IDRE, LOKB, RCAH, RCAL, RCAP, RCCD, RSRE, SEAP, SEBL, SEBS, TRAD, TRAH, TRAL, TRAP, TRBR, TRCD, TRRS, TRTC). Two (CKDR, TRRS) were previously undocumented — their purpose has been inferred via firmware decompilation (see below).


## Issues Found in `comms` Script

### Bug: `ser.write(0xff)` passes int, not bytes (line 664)

```python
ser.write(0xff)
```

In Python 3 with pyserial 3.4, `serial.write()` expects a bytes-like object. Passing an integer raises `TypeError`. This should be:

```python
ser.write(b'\xff')
```

This line sends a trailing 0xFF padding byte after each packet. If it fails, the protocol may still work (the receiver resyncs on 0x96 preamble bytes), which could explain why this hasn't been caught.


### Bug: `0x05 0x02` (nack/retry) not distinguished from `0x05 0x01` (ok)

In `_parse_iter` (line 500-504), when `datacode == 5`, the `intro[1]` byte (which carries `0x01`=success or `0x02`=failure) is ignored:

```python
if datacode == 5:
    databuff = None
    datalen = 0
```

The `status` flag is set based on the continuation byte (line 499), not the actual status byte:

```python
self.status = (self.cont == 0xc0 or self.cont == 0xc1)
```

This means a `0x05 0x02` (nack) response is treated identically to `0x05 0x01` (ok). In `send_message`, if the analyzer sends a nack requesting retransmission, the code will send the *next* message instead of re-sending the current one. This could cause silent data corruption over noisy serial links.

The captured data shows this scenario: `CMD_TRAL_PART4` and `CMD_TRAL_PART5` have `0x05 0x02` (nack), causing the analyzer to re-send the same sequence number, but the code has no logic to handle this.


### Missing: Multi-packet receive (TODO, line 669-672)

The code can *send* multi-packet data (app download via RCAP), but cannot *receive* multi-packet responses. Commands that return large payloads (TRCD, TRAL, TRAP, TRTC) produce chains of `0x41` (partial) packets terminated by a `0xC1` (final) packet. The code only processes the first response.

This limits the tool to download-only. Upload (TRAP) and data capture retrieval (TRCD) are non-functional.


### Missing: CRC error recovery (TODO, line 674)

A CRC mismatch raises `MessageFormatException` and crashes the script. The protocol supports retransmission (the `0x05 0x02` response), but the code never sends a retry request.


### Minor: Incomplete send detection (line 682-683)

```python
if msg.rest:
    logger.debug("Uh oh, we didn't finish")
```

If the analyzer responds with `CONT_FIN` before the controller has finished sending all continuation data, the remaining data is silently dropped with only a debug log. This could happen if the analyzer rejects part of a download.


### Minor: `text` property crashes on binary responses (line 323)

```python
return self.data.decode("ASCII")
```

Binary responses (TRBR memory stats, TRTC timer data) will throw `UnicodeDecodeError`. This only matters if `.text` is accessed on such responses, which the current code avoids — but it's a trap for anyone extending the tool.


### Minor: SEBL flag logic for single-block apps (line 726)

```python
seblflag = 0 if blocknum == 0 else 1 if appdata else 2
```

For an app that fits in a single 2KB block, `seblflag` is always 0 (first), never 2 (last). The analyzer may expect a "last block" flag. This hasn't caused issues in practice (VT100 and snek are multi-block), but would matter for very small apps.


## Protocol Behavior Notes

- **SEBS rejected on 4952A:** Returns "Operation not supported" — buffer size management is only for 4953A/4954A.
- **App download flow:** IDRE → DEAP → TRRS → RCAH (header) → [SEBL + RCAP] × N blocks → SEAP → EXAP.
- **Default baud rate:** 9600. No auto-detection or negotiation.


## CKDR and TRRS: Firmware Decompilation Results

These two commands were previously undocumented. Their purpose has been determined by decompiling the Z80 handler code in the U500 firmware ROM (04952-10028).

### CKDR — Check Disc Ready

**Purpose:** Queries whether a floppy disc is inserted, accessible, and has a valid format.

**Firmware analysis:** The CKDR handler (dispatch table entry at ROM file offset 0x95A7, handler code at file 0x5C8C) performs:

1. Saves the current callback pointer from RAM address 1716h
2. Sets up a disc read operation: 22 bytes from disc identification area (buffer at 7559h)
3. Sends command to the floppy controller via `OUT (70h)`
4. Waits for response with timeout (`CALL 16EEh` with A=10)
5. If timeout → returns "not ready" (HL=0)
6. Calls a 10-byte comparison routine (at file 0x5CCD) that validates disc ID data at 7559h against a reference table at 66F2h
7. Performs additional checks: system state (7501h) must be 12h, and disc type byte (7563h) must be C4h
8. If all checks pass → returns "ready" (HL=1)

**Response format (6 bytes):** Constructed in the upper ROM half (file offset 0xB057) into a buffer at 7C00h:

| Byte | Value | Meaning |
|------|-------|---------|
| 0 | 00 | Reserved (always 0) |
| 1 | 00/01 | Disc presence flag |
| 2 | 00 | Reserved (always 0) |
| 3 | 00/01 | Disc format valid flag |
| 4 | 00 | Reserved (always 0) |
| 5 | 00/01 | Ready status (low byte of check result) |

**Captured response:** `00 00 00 01 00 01` — disc present, format valid, ready.

**Name derivation:** CK = Check, DR = Disc Ready.


### TRRS — Transfer Remote/Run State

**Purpose:** Reports the analyzer's current UI/menu state to the remote controller. Called before app download to verify the analyzer is in the correct state to receive commands.

**Firmware analysis:** The TRRS command name appears at ROM file offset 0xA974, immediately followed by 10 state description strings (variable-length, space-padded):

| Index | Description |
|-------|-------------|
| 0 | In Top level |
| 1 | In Setup Menu |
| 2 | In Mon/Sim Menus |
| 3 | In Examine Data |
| 4 | In Run Menu |
| 5 | In Mass Store Menu |
| 6 | In Slave Menu |
| 7 | Exec Mass Store Op |
| 8 | Executing Run Menu |
| 9 | In Other Menu |

A state mapping function (file offset 0x150F, Z80 addr 0x950Fh) translates the system state variable at RAM address 7501h into these indices:

| State byte (7501h) | → Index | Description |
|---------------------|---------|-------------|
| 0x21, 0x22 | 0 | In Top level |
| 0x11 | 2 | In Mon/Sim Menus |
| 0x13 | 3 | In Examine Data |
| 0x12 | 9 | In Other Menu |
| 0x10 | 5 | In Mass Store Menu |
| 0x23 | 7 | Exec Mass Store Op |
| 0x24 | 10 | (extended state) |
| bit 7 set | 15 | (busy/executing) |
| bit 6 set | 12 | (transitional) |
| other | 0xFF | (unknown state) |

**Response format (6 bytes):** The 6-byte response `00 00 00 00 00 32` encodes the current operational state. The value 0x32 (50 decimal) in byte 5 likely represents a composite status: the `comms` script calls TRRS after DEAP (delete application) and before RCAH (receive application header) to verify the analyzer has returned to a ready state.

**Name derivation:** TR = Transfer/Transmit, RS = Run State (or Remote State).


## Captured Data Files

| File | Lines | Content |
|------|-------|---------|
| `ident.dat` | ~60 | IDRE command/response |
| `reset.dat` | ~40 | RSRE command/response |
| `lock_unlock.dat` | ~80 | LOKB + ENKB sequence |
| `loadapp_vt100.dat` | 27,490 | Full VT100.APP download |
| `loadapp_fail.dat` | ~200 | Failed download ("An Applic is Already Loaded") |
| `more.dat` | 15,427 | TRAL, TRCD, TRTC multi-packet uploads |
| `uploadapp_async56k` | ~230KB | TRAP upload of ASYNC_56K app |
| `ident_reset.dat` | ~100 | Combined IDRE + RSRE |
