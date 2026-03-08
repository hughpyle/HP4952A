# HP 4952A Firmware EPROM Analysis

Analysis of EPROM dumps from the [HP4952A_VintageProject](https://github.com/thilographie/HP4952A_VintageProject) repository. This is a Version 1.0 (1986) unit.

The HP 4952A contains three processors: a **Z80** (main UI/control), a **68008** (protocol analysis), and an **80C88** (floppy controller). Additionally, two **87C51** microcontrollers manage memory banking and extended RAM.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  PSU-CPU-CRT Board                                          │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ Z80 CPU  │  │ U212 (10029) │  │ U914 (10005)           │ │
│  │          │──│ Boot ROM     │  │ Character ROM           │ │
│  │          │  │ 32KB         │  │ 32KB                    │ │
│  └──────────┘  └──────────────┘  └────────────────────────┘ │
│  ┌──────────┐                                               │
│  │ 68008    │  (shares bus with Z80)                        │
│  └──────────┘                                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  RAM-ROM Board                                              │
│  ┌──────────────┐  ┌───────────┐  ┌───────────┐            │
│  │ U204 (10029) │  │ U500      │  │ U502      │            │
│  │ Boot ROM     │  │ (10028)   │  │ (10027)   │            │
│  │ 32KB         │  │ 64KB      │  │ 64KB      │            │
│  │ = U212       │  │ Remote +  │  │ Menus +   │            │
│  └──────────────┘  │ Protocol  │  │ Config    │            │
│  ┌──────────────┐  │ Decode    │  └───────────┘            │
│  │ U503 (10026) │  └───────────┘  ┌───────────┐            │
│  │ 64KB         │                 │ U304      │            │
│  │ Display +    │                 │ 87C51     │            │
│  │ Mass Store + │                 │ 4KB       │            │
│  │ Self-Test    │                 │ Bank Ctrl │            │
│  └──────────────┘                 └───────────┘            │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────────────┐  ┌──────────────────────────┐
│ Floppy Controller Board      │  │ Extended RAM Option Board │
│ ┌────────────┐               │  │ ┌───────────┐            │
│ │ U606       │  80C88 CPU    │  │ │ U507      │            │
│ │ (10021)    │               │  │ │ 87C51     │            │
│ │ 32KB       │               │  │ │ 4KB       │            │
│ │ Floppy FW  │               │  │ │ RAM Ctrl  │            │
│ └────────────┘               │  │ └───────────┘            │
└──────────────────────────────┘  └──────────────────────────┘
```


## Memory Banking

The Z80 addresses 64KB total. Lower 32KB (0x0000–0x7FFF) is RAM; upper 32KB (0x8000–0xFFFF) is banked ROM/RAM selected via I/O port 0x20:

| Page | Purpose | Source |
|------|---------|--------|
| 2 | Application ROM (loaded apps appear here) | RAM |
| 4 | System ROM lower page (ordinal/jump table at 0x8000) | U500/U502/U503 |
| 6 | Application RAM (work area) | RAM |

The DLL stub in application code (`snek/lib/strap.asm`) copies 308 bytes of system ordinals from Page 4 at 0x8000 into RAM at 0x2D00, then patches application code with resolved ROM function addresses.


## Individual ROM Analysis

### U212 / U204 — Z80 Boot + 68008 Exception Handlers
- **Part:** 04952-10029 (TMS27C256, 32KB)
- **Board:** U212 on PSU-CPU-CRT; U204 on RAM-ROM (identical copies, same MD5)
- **CPU:** Z80 (primary) + 68008 (secondary)
- **Role:** System boot and initialization

**Z80 boot sequence** (offset 0x0000):
```
LD SP, 8000h    ; Stack at top of lower 32KB RAM
XOR A
EX AF,AF'
IN A,(03h)      ; Read system status port
XOR A
OUT (03h),A     ; Clear status
LD A,2Bh
OUT (03h),A     ; Set initial configuration
```

Also contains **68008 exception handler** strings:
- "---Bus Error---"
- "---Address Error---"
- "---Illegal Instruction---"
- "---Zero Divide---"
- "---CHK Instruction---"
- "---TRAPV Instruction---"
- "---Privilege Violation---"
- "---Trace---"
- "---1010 Exception---"
- "---1111 Exception---"
- "Error! Entry Mode=User"
- "Run Aborted! Mode=User"

The dual presence of Z80 code and 68008 strings confirms this ROM is shared between both processors via the system bus. The Z80 boots first and likely initializes the 68008.


### U914 — CRT Character ROM
- **Part:** 04952-10005 (MBM27C256, 32KB)
- **Board:** PSU-CPU-CRT
- **CPU:** CRT controller (directly accessed by display hardware)
- **Role:** Character generator / font ROM

Contains bitmap font data in 16-byte entries:
```
00 7F [header] [6–8 glyph bytes] 7F FF 00 00 00
```

Multiple character sets at 256-byte intervals (matching the analyzer's display modes):
- ASCII (normal and inverted)
- EBCDIC
- Hex display
- Baudot
- Transcode
- IPARS

Each character is rendered as a bitmap for the CRT display. The `0x7F` delimiters mark entry boundaries. The snek code references these character sets via screen attribute bytes (e.g., `_scrattr_ascii_n = 0x83`, `_scrattr_graphics = 0x80`).


### U500 — Remote Protocol + Protocol Decode Engine
- **Part:** 04952-10028 (MBM27C512, 64KB)
- **Board:** RAM-ROM
- **CPU:** Z80
- **Role:** Remote control protocol, protocol decoding, data analysis

**Key contents:**
- **Remote protocol implementation** — all command handlers: IDRE, TRBR, CKDR, RCCD, SEBL, TRAH, TRAP, RCAH, RCAP, TRTC, RSRE, TRRS, EXRU, EXBR, TRBS, LOKB, ENKB, EXAP, RCAL, TRAL
- **Attribution:** "Remote by Gary Zimmerman"
- **Device ID string:** "HP4952"
- **State machine strings:** "In Top level", "In Setup Menu", "In Mon/Sim Menus", "In Examine Data", "In Run Menu", "In Mass Store Menu", "In Slave Menu", "Exec Mass Store Op", "Executing Run Menu"
- **X.25 packet decode:** Call Request, Clear, Reset, Restart, Interrupt, Diagnostic, Registration
- **HDLC/SDLC frame decode:** RR, RNR, REJ, SREJ, SNRM, SABM, DISC, UA, FRMR, etc.
- **Counter/timer display** and printer output formatting
- **Error messages:** "The Slave Does Not Respond", "No Data in Slave Capture Buffer", "Menus Incompatible with 4952"

This is the core protocol analysis engine. The jump table at offset 0 (`C3 52 83` = JP 8352h) provides the entry point vector. The remote protocol handler here is what the Python `comms` script communicates with.

**Command dispatch table** at file offset 0x9552: 28 entries of `4-byte ASCII command name` + `2-byte handler file offset` (little-endian), separated into two groups by 0xFF delimiters. Handler code resides in the lower 32KB of the ROM (file offsets 0x563C–0x60FD), which maps to Z80 addresses 0xD63C–0xE0FD when banked. Response construction code is in the upper 32KB (file offsets 0xA900–0xB100 region).

**Decompiled handlers** (see analysis-remote-protocol.md):
- **CKDR** (Check Disc Ready): handler at file 0x5C8C reads floppy disc ID via `OUT (70h)`, validates 10 bytes against reference, returns 6-byte ready/not-ready status
- **TRRS** (Transfer Run State): associated with 10 state description strings at file 0xA974, state mapping function at file 0x150F; returns 6-byte current UI/menu state


### U502 — Main Menus + Protocol Configuration
- **Part:** 04952-10027 (MBM27C512, 64KB)
- **Board:** RAM-ROM
- **CPU:** Z80
- **Role:** User interface, menus, protocol setup

**Key contents:**
- **Boot splash:** "Hewlett - Packard", "Protocol Analyzer", "Rev 1.0", "1986"
- **Main menu page 1:** "Auto/Set/Mon/Sim/Run/Exam" (Configure, Setup, Monitor, Simulate, Run, Examine Data)
- **Main menu page 2:** "Re-set/BERT/Remote&Print/Mass Store/[App]/Self Test"
- **Remote and Printer Menu:** "Control Slave", "Print Setup", "Print All"
- **Monitor/Simulate/Data menus:** line monitor, buffer, data filter, BERT
- **Protocol selection:** HDLC, SDLC, X.25, BSC, Char, X.21
- **Character encoding setup:** ASCII 7/8, EBCDIC, Hex, Baudot, Transcode, IPARS (idle 0/1)
- **Line parameters:** Parity (None/Even/Odd/Ignore), Bit order (LSB/MSB first), Bit sense (Normal/Inverted), DTE clock, Sync settings

The snek game's `_splash_menu_data` mirrors this menu structure — it replaces page 2 button 5 (normally blank) with "snek/SNEK".


### U503 — Data Display + Mass Storage + Self-Test
- **Part:** 04952-10026 (MBM27C512, 64KB)
- **Board:** RAM-ROM
- **CPU:** Z80
- **Role:** Data examination, floppy disk operations, diagnostics

**Key contents:**
- **Examine Data menus:** Hex/Text display, Roll Up/Down, Next/Prev Page, Timer & Counter, Bit Shift, Data Segments, Highlight navigation
- **Data display:** "Bin = ... Hex = ... Shift = ... Par. = ... Octal = ..."
- **Frame markers:** Frame Start/End, Good/Bad FCS, Abort character, Block check
- **Mass Storage (MSD) operations:** Dir, Load, Store, Delete, Recover, Format, Pack Disc, Rename, Execute, Print Dir
- **File types:** Data, Menu, Menu&Data, Applic, Ext Menu, Prog
- **Floppy errors:** "Runtime Disc Timeout", "Floppy Error", "Floppy removed during a read", "Floppy read error", "Disc Controller Self Test Error"
- **Self-Test and Diagnostics menu:** CRT Test, Keyboard Test, Loop Test, Alignment Pattern, Character Sets 1/2, Video Pattern/Calibration/Inverse, Disc/Ext Track/FDC tests, BERT (corrected/uncorrected), RAM test, Format
- **RAM test:** "LOW RAM FAILURE"
- **Menu corruption recovery:** "Menus corrupt; menus have been reset to the default condition."


### U606 — Floppy Controller Firmware
- **Part:** 04952-10021 (MBM27C256, 32KB)
- **Board:** Floppy Controller
- **CPU:** 80C88 (Intel)
- **Role:** Floppy disk drive controller

Starts with 8088 far jump: `EA 5F A4 00 F0` = `JMP FAR F000:A45F` (standard 8088 reset vector region). The 80C88 is a dedicated processor solely for floppy disk I/O.

Contains string: **"Floppy board controller code. Hewlett Packard Corp, July 1985."**

This is the oldest dated code in the system (July 1985), predating the main firmware (1986). The floppy controller operates independently, receiving commands from the Z80 over the system bus.


### U304 — Memory Bank Controller
- **Part:** 04952-10017 (87C51, 4KB)
- **Board:** RAM-ROM
- **CPU:** 87C51 (Intel MCS-51 family)
- **Role:** Memory page/bank switching controller

This microcontroller manages the banked memory system. When the Z80 writes to I/O port 0x20 (via `OUT (020h), A`), the 87C51 decodes the page number and controls address lines to select which ROM/RAM appears in the Z80's upper 32KB address space (0x8000–0xFFFF).


### U507 — Extended RAM Controller
- **Part:** 04952-10016 (87C51, 4KB)
- **Board:** Extended RAM Option Board
- **CPU:** 87C51 (Intel MCS-51 family)
- **Role:** Optional extended RAM management

Controls the additional RAM expansion board. This is an optional accessory that provides extra capture buffer and application memory. The base 4952A works without this board.


## Cross-Reference with snek Code

The snek application's DLL (dynamic link loader) stub in `lib/strap.asm` directly interacts with this firmware:

1. **Page 4 access** (`OUT (020h), 004h`) — selects one of the system ROM pages (likely U500's lower half) to read the ordinal/jump table at 0x8000
2. **308 bytes (0x134) of ordinals** copied to RAM at 0x2D00 — these are resolved function addresses for ROM subroutines
3. **18 DLL fixup entries** patch the application code with actual ROM function addresses (e.g., `01543h`, `00fe9h`, `00085h`, `01cf8h`, `0007eh`, `00e60h`)
4. **Page 2** (`OUT (020h), 002h`) — switches back to Application ROM where the loaded app resides

The function at `00e60h` (referenced frequently) is the page-switch routine itself, allowing the application to bank in different ROM pages as needed.


## Summary Table

| Chip | Board | Type | Size | HP Part | Role |
|------|-------|------|------|---------|------|
| U212 | PSU-CPU-CRT | TMS27C256 | 32KB | 04952-10029 | Z80 boot + 68008 exception handlers |
| U204 | RAM-ROM | TMS27C256 | 32KB | 04952-10029 | Identical copy of U212 |
| U914 | PSU-CPU-CRT | MBM27C256 | 32KB | 04952-10005 | CRT character generator (multiple font sets) |
| U500 | RAM-ROM | MBM27C512 | 64KB | 04952-10028 | Remote protocol + protocol decode engine |
| U502 | RAM-ROM | MBM27C512 | 64KB | 04952-10027 | Main menus + protocol configuration UI |
| U503 | RAM-ROM | MBM27C512 | 64KB | 04952-10026 | Data display + mass storage + self-test |
| U606 | Floppy Ctrl | MBM27C256 | 32KB | 04952-10021 | 80C88 floppy controller firmware |
| U304 | RAM-ROM | 87C51 | 4KB | 04952-10017 | Memory bank switching controller |
| U507 | Ext RAM Opt | 87C51 | 4KB | 04952-10016 | Extended RAM option controller |

**Total firmware:** 288KB across 9 chips (224KB EPROMs + 8KB microcontrollers)
