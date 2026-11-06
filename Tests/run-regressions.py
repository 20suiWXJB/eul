#!/usr/bin/env python3
"""Run hardware-independent checks against the production Swift sources.

Pass --hardware to additionally probe this Mac's sensors (read only).
"""
from pathlib import Path
import os
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
sources = [
    "SharedLibrary/Schema/SmcStruct.swift",
    "SharedLibrary/Schema/SharedEntry.swift",
    "SharedLibrary/Utilities/Container.swift",
    "eul/Utilities/SMC.swift",
    "eul/Schema/TemperatureData.swift",
    "eul/Extension/String.swift",
    "eul/Utilities/IOHelper.swift",
    "eul/Schema/SystemProfiler.swift",
    "eul/Utilities/Shell.swift",
    "eul/Utilities/Print.swift",
    "eul/Utilities/GPU.swift",
]
# GPU.getInfo depends on the app singleton. The parser/matcher and SMC code
# remain unmodified; UI state is the only stand-in in this isolated executable.
stub = """
class SmcControl {
    static let shared = SmcControl()
    var tempUnit: TemperatureUnit = .celius
    var gpuProximityTemperature: Double? = nil
}
"""
parts = [stub]
for name in sources:
    source = (root / name).read_text()
    parts.append(source.replace("import SharedLibrary\n", ""))
parts.append((root / "Tests/RegressionChecks.swift").read_text())
env = dict(os.environ, PATH="/usr/bin:/bin:/usr/sbin:/sbin")
env["SDKROOT"] = subprocess.check_output(
    ["/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-path"], env=env, text=True).strip()
with tempfile.TemporaryDirectory(prefix="eul-regressions-") as directory:
    script = Path(directory) / "main.swift"
    script.write_text("\n".join(parts))
    subprocess.run(["/usr/bin/xcrun", "swift", "-module-cache-path", str(Path(directory) / "cache"),
                    "-D", "DEBUG", str(script), *sys.argv[1:]],
                   env=env, check=True)
