"""Capture a real GRUB demo with headless QEMU/QMP. Never attaches host disks."""
from pathlib import Path
import json
import os
import socket
import subprocess
import tempfile
import time
import sys

ROOT = Path(__file__).resolve().parents[1]
PROFILE = sys.argv[1] if len(sys.argv) > 1 else "1080p"
qemu = os.environ.get("QEMU_BINARY", "qemu-system-x86_64")
iso = ROOT / "dist" / f"moss-preview-{PROFILE}.iso"
assert iso.exists(), "Build preview ISO first"
with tempfile.TemporaryDirectory(prefix="moss-qmp-") as work:
    sock_path = str(Path(work) / "qmp.sock")
    vga = "VGA,vgamem_mb=128"
    width, height = {"720p": (1280, 720), "1080p": (1920, 1080), "1440p": (2560, 1440), "4k": (3840, 2160)}[PROFILE]
    vga += f",xres={width},yres={height}"
    if os.environ.get("QEMU_VGA_ROM"):
        vga += ",romfile=" + os.environ["QEMU_VGA_ROM"]
    command = [qemu, "-machine", "accel=tcg", "-m", "256", "-display", "none", "-nodefaults",
               "-device", vga, "-drive", f"file={iso},media=cdrom,readonly=on",
               "-boot", "d", "-qmp", f"unix:{sock_path},server=on,wait=off",
               "-serial", "none", "-monitor", "none", "-no-reboot"]
    if os.environ.get("QEMU_DATA_DIR"):
        command += ["-L", os.environ["QEMU_DATA_DIR"]]
    if os.environ.get("QEMU_BIOS"):
        command += ["-bios", os.environ["QEMU_BIOS"]]
    log = (ROOT / "dist" / f"qemu-{PROFILE}.log").open("w")
    vm = subprocess.Popen(command, stdout=log, stderr=log)
    try:
        for _ in range(100):
            if Path(sock_path).exists(): break
            if vm.poll() is not None: raise RuntimeError("QEMU stopped; inspect log")
            time.sleep(0.1)
        sock = socket.socket(socket.AF_UNIX)
        sock.settimeout(10)
        sock.connect(sock_path)
        reader = sock.makefile("r")
        greeting = json.loads(reader.readline())
        assert "QMP" in greeting

        def execute(name, args=None):
            payload = {"execute": name}
            if args is not None: payload["arguments"] = args
            sock.sendall((json.dumps(payload) + "\n").encode())
            while True:
                response = json.loads(reader.readline())
                if "error" in response: raise RuntimeError(response)
                if "return" in response: return response["return"]

        def key(name):
            execute("send-key", {"keys": [{"type": "qcode", "data": name}], "hold-time": 100})
            time.sleep(0.5)

        def capture(suffix):
            path = ROOT / "docs" / f"preview-{PROFILE}-{suffix}.ppm"
            execute("screendump", {"filename": str(path)})
            print(path, flush=True)

        execute("qmp_capabilities")
        time.sleep(5)
        capture("ubuntu")
        time.sleep(2)
        capture("countdown")
        key("down")
        key("down")
        capture("windows")
        key("up")
        key("ret")
        capture("submenu")
        for _ in range(5): key("down")
        capture("scroll")
        key("esc")
        key("c")
        capture("terminal")
        key("esc")
        execute("quit")
        vm.wait(timeout=10)
    finally:
        if vm.poll() is None:
            vm.terminate()
            vm.wait(timeout=10)
        log.close()
