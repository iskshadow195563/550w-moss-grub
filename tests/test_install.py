"""Exercise install/rollback/uninstall against an isolated filesystem and generator.

Run as root only inside a disposable Linux environment. No host /boot or /etc
is accessed: test copies replace the explicit SYS_ROOT and kernel-info path.
GRUB_SCRIPT_CHECK may point to an extracted real GRUB syntax checker.
"""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
BASE_CFG = '''menuentry 'Ubuntu' --class ubuntu {
    linux /vmlinuz root=UUID=fixture ro
    initrd /initrd.img
}
menuentry 'Windows Boot Manager' --class windows {
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
'''


class TransactionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="moss-transaction-")
        self.base = Path(self.temp.name)
        self.root = self.base / "system"
        self.package = self.base / "package"
        self.package.mkdir()
        (self.package / "theme").symlink_to(PROJECT / "theme", target_is_directory=True)
        for rel in ("boot/grub", "etc/default/grub.d", "var/tmp", "var/lib", "run/lock", "proc/sys/kernel"):
            (self.root / rel).mkdir(parents=True)
        self.original = self.root / "boot/grub/grub.cfg"
        self.original.write_text(BASE_CFG)
        self.defaults = self.root / "etc/default/grub"
        self.defaults.write_text('GRUB_DEFAULT=saved\nGRUB_SAVEDEFAULT=true\nGRUB_TIMEOUT=5\n')
        (self.root / "proc/sys/kernel/osrelease").write_text("6.8-test-linux")
        self.theme = self.root / "boot/grub/themes/550w-moss"
        self.dropin = self.root / "etc/default/grub.d/zzzz-550w-moss.cfg"
        self.state = self.root / "var/lib/550w-moss"
        for name in ("install.sh", "uninstall.sh"):
            script = (PROJECT / name).read_text()
            script = script.replace('readonly SYS_ROOT=""', f'readonly SYS_ROOT="{self.root}"')
            script = script.replace("/proc/sys/kernel/osrelease", str(self.root / "proc/sys/kernel/osrelease"))
            (self.package / name).write_text(script)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.command("grub-mkconfig", '''#!/usr/bin/env python3
# Ubuntu sources /etc/default/grub.d/*.cfg
import os, pathlib, sys
if os.environ.get('CASE') == 'generation-fail': sys.exit(7)
data = os.environ['FIXTURE_CFG']
if os.environ.get('CASE') == 'syntax-fail': data = "menuentry 'broken' {\\n"
if os.environ.get('CASE') == 'windows-lost': data = data.split("menuentry 'Windows")[0]
if os.environ.get('CASE') == 'linux-lost': data = "menuentry 'Windows Boot Manager' { chainloader /bootmgfw.efi }\\n"
if pathlib.Path(os.environ['DROPIN']).exists() and os.environ.get('CASE') != 'theme-lost':
    data = 'set theme=/boot/grub/themes/550w-moss/theme.txt\\n' + data
if os.environ.get('CASE') == 'separate-boot': data = data.replace('/boot/grub/', '/grub/')
pathlib.Path(sys.argv[2]).write_text(data)
''')
        checker = os.environ.get("GRUB_SCRIPT_CHECK", "grub-script-check")
        self.command("grub-script-check", f'#!/usr/bin/env bash\nexec "{checker}" "$@"\n')
        self.env = os.environ.copy()
        self.env.update(PATH=f"{self.bin}:{self.env['PATH']}", FIXTURE_CFG=BASE_CFG, DROPIN=str(self.dropin))

    def command(self, name, code):
        path = self.bin / name
        path.write_text(code)
        path.chmod(0o755)

    def run_script(self, name="install.sh", args=(), case="", success=True):
        result = subprocess.run(["bash", str(self.package / name), *args], env={**self.env, "CASE": case}, text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def assert_pristine(self):
        self.assertEqual(self.original.read_text(), BASE_CFG)
        self.assertFalse(self.dropin.exists())
        self.assertFalse(self.theme.exists())
        self.assertFalse(self.state.exists())
        self.assertFalse(list((self.root / "boot/grub").glob(".moss-*.cfg.*")))

    def test_install_preserves_defaults_and_entries(self):
        before = self.defaults.read_bytes()
        self.run_script()
        self.assertEqual(self.defaults.read_bytes(), before)
        self.assertEqual((self.state / "grub.cfg.before-install").read_text(), BASE_CFG)
        self.assertIn("Windows Boot Manager", self.original.read_text())
        self.assertIn("linux /vmlinuz", self.original.read_text())
        self.assertEqual((self.theme / "theme.txt").read_bytes(), (PROJECT / "theme/theme-1080p.txt").read_bytes())
        self.assertIn("GRUB_TIMEOUT=8", self.dropin.read_text())

    def test_dry_run_makes_no_changes(self):
        self.run_script(args=("--dry-run", "--resolution", "4k"))
        self.assert_pristine()

    def test_bad_args_make_no_changes(self):
        for args in (("--timeout", "0"), ("--timeout", "5;reboot"), ("--resolution", "weird"), ("--timeout",)):
            self.run_script(args=args, success=False)
            self.assert_pristine()

    def test_generation_failure_rolls_back(self):
        self.run_script(case="generation-fail", success=False)
        self.assert_pristine()

    def test_separate_boot_partition_path_is_supported(self):
        self.run_script(case="separate-boot")
        self.assertIn("set theme=/grub/themes/550w-moss/theme.txt", self.original.read_text())

    def test_missing_theme_rolls_back(self):
        self.run_script(case="theme-lost", success=False)
        self.assert_pristine()

    def test_invalid_grub_config_rolls_back(self):
        self.run_script(case="syntax-fail", success=False)
        self.assert_pristine()

    def test_lost_windows_entry_rolls_back(self):
        self.run_script(case="windows-lost", success=False)
        self.assert_pristine()

    def test_lost_linux_entry_rolls_back(self):
        self.run_script(case="linux-lost", success=False)
        self.assert_pristine()

    def test_refuses_unmanaged_theme(self):
        self.theme.mkdir(parents=True)
        sentinel = self.theme / "keep.txt"
        sentinel.write_text("existing theme")
        self.run_script(success=False)
        self.assertEqual(sentinel.read_text(), "existing theme")
        self.assertFalse(self.dropin.exists())

    def test_upgrade_failure_restores_previous_install(self):
        self.run_script()
        before_dropin = self.dropin.read_bytes()
        before_cfg = self.original.read_bytes()
        before_theme = (self.theme / "theme.txt").read_bytes()
        self.run_script(args=("--resolution", "4k"), case="generation-fail", success=False)
        self.assertEqual(before_dropin, self.dropin.read_bytes())
        self.assertEqual(before_cfg, self.original.read_bytes())
        self.assertEqual(before_theme, (self.theme / "theme.txt").read_bytes())

    def test_upgrade_uses_requested_profile(self):
        self.run_script()
        self.run_script(args=("--resolution", "4k", "--timeout", "-1"))
        self.assertIn("GRUB_TIMEOUT=-1", self.dropin.read_text())
        self.assertEqual((self.theme / "theme.txt").read_bytes(), (PROJECT / "theme/theme-4k.txt").read_bytes())
        self.assertEqual((self.state / "grub.cfg.before-install").read_text(), BASE_CFG)

    def test_uninstall_keeps_current_kernels(self):
        self.run_script()
        self.env["FIXTURE_CFG"] = BASE_CFG.replace("/vmlinuz", "/vmlinuz-new")
        self.run_script("uninstall.sh")
        self.assertIn("/vmlinuz-new", self.original.read_text())
        self.assertFalse(self.theme.exists())
        self.assertFalse(self.dropin.exists())
        self.assertTrue((self.state / "grub.cfg.before-install").exists())

    def test_failed_uninstall_restores_theme(self):
        self.run_script()
        before_dropin = self.dropin.read_bytes()
        before_cfg = self.original.read_bytes()
        self.run_script("uninstall.sh", case="windows-lost", success=False)
        self.assertEqual(before_dropin, self.dropin.read_bytes())
        self.assertEqual(before_cfg, self.original.read_bytes())
        self.assertTrue(self.theme.exists())

    def tearDown(self):
        self.temp.cleanup()


if __name__ == "__main__":
    if os.geteuid() != 0:
        raise SystemExit("Run these isolated fixture tests as root in a disposable Linux environment.")
    unittest.main(verbosity=2)
