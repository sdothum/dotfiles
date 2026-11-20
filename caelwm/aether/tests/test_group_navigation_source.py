from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
GROUP = (ROOT / "wm/group.nim").read_text()
AETHER = (ROOT / "aether.nim").read_text()
GROUP_ID = (ROOT / "wm/group_id.nim").read_text()


def procedure(name: str) -> str:
    match = re.search(
        rf"proc {name}\*\([^\n]*\).*?\n(?=proc |#|$)",
        GROUP,
        re.S,
    )
    if match is None:
        raise AssertionError(f"missing group.{name} procedure")
    return match.group(0)


class NavigationSourceContract(unittest.TestCase):
    def test_both_operations_are_read_only_destination_queries(self):
        for name in ("next", "previous"):
            body = procedure(name)
            self.assertIn("requireNoArgs", body)
            self.assertIn("count()", body)
            self.assertIn("currentLiveId()", body)
            self.assertIn("relativeGroupId", body)
            for forbidden in (
                "focus(", "activateGroup(", "groupTarget(",
                "window.group", "teleport", "layouts.", "setCurrentGroup",
            ):
                self.assertNotIn(forbidden, body)

    def test_dispatch_only_prints_the_destination(self):
        self.assertIn('of "next":\n    echo next(rest)', GROUP)
        self.assertIn('of "previous":\n    echo previous(rest)', GROUP)
        self.assertIn("except ZephyrError as error:", AETHER)
        self.assertIn("stderr.writeLine(error.msg)\n  quit(1)", AETHER)

    def test_navigation_helper_is_pure_number_arithmetic(self):
        self.assertIn("proc relativeGroupId*", GROUP_ID)
        self.assertIn("raiseZephyrError", GROUP_ID)
        for forbidden in ("native_ipc", "window", "focus(", "activateGroup", "GROUP", "WME"):
            self.assertNotIn(forbidden, GROUP_ID)

    def test_legacy_group_get_alias_is_not_added(self):
        self.assertNotIn('of "get":', GROUP)
