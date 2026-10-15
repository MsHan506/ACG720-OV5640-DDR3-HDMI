# CLKDIV / OSER10 audit - 2026-10-10

> Follow-up: the read-only audit below is a historical stage, not the latest build.
> Its generated-clock and stale-full-image findings were addressed in the subsequent
> implementation described in `C:\chatgpt\fpga\deliverables\hdmi_fix_20261010\CHECKS.md`.
> Production HDL/SDC was modified and both images rebuilt with source snapshots.
> `serializer_audit_postfix.log` re-runs the unchanged serializer behavior after
> the explanatory comment update: 25 startup scenarios, 7,108 complete three-lane
> words, zero failures. Full-engine STA and physical RK3588 acceptance remain open.

## Scope and acceptance

Read-only inspection of the production transmitter sources, synthesized netlists,
and existing implementation reports. Added a standalone ModelSim testbench only;
no production RTL, SDC, project, or FPGA image was changed or rebuilt by this audit.

Checks requested: FCLK/PCLK frequency and phase relationship; common clocks and
startup for the four lanes; complete, consecutive 10-bit words; repeatability after
downloads and physical cold starts. Physical board acceptance is still FAILED by
the user's reported RK3588 lock failures. No physical cold starts were performed
by this audit.

## Official requirements and source evidence

Gowin UG304, OSER10: ten parallel input bits, serial DDR output; PCLK is normally
obtained by dividing FCLK by five. OSER10 RESET is active-high asynchronous.
Gowin UG306, CLKDIV: dedicated divided clock with an input-related phase; RESETN
is active-low asynchronous and CALIB adjusts phase.

Official documents:
- https://cdn.gowinsemi.com.cn/UG304E.pdf
- https://cdn.gowinsemi.com.cn/UG306E.pdf

Local vendor simulation library used:
`C:/Gowin/Gowin_V1.9.12.03_x64/IDE/simlib/gw5a/prim_sim.v`

Current serializer:
`C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/src/true_hdmi/serializer_gowin.sv`

- All four OSER10 instances share PCLK and FCLK, and all RESET inputs are zero.
- Each data input D0..D9 maps to the corresponding bit of its registered pixel word.
- The clock word is D0..D4=0, D5..D9=1.
- CLKDIV RESETN=1, CALIB=1, DIV_MODE="5".
- Thus startup relies on configuration GSR; the lock wait gates upstream video
  state, not the four serializers or their forwarded clock.
- The register transfer structure contains no fabric, independently running
  serializer counter that could splice words between these four lanes.
- This wiring alone does not prove physical GSR release timing, PLL startup,
  jitter, or inter-lane skew.

## Functional simulation result (not physical measurements)

Simulator: ModelSim Intel FPGA Starter Edition 2020.1.
Testbench: `tb_serializer_audit.sv` in this directory.
Final log: `serializer_audit_qualified_start.log` in this directory.

The actual current serializer module was compiled with Gowin's GSR, CLKDIV and
OSER10 functional models. Three changing 10-bit word streams were sent. An
independent scoreboard reconstructed serial words using the forwarded clock's
falling edge and compared them with the parallel input history. It checked
10 samples per word, bit order, consecutive input indices, simultaneous three-lane
agreement, forwarded clock pattern, and the PCLK/FCLK rising-edge relationship.

25 startup scenarios varied clock-start and GSR-release times, including GSR
release before the first FCLK edge and release while the clock was running.

Final simulator result:

```text
RESULT trials=25 complete_3lane_words=7108 failures=0 first_latency=3
MODEL_CLOCK period_ps=13470 high_ps=8082 low_ps=5388 FCLK_period_ps=2694
```

7108 is a count of three-lane word groups, not the number of physical frames or
boots. The source clock half-period was rounded to 1347 ps for this test; this
test verifies the 5:1 ratio and word transfer, not an exact measured 74.25 MHz.
After the initial pipeline fill (12 PCLK captures), no missing, duplicated,
spliced, reversed or inter-lane-misaligned words were detected in these finite
tests. Early unqualified output is excluded; production diagnostics wait about
14 ms before releasing their video raster. The complete production design uses
a different, approximately 1024-pixel-cycle lock delay.

An earlier unqualified test log (`serializer_audit.log`) contains startup checker
failures after adding GSR-before-clock cases. The final test explicitly resets
its external scoreboard on GSR and evaluates valid output after pipeline fill.
The earlier log is not presented as a passing test or a physical fault capture.

Not covered: analog PLL lock/ramp, metastability, jitter, physical skew, routed
timing simulation with SDF, actual HDMI receiver acceptance, HDMI packet correctness,
camera/DDR interaction, re-downloads or power cycling of the board.

## Confirmed constraints / artifact issues

1. Diagnostic SDC files create FCLK and PCLK as separate base clocks, rather than
   expressing PCLK's generated /5 relationship. Their reports list both as Base
   clocks with blank Master/Source. A zero setup/hold count in those reports is
   not sufficient evidence that the required serializer clock relationship was
   verified by STA. Generated-clock constraints and waveforms need review.

2. The diagnostic constraints declare a 50% PCLK duty cycle by default. The
   vendor functional CLKDIV /5 model produced 60% high / 40% low in the audit.
   This is a simulation-model observation, not a scope measurement. It is not
   by itself proof of an invalid OSER10 design, but the constraint waveform and
   actual generated-clock behavior cannot simply be assumed identical.

3. Existing complete image `b_full_rk3588_sync_fixed.fs` was built on October 9.
   Its companion synthesized netlist has clock D0..D4=1, D5..D9=0, opposite to
   current source and the October 10 diagnostic images. Hence testing current
   source does not establish the behavior of that complete image. The different
   clock patterns differ by a half-pixel forwarded-clock phase; this audit has
   not proved that phase difference is the cause of RK3588 no-lock.

4. The complete image's report has 174 setup and 39 hold violated endpoints.
   The first listed setup violation is Disp_VS to DDR rd_load_d0, -4.383 ns.
   Additional paths include 50 MHz sensor/OSD to pixel-domain synchronizer first
   stages. The first listed hold violation is DDR initialization to wloadn_1,
   -1.285 ns. These need a CDC/constraint and reset review; no blanket false-path
   exception should be added merely to suppress them. They are not evidence
   that the camera/DDR-free diagnostic's no-lock has the same cause.

5. The complete image's report automatically recognizes PLL and CLKDIV clocks
   as Generated, including 371.25 -> 74.25 MHz. Thus its constraints situation
   differs from the manually declared base clocks in diagnostic reports.

Relevant evidence files (project root is the directory two levels above here):

- `impl/gwsynthesis/b_full_rk3588_sync_fixed.vg`, clock OSER10 around line 86047
- `impl/pnr/b_full_rk3588_sync_fixed_tr_content.html`
- `impl/gwsynthesis/rk3588_custom_tmds_dvi_720p60.vg`
- `impl/pnr/rk3588_custom_tmds_dvi_720p60_tr_content.html`
- `src/rk3588_custom_dvi_link_test.sdc`
- `src/rk3588_hdmi_link_test.sdc`
- `src/rk3588_gowin_dvi_link_test.sdc`

Image SHA256 values read in this audit:

```text
b_full_rk3588_sync_fixed.fs
88F9E4093E3B765B6078BA83CDDD885B52FC69B8925DC52DF4FF2DD324B9B0AE

rk3588_custom_tmds_dvi_720p60.fs
D805ACD8BC860CDE58674D92D556FCC6CFFEC2C9066CDE402CCBBBE60BE85CAB
```

## Reproduce simulation

Run from this directory in PowerShell:

```powershell
& 'C:/intelFPGA/20.1/modelsim_ase/win32aloem/vlib.exe' work
& 'C:/intelFPGA/20.1/modelsim_ase/win32aloem/vlog.exe' -sv `
  'C:/Gowin/Gowin_V1.9.12.03_x64/IDE/simlib/gw5a/prim_sim.v' `
  '../../src/true_hdmi/serializer_gowin.sv' tb_serializer_audit.sv
& 'C:/intelFPGA/20.1/modelsim_ase/win32aloem/vsim.exe' -c `
  -l serializer_audit_qualified_start.log work.tb_serializer_audit `
  -do 'run -all; quit -f'
```

## Remaining board acceptance

Use one fixed image, record its SHA256 and source snapshot, and identify its
intended HDMI or DVI mode. At least 10 re-downloads and 10 complete power-off/on
trials should be recorded separately. For each, keep the physical configuration
constant, check PLL/drop indicators, and capture 60 seconds of receiver logs plus
10 queries. These suggested trial counts are finite acceptance tests, not a
guarantee for all future starts.

For a true-HDMI 720p60 image every trial must show 1280x720 progressive near
74.25 MHz, with no signal loss or AVI timeout. A DVI-only image can demonstrate
TMDS physical lock without AVI; query failure from missing AVI must be separated
from PHY no-lock using kernel logs. Do not count one transient lock as a pass.

If failed, acquire PLL LOCK, reference/high-speed/divided clocks, video reset,
and the encoded 10-bit words around the failure. Pixel-domain ILA cannot resolve
742.5 Mbps serial output; serial word alignment and inter-lane skew require a
suitable external measurement or receiver decoder.
