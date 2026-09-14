"""Offline wrapper regression tests (Linux user/network namespaces required).

Run: python3 -m unittest discover -s tests -v
The real entrypoint runs unchanged under /bin/sh in a disposable chroot.
Only geth is stubbed: these tests verify argv, not binary flag support.
No Docker, RPC access, existing datadir, or host /shared directory is used.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class OpGethWebSocketTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        def require_tool(name):
            tool = shutil.which(name)
            if tool is None:
                raise unittest.SkipTest("Required Linux tool unavailable: " + name)
            return tool

        cls.unshare = require_tool("unshare")
        cls.chroot = require_tool("chroot")
        cls.ldd = require_tool("ldd")
        probe = subprocess.run(
            [cls.unshare, "--user", "--map-root-user", "--net", "/bin/true"],
            capture_output=True, text=True, timeout=10,
        )
        if probe.returncode:
            raise unittest.SkipTest("User/network namespaces unavailable: " + probe.stderr)

    def wrapper_args(self, node_type="full", extra_args=()):
        with tempfile.TemporaryDirectory(prefix="op-geth-wrapper-test-") as tmp:
            root = Path(tmp)
            for directory in ("bin", "scripts", "shared", "geth"):
                (root / directory).mkdir()
            shutil.copyfile("/bin/sh", root / "bin/sh")
            (root / "bin/sh").chmod(0o755)
            # Copy the host shell's loader and libraries, not host configuration.
            deps = subprocess.run(
                [self.ldd, "/bin/sh"], check=True, capture_output=True, text=True,
            )
            for dependency in set(re.findall(r"/[^\s()]+", deps.stdout)):
                dest = root / dependency.lstrip("/")
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(dependency, dest)
                dest.chmod(0o755)
            shutil.copyfile(REPO / "scripts/start-op-geth.sh", root / "scripts/start-op-geth.sh")
            (root / "shared/initialized.txt").touch()
            stub = root / "bin/geth"
            stub.write_text("#!/bin/sh\nprintf '%s\\n' \"$@\"\n")
            stub.chmod(0o755)
            env = {
                "PATH": "/bin", "LC_ALL": "C", "NETWORK_NAME": "ink-sepolia",
                "NODE_TYPE": node_type, "BEDROCK_DATADIR": "/geth",
                "BEDROCK_SEQUENCER_HTTP": "http://sequencer.invalid",
                "PORT__OP_GETH_P2P": "49393", "EXTENDED_ARG": "",
                "OVERRIDE_HOLOCENE": "",
            }
            result = subprocess.run(
                [self.unshare, "--user", "--map-root-user", "--net", self.chroot,
                 str(root), "/bin/sh", "/scripts/start-op-geth.sh", *extra_args],
                env=env, cwd="/", capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout.splitlines()[1:]  # Skip the init-wait message.

    def assert_websocket_listener(self, args):
        self.assertIn("--ws", args)
        self.assertIn("--ws.addr=0.0.0.0", args)
        self.assertIn("--ws.port=8546", args)

    def test_full_node_enables_published_websocket_listener(self):
        args = self.wrapper_args()
        self.assert_websocket_listener(args)
        self.assertIn("--http.port=8545", args)
        self.assertIn("--gcmode=full", args)

    def test_archive_node_enables_same_websocket_listener(self):
        args = self.wrapper_args(node_type="archive")
        self.assert_websocket_listener(args)
        self.assertIn("--gcmode=archive", args)
        self.assertIn("--port=49393", args)

    def test_explicit_arguments_remain_after_wrapper_defaults(self):
        args = self.wrapper_args(extra_args=("--ws=false",))
        self.assert_websocket_listener(args)
        self.assertEqual(args[-1], "--ws=false")


if __name__ == "__main__":
    unittest.main()
