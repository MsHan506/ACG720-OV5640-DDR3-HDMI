# Gowin official DVI TX reference design: ACG-720 port

## Official source

- Vendor: Gowin Semiconductor
- Official page: https://www.gowinsemi.com/en/support/ip_detail/48/
- Download: https://www.gowinsemi.com/upload/database_doc/2707/document/654312dee1084.zip
- ZIP SHA256: `EC2DA23FD632C54A70410B0BBDF395FDB5B3448DCB02BEBA68136D3890ECA37C`
- Vendor reference target: `GW2A-18C-PBGA484`
- Vendor reference video mode: `1280x720p60`, RGB888, positive HS/VS

The files under `vendor/` were copied from the official ZIP without editing.
Their per-file hashes are recorded after the local build.

## Required ACG-720/GW5AT-60B adaptations

1. `src/gowin_official_video_top_acg720.v`
   - Copied from the official `video_top.v`.
   - Module name made unique.
   - Device-specific `TMDS_rPLL` instance replaced by `gw5at_dvi_pll`.
   - Omitted the GW2A-only `CLKDIV.GSREN` defparam because the GW5AT
     `CLKDIV` primitive does not define it. `RESETN`, `HCLKIN`, `CLKOUT`,
     `CALIB`, and `DIV_MODE=5` remain as in the official reference.
   - Official test-pattern parameters, reset equation, CLKDIV setup, and
     `DVI_TX_Top` connections remain unchanged.
2. `src/gw5at_dvi_pll.v`
   - GW5AT PLLA configuration: 50 MHz input, 371.25 MHz output.
3. `src/acg720_official_dvi.cst`
   - ACG-720 50 MHz clock, reset, LEDs, and HDMI1 TMDS pins only.
4. `src/acg720_official_dvi.sdc`
   - Retains the official reference's 50 MHz input-clock constraint.
   - Adds GW5AT generated-clock descriptions for the 371.25 MHz PLL output
     and 74.25 MHz CLKDIV output so both domains receive static timing analysis.
5. `gowin_official_dvi_acg720.gprj`
   - Target changed to `GW5AT-LV60PG484AC1/I0`.
6. `build_official_dvi_acg720.tcl`
   - Enables `use_sspi_as_gpio` because ACG-720 LEDs on M22/N22 use the
     device's SSPI-multiplexed pins. This option does not alter the DVI path.

This is an official-reference board port, not an unmodified vendor bitstream.
It contains no camera, DDR, OSD, UART, motor, AI, or HDMI InfoFrame logic.

## Build identity

- Build date: `2026-10-14 11:52:12 +08:00`
- Gowin EDA: `V1.9.12.03 (64-bit)`
- Repository HEAD: `3539e369c6349aabd91c29eb70b9f0d81f81ff39`
- Tracked baseline: no tracked modifications before this new untracked project
- Bitstream: `impl/pnr/gowin_official_dvi_acg720_720p60.fs`
- Bitstream bytes: `17312519`
- Bitstream SHA256: `B691FE5D5A4D8E21480813FCDDD80DCD859F81C72766D146E13F7F777804D04F`

## Input hashes

| File | SHA256 |
|---|---|
| `vendor/Readme.txt` | `40F5988061E6A100A74104061A4A1DD325990F4A9FC6F19D61BD9DF867E5D157` |
| `vendor/testpattern.v` | `B1D44A7BD629727B2CA37238AD59F197635CF2837868FB9957C54017D945593A` |
| `vendor/dvi_tx/dvi_tx.v` | `724921AF09CA69DEE9E62FBA5744679D22723A0CFBF1ED4442840192C259E483` |
| `vendor/dvi_tx/dvi_tx.ipc` | `C5FB6377814C4F55877D28B0A4AA3ED8495825C766015BBD838882BA045BE97A` |
| `src/gowin_official_video_top_acg720.v` | `112C36880D1C4F5AB965F9AF68CBDFFFC65F6E622BBCC8D8E486B4AC925A83AE` |
| `src/gw5at_dvi_pll.v` | `A05FB2B450A80E3E6B76B0A8977C26805C19BC13C619207DF90C2978101C9E8F` |
| `src/acg720_official_dvi.cst` | `326ABA2C7ED7330BDDD1E9D234F4056D523E89BC69972B53A261852BADE80854` |
| `src/acg720_official_dvi.sdc` | `29D8D045E9482964F8EE48AF5766BD654D9D1D18FF4F23E20AF6CB6A19F81262` |
| `gowin_official_dvi_acg720.gprj` | `CFABC2D1F9769DBFFA457A6BF299C208134E81CAC5190F100AE1EAADE8309097` |
| `build_official_dvi_acg720.tcl` | `FED6E76647E0C50645761844EA360C36D1AEA781085FD086148A59DCE66A20B1` |

## Build verification

- Synthesis: passed
- Placement and routing: passed
- Bitstream generation: passed
- Analyzed endpoints: 898
- Setup violated endpoints: 0
- Hold violated endpoints: 0
- Minimum pulse width worst reported slack: +3.609 ns
- Pixel-clock constraint: 74.250 MHz
- Pixel-domain reported Fmax: 148.942 MHz
- Serial clock: constrained to 371.250 MHz; no fabric timing paths are
  reported because serialization is implemented by dedicated resources
- TMDS implementation: LVDS25, Bank 10 VCCIO reported as 2.5 V
- Direct-monitor hardware test: passed; the user observed a picture with this
  bitstream.
- RK3588 hardware capture: failed to lock with this bitstream.
- Same-mode control: the user confirmed that the RK3588 HDMI-IN can lock to a
  PC source. The complete `/sys/kernel/debug/hdmirx/status` output has not yet
  been archived, so channel/error-register details remain unverified.

These are finite hardware observations. They do not establish whether the
remaining cause is TMDS electrical margin, clock/serializer startup, or the
RK3588 receiver's handling of a pure-DVI source.
