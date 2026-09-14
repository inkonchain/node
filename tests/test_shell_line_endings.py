"""Run with: python3 -m unittest discover -s tests -v

Uses real repository shell files and Git checkout conversion in temporary repos.
Set GIT_BINARY to also test Git for Windows from WSL. No global config changes.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
GIT = os.environ.get("GIT_BINARY", "git")
WINDOWS_GIT = GIT.lower().endswith(".exe")


class ShellLineEndingTests(unittest.TestCase):
    def check_checkout(self, autocrlf):
        scripts = sorted(REPO.glob("scripts/*.sh")) + [REPO / "progress.sh"]
        self.assertTrue(all(path.is_file() for path in scripts))
        with tempfile.TemporaryDirectory(prefix="shell-eol-") as tmp:
            root = Path(tmp)
            template = root / "empty-template"
            template.mkdir()

            def git_path(path):
                if WINDOWS_GIT:
                    return subprocess.check_output(
                        ["wslpath", "-w", str(path)], text=True
                    ).strip()
                return str(path)

            target = git_path(root)

            def git(*args):
                command = [
                    GIT, "-c", "safe.directory=" + target,
                    "-c", "core.attributesFile=" + ("NUL" if WINDOWS_GIT else "/dev/null"),
                    "-c", "core.safecrlf=false", "-C", target, *args,
                ]
                result = subprocess.run(command, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                return result.stdout

            git("init", "--quiet", "--template=" + git_path(template))
            paths = []
            for source in scripts:
                relative = source.relative_to(REPO)
                dest = root / relative
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, dest)
                paths.append(relative.as_posix())
            if (REPO / ".gitattributes").exists():
                shutil.copyfile(REPO / ".gitattributes", root / ".gitattributes")
                paths.append(".gitattributes")
            git("-c", "core.autocrlf=false", "add", "--", *paths)
            # Force materialization from the index rather than a stat-cache no-op.
            for source in scripts:
                (root / source.relative_to(REPO)).unlink()
            git("-c", "core.autocrlf=" + autocrlf, "checkout-index", "--all", "--force")
            evidence = git("ls-files", "--eol")
            for source in scripts:
                with self.subTest(script=str(source.relative_to(REPO))):
                    self.assertEqual(
                        (root / source.relative_to(REPO)).read_bytes(),
                        source.read_bytes(), evidence,
                    )
                    self.assertNotIn(b"\r\n", (root / source.relative_to(REPO)).read_bytes())

    def test_autocrlf_true_preserves_shell_lf(self):
        self.check_checkout("true")

    def test_autocrlf_false_preserves_shell_lf(self):
        self.check_checkout("false")

    def test_autocrlf_input_preserves_shell_lf(self):
        self.check_checkout("input")


if __name__ == "__main__":
    unittest.main()
