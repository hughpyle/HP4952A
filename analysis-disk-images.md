# Disk Image Analysis

Analysis of the HP4952A floppy disk images in the `disks/` directory.

## Disk Format

All disks use **HP LIF (Logical Interchange Format)**, a proprietary filesystem common to HP equipment. This is distinct from DOS FAT formatting. The disks are 3.5" floppies.

**Image formats present:**
- **TD0** (TeleDisk) — 11 images, 479–631 KB each
- **IMD** (ImageDisk) — 2 images, 267–553 KB each

**Extraction tools:** The `extract.sh` script uses [bug400's lifutils](https://github.com/bug400/lifutils) fork with `dskconv` (TD0/IMD → raw) and `lifget -l -r` (extract files with raw headers).


## Disk Inventory

### Utility Disks

| Directory | Image | Date | Contents |
|-----------|-------|------|----------|
| `04952-16009_utility_051690/` | 4952A_Util.IMD (553 KB) | May 1990 | VT100 terminal (A.00.03), ASYNC_56K, ASYNC_64K, COPY_DISC, DEMO_DATA, IPARS_MEC, DCE_BERT |
| `04952-16003_utility_022890/` | 4952A-1.TD0 (557 KB) | Feb 1990 | EXTD_ASYNC (14.4K & 38.4K), TERM/VT100 (A.00.00), COPY_DISC, DEMO_DATA, IPARS_MEC |

The 051690 utility disk is the newer version with the VT100 app at revision A.00.03 (vs A.00.00 in the earlier disk). This is the default app loaded by the `comms` script.

### Demo Disks

| Directory | Image | Date | Contents |
|-----------|-------|------|----------|
| `18241-16003_demo_hp4951c/` | 4951DEMO.TD0 (552 KB) | — | 26 files: sample data captures (COP, BOP, X25, SNA, DDCMP, LINK) + demo apps |
| `18241-16004_demo_hp4952a/` | 4952DEMO.TD0 (479 KB) | — | 37 files: all of the above + X.25 emulation, X.21, BLERT, Level 1 monitor demos |

### Protocol Analysis Disks

| Directory | Image | Date | Protocol | Contents |
|-----------|-------|------|----------|----------|
| `18261-16002_sna_analysis_120490/` | 18261A.TD0 (624 KB) | Dec 1990 | SNA | SNA_DECODE app + SNA_DATA samples |
| `18266-16001_x25_enhanced_011691/` | 18266A.TD0 (621 KB) | Jan 1991 | X.25 | ENHANC_X25 app (Rev 2727), display defs, X25_DATA |
| `18265-16001_docmp_analysis_111690/` | 18265A.TD0 (612 KB) | Nov 1990 | DDCMP | DDCMP4952 app (Rev 2716), training data, TUTORIAL |
| `18263-16002_3270_install_122090/` | 18263A.TD0 (631 KB) | Dec 1990 | 3270 | BSC_3270 + SNA_3270 apps |

### Test Library Disks

| Directory | Image | Date | Contents |
|-----------|-------|------|----------|
| `18267-16001_test_library_012191/` | 18267A.TD0 (548 KB) | Jan 1991 | X.25 Level 2 Emulator + 15 DCE/DTE test apps |
| `05010-05017_library_022890/` | 4952A-2.TD0 (205 KB) | Feb 1990 | 64 C401 test programs (async, sync, X.25, timing) |
| `05010-05017_library_051690/` | 4952A_Library.IMD (267 KB) | May 1990 | Same 64 C401 test programs (later version) |


## LIF File Types

| Type Code | Meaning | Count |
|-----------|---------|-------|
| C400 | Data files (captures, menus, config) | ~22 |
| C401 | Binary test programs | ~64 |
| C402 | Data files (alternate) | varies |
| C403 | Application programs | ~28 |
| C404 | Binary programs (alternate) | varies |


## File Format Notes

### Application file structure (C403)

```
Offset 0x0000: "4952 Protocol Analyzer" magic string
Offset 0x0016: File metadata (size, type codes)
Offset 0x001A: Description string (32 bytes)
Offset 0x0100: Application header
  - Byte 0x02: (number of 256-byte blocks) - 1
  - Bytes 0x08–0x17: App name (padded to 16 chars)
  - Bytes 0x20–0x3F: Description string
Offset 0x0147: Entry point address (word)
Offset 0x0150: Launch address (word)
Offset 0x0180: DLL fixup table (count + pointer)
```

When extracting with lifutils, the `-r` flag skips the 0x20-byte directory entry prefix. Files extracted without `-r` need offset 0x120 instead of 0x100 for the `comms` script.


## Test Library Programs (64 programs)

The test library contains automated test procedures for protocol analysis work:

**Async tests:** A_COUNTCHR, A_COUNTPAR, B_ASC7EVER/ODER, B_AUTOBAUD, B_BRBRPOLE/POLS, B_FOXFLOW
**Flow control:** D_DTR, D_XONXOFF, D_BUFFER, E_DTRFLOW, E_XONXOFF, F_BRBRPOLS
**Timing measurements:** I_AVRTSCTS, I_AVTURND, I_CDOFF, I_CD_TO_RD/TD, I_CTSTD, I_CTS_ERR, I_DSR_DTR, I_LCLTURND, I_RMT_TRND, I_RTS_CTS/TD/ERR
**Sync protocols:** S_CNTERRS, S_CNTIVALL, S_CTSTPRDC/T, S_HILITFLG, S_SNRM, S_UTIL
**X.25 protocols:** X_CALLTRYS, X_CNTALLFR, X_CNTCALLS/CONCT, X_CNTDCEFR/T, X_CNTDTEFR/T, X_CNTERRS, X_CNTIVALL, X_DCEUTIL, X_DTEUTIL, X_HILITFLG, X_LINKUPDN, X_LVL1
**Setup/Alignment:** U_BURS_SPS, U_BUR_A_PS, U_IPARS, U_SYALL7/8, U_UNISCOPE, C_ALGNMNT, C_RESPTIME


## Extraction Script Issues

The `extract.sh` script (disks/extract.sh) generates a secondary script at `/tmp/extract2.sh` but does not execute it — it only prints it with `cat`. The user must manually run it. The script also:
- Strips `?` and `()` characters from filenames via `sed`
- Renames C403 → `.APP` and C402 → `.DAT` extensions
- Generates a `dir.txt` with file descriptions extracted via `strings`

**Note:** The script does not handle C401 or C404 file types in its rename mappings, so those files keep their original type codes as extensions.


## Software Versions and Dates

All software is copyright Hewlett-Packard Co., dating from 1986–1991:
- Earliest: Utility disk v022890 (Feb 1990)
- Latest: Test Library v012191 (Jan 1991)
- The 4952A hardware itself was manufactured from approximately 1988–1993
