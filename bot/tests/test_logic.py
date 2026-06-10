import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from detector import detect_transition  # noqa: E402
from fsolar import parse_snapshot  # noqa: E402


def test_first_snapshot_is_baseline():
    assert detect_transition(None, True) is None
    assert detect_transition(None, False) is None


def test_no_change():
    assert detect_transition(True, True) is None
    assert detect_transition(False, False) is None


def test_grid_lost_and_restored():
    assert detect_transition(True, False) == "gridLost"
    assert detect_transition(False, True) == "gridRestored"


def test_parse_grid_on():
    s = parse_snapshot({
        "acRInVolt": "218.3", "acRInFreq": "49.98", "workModeStr": "Line Mode",
        "emsSoc": "99", "emsVoltage": "54", "emsCurrent": "9", "dataTime": 1780215900000,
    })
    assert s.is_present is True
    assert s.voltage == 218.3
    assert s.soc == 99
    assert s.work_mode == "Line Mode"


def test_parse_grid_off():
    s = parse_snapshot({"acRInVolt": "0", "workModeStr": "Battery Mode", "emsSoc": "80"})
    assert s.is_present is False
    assert s.soc == 80


def test_parse_soc_fallback_to_avg():
    s = parse_snapshot({"acRInVolt": "230", "emsSocAvg": "55"})
    assert s.soc == 55
