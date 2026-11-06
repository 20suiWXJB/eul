#!/usr/bin/env python3
"""Run hardware-independent checks against the production Swift sources.

Pass --hardware to additionally probe this Mac's sensors (read only).
"""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import uuid

root = Path(__file__).resolve().parents[1]
sources = [
    "SharedLibrary/Schema/SmcStruct.swift",
    "SharedLibrary/Schema/SharedEntry.swift",
    "SharedLibrary/Schema/SharedWidgetEntry.swift",
    "SharedLibrary/Schema/StandardProvider.swift",
    "SharedLibrary/Schema/MemoryEntry.swift",
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
suite_name = "com.gaosun.eul.regressions." + uuid.uuid4().hex
parts = [stub, f'let regressionSuiteName = "{suite_name}"']
for name in sources:
    source = (root / name).read_text()
    if name == "SharedLibrary/Utilities/Container.swift":
        source = source.replace('"com.gaosun.eul.widget-data"', f'"{suite_name}"')
    parts.append(source.replace("import SharedLibrary\n", ""))
parts.append((root / "Tests/RegressionChecks.swift").read_text())
env = dict(os.environ, PATH="/usr/bin:/bin:/usr/sbin:/sbin")
env["SDKROOT"] = subprocess.check_output(
    ["/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-path"], env=env, text=True).strip()
with tempfile.TemporaryDirectory(prefix="eul-regressions-") as directory:
    script = Path(directory) / "main.swift"
    script.write_text("\n".join(parts))
    executable = Path(directory) / "regressions"
    subprocess.run(["/usr/bin/xcrun", "swiftc", "-module-cache-path", str(Path(directory) / "cache"),
                    "-D", "DEBUG", str(script), "-o", str(executable)],
                   env=env, check=True)
    subprocess.run([str(executable), *sys.argv[1:]],
                   env=env, check=True)
