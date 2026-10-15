# Gowin official DVI reference port for ACG-720

This independent project ports Gowin Semiconductor's official DVI TX
reference design from GW2A-18C to the ACG-720 GW5AT-60B board.

It outputs the official reference test pattern as 1280x720p60 RGB888 DVI over
the board's HDMI1 connector. It deliberately contains no camera, DDR, OSD,
UART, motor, AI, audio, data islands, or AVI InfoFrame logic.

## Recommended bitstream

`impl/pnr/gowin_official_dvi_acg720_720p60.fs`

SHA256:

`B691FE5D5A4D8E21480813FCDDD80DCD859F81C72766D146E13F7F777804D04F`

## Rebuild

Run from this directory with Gowin EDA V1.9.12.03:

```powershell
& 'C:\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe' '.\build_official_dvi_acg720.tcl'
```

## Evidence level

- Official source provenance: verified by ZIP and per-file SHA256
- Source adaptation review: complete
- Synthesis: passed
- Placement and routing: passed
- Static timing: Setup/Hold violations 0
- Bitstream generation: passed
- Direct-monitor test: passed (stable picture observed by the user)
- RK3588 HDMI-IN lock/capture: failed to lock in the current hardware test

The same RK3588 HDMI-IN port can lock to a PC source. This narrows the
remaining investigation to FPGA TMDS electrical quality/clocking/startup and
pure-DVI receiver compatibility; it does not by itself prove a single root
cause.

See `SOURCE_MANIFEST.md` for the official source URL, all required board-port
changes, file hashes, implementation results, and evidence boundaries.
