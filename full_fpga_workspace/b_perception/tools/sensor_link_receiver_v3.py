#!/usr/bin/env python3
"""Receive FPGA sensor telemetry v3 from a Linux USB-to-TTL device."""

from __future__ import annotations

import argparse
import os
import struct
import time

try:
    import termios
except ImportError:  # Allows protocol unit tests on non-Linux development hosts.
    termios = None

SYNC = b"\xA5\x5A"
VERSION = 1
TYPE_SENSOR = 0x10
PAYLOAD_LEN = 21
FRAME_LEN = 28


def crc16_ccitt_false(data: bytes) -> int:
    crc = 0xFFFF
    for value in data:
        crc ^= value << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def configure_serial(fd: int) -> None:
    if termios is None:
        raise RuntimeError("this receiver must run on Linux")
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0
    attrs[1] = 0
    attrs[2] = termios.CLOCAL | termios.CREAD | termios.CS8
    attrs[3] = 0
    attrs[4] = termios.B115200
    attrs[5] = termios.B115200
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 1
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    termios.tcflush(fd, termios.TCIFLUSH)


def extract_frames(buffer: bytearray):
    while True:
        start = buffer.find(SYNC)
        if start < 0:
            if buffer[-1:] == SYNC[:1]:
                del buffer[:-1]
            else:
                buffer.clear()
            return
        if start:
            del buffer[:start]
        if len(buffer) < 5:
            return
        payload_len = buffer[4]
        total = 7 + payload_len
        if payload_len > 64:
            del buffer[0]
            continue
        if len(buffer) < total:
            return
        candidate = bytes(buffer[:total])
        received_crc = candidate[-2] | candidate[-1] << 8
        calculated_crc = crc16_ccitt_false(candidate[2:-2])
        if received_crc != calculated_crc:
            del buffer[0]
            continue
        del buffer[:total]
        yield candidate


def decode_sensor_frame(frame: bytes) -> dict[str, int | float | bool]:
    if len(frame) != FRAME_LEN or frame[2] != VERSION or frame[3] != TYPE_SENSOR or frame[4] != PAYLOAD_LEN:
        raise ValueError("unsupported telemetry frame")
    seq, status, distance, strength, roll, pitch, yaw, tof_errors, imu_errors, uptime_ms = struct.unpack_from(
        "<HBHHhhhHHI", frame, 5
    )
    return {
        "seq": seq,
        "status": status,
        "tof_seen": bool(status & 0x01),
        "imu_seen": bool(status & 0x02),
        "tof_fresh": bool(status & 0x04),
        "imu_fresh": bool(status & 0x08),
        "tof_error": bool(status & 0x10),
        "imu_error": bool(status & 0x20),
        "distance_mm": distance,
        "strength": strength,
        "roll_deg": roll / 100.0,
        "pitch_deg": pitch / 100.0,
        "yaw_deg": yaw / 100.0,
        "tof_errors": tof_errors,
        "imu_errors": imu_errors,
        "uptime_ms": uptime_ms,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Receive FPGA sensor telemetry v3")
    parser.add_argument("device", nargs="?", default="/dev/ttyUSB0")
    args = parser.parse_args()

    if termios is None:
        raise SystemExit("this receiver must run on Linux")
    fd = os.open(args.device, os.O_RDONLY | os.O_NOCTTY | os.O_NONBLOCK)
    configure_serial(fd)
    buffer = bytearray()
    last_frame = time.monotonic()
    print(f"listening on {args.device} at 115200 8N1")

    try:
        while True:
            try:
                chunk = os.read(fd, 4096)
            except BlockingIOError:
                chunk = b""
            if chunk:
                buffer.extend(chunk)
                for frame in extract_frames(buffer):
                    data = decode_sensor_frame(frame)
                    last_frame = time.monotonic()
                    print(
                        f"seq={data['seq']:05d} status=0x{data['status']:02X} "
                        f"distance={data['distance_mm']}mm strength={data['strength']} "
                        f"roll={data['roll_deg']:.2f}° pitch={data['pitch_deg']:.2f}° "
                        f"yaw={data['yaw_deg']:.2f}° tof_err={data['tof_errors']} "
                        f"imu_err={data['imu_errors']} uptime={data['uptime_ms'] / 1000:.3f}s"
                    )
            elif time.monotonic() - last_frame > 2.0:
                print("warning: no valid CRC frame received for 2 seconds")
                last_frame = time.monotonic()
            time.sleep(0.01)
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()
