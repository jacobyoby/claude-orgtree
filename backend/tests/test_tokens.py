"""Token-store permissions and atomic replacement checks.

    python backend/tests/test_tokens.py
"""
from __future__ import annotations

import os
import stat
import sys
import tempfile

os.environ["ORGTREE_DATA"] = tempfile.mkdtemp(prefix="orgtree-tokens-")
os.makedirs(os.environ["ORGTREE_DATA"], exist_ok=True)
with open(os.path.join(os.environ["ORGTREE_DATA"], "defaults.json"), "w",
          encoding="utf-8") as f:
    f.write('{"net_hub_address": "http://127.0.0.1:9"}')
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from orgtree import tokens  # noqa: E402

CHECKS = 0


def check(label: str, condition: bool) -> None:
    global CHECKS
    CHECKS += 1
    if not condition:
        raise AssertionError(label)
    print(f"ok {CHECKS:2d}  {label}")


def mode(path: str) -> int:
    return stat.S_IMODE(os.stat(path).st_mode)


def main() -> int:
    if os.name == "nt":
        print("SKIP Windows has no POSIX mode assertion")
        return 0

    tokens.put("account-1", "fabricated-token")
    check("put creates an owner-only token file", mode(tokens.tokens_path()) == 0o600)
    check("put persists the token", tokens.get("account-1") == "fabricated-token")

    os.chmod(tokens.tokens_path(), 0o644)
    tokens.put("account-2", "another-fabricated-token")
    check("put tightens an existing wider file on replacement",
          mode(tokens.tokens_path()) == 0o600)

    os.chmod(tokens.tokens_path(), 0o644)
    check("forget removes a stored token", tokens.forget("account-1"))
    check("forget also tightens the replacement", mode(tokens.tokens_path()) == 0o600)
    print(f"ALL {CHECKS} CHECKS PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
