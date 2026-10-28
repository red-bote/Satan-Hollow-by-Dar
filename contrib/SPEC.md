# Basys3 port template: source lifecycle and build

Template for the rb-fpga machine repos (one git repo per machine). Bagman is the reference
instance; generic files (`Makefile`, `.gitignore`, `LICENSE`, `contrib/tools/`, this spec)
are identical across repos. Per-machine values live in `machine.conf`.

## 1. Goals

- Every change to an original is a patch against a known original:
  - upstream sources: `contrib/patches/*.patch`, applied in place, patched files tracked;
  - board top -> Basys3 wrapper, Digilent XDC -> project XDC, empty project -> `.xpr`:
    `contrib/basys3/*.patch`, applied to copies in the project, results tracked.
- A clone builds roms and a bitstream with no dev scripting (`make roms bitstream`).
- `make check` proves the tracked tree equals zip + normalization + patches.

## 2. Layout

```
Makefile, machine.conf, .gitignore, README.md, LICENSE
contrib/
  SPEC.md
  tools/user/           end-user build: roms.sh, bitstream.sh, build.tcl, open.sh,
                        clean.sh, localize_xpr.sh, normalize_xpr.sh
  tools/dev/            tree regeneration: fetch.sh, normalize.sh, normalize_file.sh,
                        vhdl_formatter.py,
                        apply_patches.sh, project.sh, diffs.sh, paths.sh,
                        empty_project.tcl, clk_wiz.tcl
  third_party/<party>/  pristine third-party files: the Digilent XDC, and HDL sources
                        imported into the project (e.g. mist/scandoubler.v)
  patches/              upstream source patches (a/<SRC_DIR>/..., -p1 from repo root);
                        new upstream-tree files (e.g. <PROM_SCRIPT>) as creation patches
  basys3/               <board_top>_to_basys3.patch, <PRJ>_xdc.patch, <PRJ>_xpr.patch,
                        <party>_<stem>.patch (third-party import fixes, optional)
dloads/                 zip cache (gitignored)
<SRC_DIR>/              upstream as shipped; patched files normalized and patched (tracked)
  <UNZIP_DIR>/<PROM_SCRIPT>    .sh port of the .bat (tracked; created by make patch)
  <PRJ_DIR>/<PRJ>.xpr          tracked
  <PRJ_DIR>/<PRJ>.srcs/sources_1/new/<TOP>.vhd                       wrapper (tracked)
  <PRJ_DIR>/<PRJ>.srcs/constrs_1/imports/digilent-xdc-master/*.xdc   XDC (tracked)
  <PRJ_DIR>/<PRJ>.srcs/sources_1/imports/clk_wiz_0/*.v               MMCM (tracked)
  <PRJ_DIR>/<PRJ>.srcs/sources_1/imports/<party>/*    third-party imports (tracked)
  <PRJ_DIR>/proms/             generated PROM VHDL, make_vhdl_prom in bin/ (gitignored)
```

`machine.conf` project keys: `PRJ_DIR` (project directory under `<SRC_DIR>`), `PRJ`
(project and `.xpr` name), `TOP` (wrapper entity and file stem; Vivado names the bitstream
`<TOP>.bit`). Convention, used by all repos: `PRJ_DIR=basys3`, `PRJ=TOP=<stem>_basys3`,
with `<stem>` from the board top `<stem>_de10_lite.vhd`.

`README.md` sections, in order: title paragraph (game, upstream link and zip), Hardware,
Build, IO, Issues Addressed (one line per patch), Third-party additions (only when
`contrib/third_party/` holds HDL), License. `LICENSE` is identical across repos: MIT,
scoped to the port's own files and changes; vendor templates (Digilent XDC, Vivado
project, clk_wiz output) are not named.

### 2.1 Sources and provenance

Every file belongs to one of four classes:

1. **Upstream (zip)**: `<SRC_DIR>/`, identified by `ZIP_URL` and `ZIP_SHA256`.
   README: title paragraph (link, zip, revision); License lists the terms in the
   upstream `README.txt` and each third-party core found in the tree (e.g. T80, T65,
   YM2149).
2. **Third-party HDL**: not in the zip, not authored here, built into the bitstream (e.g.
   MiST `scandoubler.v`). Kept pristine in `contrib/third_party/<party>/`; changes in
   `contrib/basys3/<party>_<stem>.patch`. Recorded: name, original author, license,
   origin URL (pinned commit when known; name the copy when taken from one), local path.
   README: Third-party additions and License.
3. **Vendor templates**: Digilent `Basys-3-Master.xdc` (`digilent-xdc`, commit
   69d35015), the Vivado empty project, the clk_wiz output. Patch bases or generated
   files; not named in the README or `LICENSE`.
4. **Port work**: `Makefile`, `machine.conf`, `contrib/tools/`, patch content, wrapper code
   and comments, docs. Authored for this repo. Each patch's `#` header states what changes
   and why, self-contained: no references to other repos or ports. README Issues
   Addressed carries one line per patch, problem first.

## 3. Lifecycle (dev)

1. `make pristine`: delete `<SRC_DIR>/`.
2. `make fetch`: download `ZIP_URL` to `dloads/` unless cached with matching `ZIP_SHA256`;
   hard-fail on mismatch.
3. `make extract`: unzip into the repo root.
4. `make normalize`: only the files the patches modify are normalized: the targets of
   `contrib/patches/*.patch` (`--- a/<SRC_DIR>/...`), by
   `contrib/tools/dev/normalize_file.sh`: text to LF, trailing whitespace stripped, final
   newline; `.vhd` re-indented by `contrib/tools/dev/vhdl_formatter.py` (2-space, no
   align); per-file check: content with all whitespace removed is unchanged. Every other
   upstream file, the board top included, stays as shipped (CRLF kept), so the published
   tree differs from the zip only where the port changes it.
   File names containing spaces are renamed, spaces to `_` (Burnin-Rubber
   `burnin_rubber _sound.vhd` -> `burnin_rubber__sound.vhd`, the published repo's name).
5. Commit the normalized baseline (`make baseline` = steps 2-4).
6. Author patches; `make patch` applies `contrib/patches/*.patch` (skips applied ones).
7. `make project`:
   1. `empty_project.tcl` creates `<PRJ>.xpr` in `<PRJ_DIR>` (part, Basys3 board part, VHDL);
      `normalize_xpr.sh` sets the `Path` attribute and the `Id` option to fixed
      placeholders (Vivado writes an absolute path and a random GUID on every run);
   2. board top `<BOARD_TOP>` copied to `/tmp` and normalized there (the tracked board
      top stays as shipped), wrapper patch applied, result written to the wrapper location;
   3. Digilent XDC copied to `constrs_1/imports/digilent-xdc-master/`, XDC patch applied;
   4. each file in `contrib/third_party/<party>/` (party other than `digilent`) copied to
      `sources_1/imports/<party>/`; `contrib/basys3/<party>_<stem>.patch` applied when
      present (`third_party_imports` in `paths.sh`);
   5. `contrib/tools/dev/clk_wiz.tcl` generates the MMCM (100 MHz in, `CLK_MHZ` out) in a
      scratch project; `clk_wiz_0.v` and
      `clk_wiz_0_clk_wiz.v` copied to `sources_1/imports/clk_wiz_0/` (plain sources, no
      `.xci`: no IP lock or upgrade state in the tracked project);
   6. `.xpr` patch applied (sources, constraints, top).
8. `make diffs` regenerates the `contrib/basys3/*.patch` from the tracked results (the
   wrapper patch against the same normalized `/tmp` copy of `<BOARD_TOP>`)
   (iterate: edit tracked file, `make diffs`, commit both). A third-party import patch is
   written only when the import differs from its original. `make diffs` records the
   tracked `.xpr` as is: a project opened directly in the Vivado GUI (not via `make open`)
   carries Vivado's rewrite (absolute Path, run state, `/tmp`-relative paths); regenerate
   it with `make project` first.
9. `make check`: steps 1-7, then `git diff --exit-code`.

Authoring the `.xpr` patch (first time per machine): `make project` (empty `.xpr`), then
`localize_xpr.sh`, add sources and set the top in Vivado (GUI via `make open`, or a scratch
batch TCL run from `/tmp`), `normalize_xpr.sh`, `make diffs`. The patch carries the
source/constraint entries, the top, and Vivado's own rewrite of the empty project on save
(collapsed `StratHandle`, `sim_1` filter).

`<Project Path>` handling: the tracked placeholder (`<PRJ>.xpr`) makes Vivado treat the
project as moved from its working directory (`/tmp`) and re-express non-existent paths
(run `AutoIncrementalDir`) against it. Every scripted open therefore runs
`localize_xpr.sh` first (real absolute Path); `bitstream.sh` restores the tracked `.xpr`
afterwards and `open.sh` re-normalizes Path/Id. The placeholder `Id` is accepted by
Vivado unchanged.

## 4. User build

- `make roms`: compile `make_vhdl_prom` from the upstream `tools/tools_prom_src/src/`
  (binary in `<PRJ_DIR>/proms/bin/`, gitignored), unzip each zip of `ROMSET`
  (comma-separated, e.g. parent and clone set; read from `ROMDIR`, default `~/roms`) into
  `<UNZIP_DIR>/`, run `<PROM_SCRIPT>` writing PROM VHDL into `<PRJ_DIR>/proms/`. `ROMZIP`
  (comma-separated zip paths) overrides `ROMSET`/`ROMDIR`.
- `make bitstream`: runs `make roms` first if `<PRJ_DIR>/proms/.done` (written by
  `roms.sh`) is missing; Vivado batch (`contrib/tools/user/build.tcl`) on the tracked
  `.xpr`, run from `/tmp`; bitstream `<PRJ_DIR>/<PRJ>.runs/impl_1/<TOP>.bit`.
- `make load`: openFPGALoader to SRAM. `make clean`: Vivado outputs, roms, proms.
- `make open`: Vivado GUI on the tracked `.xpr` (Path localized before, Path/Id
  normalized after; GUI edits kept).
- These targets use only `contrib/tools/user/`; `contrib/tools/dev/` serves section 3.

## 5. Conventions

- Static scripts; Vivado driven by `.tcl` files with `-tclargs` (no generated TCL).
- Vivado runs from `/tmp` so `vivado.log` / `vivado.jou` stay out of the repo.
- `VIVADO` (default `/tools/Xilinx/Vivado/2020.2/bin/vivado`), `ROMDIR` and `ROMZIP` override.
- Keyboard: MAME default keys (arrows, Left Ctrl button 1, Left Alt button 2, Space
  button 3, 1/2 start, 5 coin), decoded in the wrapper from `io_ps2_keyboard` scancodes
  with F0 release tracking; E0 ignored, as in the upstream `kbd_joystick` (requiring E0
  loses the arrow keys on the Basys 3 USB-HID PS/2 emulation); `kbd_joystick` unused.
- Inputs (PS/2, joystick, buttons) through 2-FF synchronizers on the core clock: two
  flip-flops in series per asynchronous input (`*_meta`, `*_s`, `ASYNC_REG`), so a
  metastable first stage has a clock period to settle before the core samples it.
- Slide switches are not synchronized: sw14/sw15 drive the PmodAMP2 pins directly (no
  clocked logic); sw13 and the DIP switches are static settings, changed with the game
  idle.
- Pmod headers: Atari joystick on JXADC pins 1/2/3/4/7 = right/left/down/up/fire
  (wrapper port `JXADC(4 downto 0)`, active low, XDC pull-ups); PmodAMP2 on JA pins
  1/2/4 = AIN/GAIN/SHUTD. A game without a direction uses that pin for an extra button.
- PmodAMP2: sw15 up = audio disabled (`O_PMODAMP2_SHUTD <= not sw(15)`, SHUTD active
  low); sw14 up = gain active (`O_PMODAMP2_GAIN <= not sw(14)`, GAIN active low).
- Roms, generated PROM VHDL and bitstreams are never committed or distributed.
- Patches keep changes minimal (no reformatting, renames or reordering beyond need).
- The Basys 3 wrapper minimizes textual difference from the board top: its comments
  are kept; added comments only for significant findings or deviations from the board
  top, terse, at the logic they describe; no dates or change history (git holds that).
  Exception, the header: the wrapper is its own release (`release rev 01 : initial Basys 3
  release`), credits the board top by file name and author, and points to it for its
  history; the board top's release history is not copied. Its license notice stays.
  Repeated blank lines are collapsed to one.

## 6. Adding a machine

1. Copy `Makefile`, `.gitignore`, `LICENSE`, `contrib/SPEC.md`, `contrib/tools/` and
   `contrib/third_party/digilent/` from an existing repo; write `machine.conf` (project
   keys per section 2: `basys3`, `<stem>_basys3`).
2. `make pristine baseline`; commit the normalized baseline.
3. Author upstream patches against normalized files, one concern per patch, each with a
   `#` header (section 2.1, class 4). A file patched for the first time is normalized
   once its patch exists in `contrib/patches/` (re-run `make pristine baseline`), so the
   patch is written against the normalized file.
4. `<PROM_SCRIPT>`: bash port of the upstream `.bat`, as a creation patch in
   `contrib/patches/`.
5. Third-party HDL: pristine file in `contrib/third_party/<party>/`.
6. `make patch project`; edit the wrapper (from the board top, minimal diff, MAME keys),
   the XDC (uncomment/rename template lines) and third-party imports in place; `make roms`;
   add sources and the top to the `.xpr` (see section 3); `make diffs`.
7. `make check`, then `make bitstream` and hardware test.
