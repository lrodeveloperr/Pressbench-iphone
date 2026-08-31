#!/usr/bin/env python3
"""Build the offline PressBench preset catalog for every supported locale.

The checked-in output is the runtime artifact. This script is only a maintainer
tool; the iOS app never makes translation or network requests.
"""

from pathlib import Path
import json
import re
import sys
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = ROOT / "prefill_localization_source.json"
OVERRIDES_PATH = ROOT / "prefill_translation_overrides.json"
OUTPUT_PATH = ROOT / "PressBench/Resources/PrefillLocalizations.json"

LANGUAGES = [
    "en", "es", "pt", "fr", "de", "it", "nl", "pl", "tr", "ro", "cs", "uk", "ru", "ar",
    "zh", "ja", "ko", "hi", "ur", "bn", "vi", "id", "th", "fil", "ms", "fi", "sv", "da",
    "nb", "el", "he"
]
OVERRIDES = ["zh-Hant"]
TRANSLATION_CODES = {
    "zh": "zh-CN",
    "zh-Hant": "zh-TW",
    "nb": "no",
}
GROUP_ORDER = [
    "platenSizes", "materials", "transferMedia", "pressureDescriptions",
    "instructionSources", "placementActions", "finishActions"
]
EXPECTED_COUNTS = {
    "platenSizes": 18,
    "materials": 20,
    "transferMedia": 18,
    "pressureDescriptions": 5,
    "instructionSources": 5,
    "placementActions": 16,
    "finishActions": 16,
}
SEPARATOR = "__PB_PRESET_{:03d}__"


def translate_batch(values, target):
    separators = [SEPARATOR.format(index) for index in range(1, len(values))]
    parts = []
    for index, value in enumerate(values):
        parts.append(value)
        if index < len(separators):
            parts.append(separators[index])
    payload = urllib.parse.urlencode({
        "client": "gtx",
        "sl": "en",
        "tl": TRANSLATION_CODES.get(target, target),
        "dt": "t",
        "q": "\n".join(parts),
    }).encode("utf-8")
    request = urllib.request.Request(
        "https://translate.googleapis.com/translate_a/single",
        data=payload,
        headers={"User-Agent": "PressBench localization maintainer/1.0"},
    )
    last_error = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                body = json.loads(response.read().decode("utf-8"))
            translated = "".join(segment[0] for segment in body[0])
            split_pattern = r"\s*__PB_PRESET_\d{3}__\s*"
            output = [part.strip() for part in re.split(split_pattern, translated)]
            if len(output) != len(values) or any(not value for value in output):
                raise ValueError(f"split mismatch: expected {len(values)}, received {len(output)}")
            return output
        except Exception as error:
            last_error = error
            time.sleep(2 ** attempt)
    raise RuntimeError(f"translation failed for {target}: {last_error}")


def localized_dimensions(values):
    output = []
    for value in values:
        match = re.fullmatch(r"(\d+) × (\d+) in", value)
        output.append(f"{match.group(1)} × {match.group(2)}″" if match else value)
    return output


def apply_overrides(catalog):
    overrides = json.loads(OVERRIDES_PATH.read_text(encoding="utf-8"))
    for group, locales in overrides.items():
        for code, replacements in locales.items():
            for index, value in replacements.items():
                catalog["groups"][group][code][int(index)] = value


def main():
    if "--apply-overrides-only" in sys.argv:
        catalog = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        apply_overrides(catalog)
        OUTPUT_PATH.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"updated overrides in {OUTPUT_PATH}")
        return

    source = json.loads(SOURCE_PATH.read_text(encoding="utf-8"))
    if list(source) != GROUP_ORDER:
        raise SystemExit("preset group order changed")
    for group, count in EXPECTED_COUNTS.items():
        if len(source[group]) != count:
            raise SystemExit(f"{group}: expected {count}, found {len(source[group])}")

    catalog = {
        "schemaVersion": 1,
        "languages": LANGUAGES,
        "localeOverrideCodes": OVERRIDES,
        "translationBasis": "GoodUse Studios terminology review with machine-assisted first pass",
        "groups": {group: {"en": values} for group, values in source.items()},
    }
    translatable = [value for group in GROUP_ORDER for value in source[group]]
    for code in LANGUAGES[1:] + OVERRIDES:
        print(f"translating {code}...", flush=True)
        translated = translate_batch(translatable, code)
        cursor = 0
        for group in GROUP_ORDER:
            count = len(source[group])
            values = translated[cursor:cursor + count]
            cursor += count
            if group == "platenSizes":
                universal = localized_dimensions(source[group])
                values[:13] = universal[:13]
            catalog["groups"][group][code] = values
        time.sleep(0.35)

    apply_overrides(catalog)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUTPUT_PATH}: {sum(EXPECTED_COUNTS.values())} presets × {len(LANGUAGES) + len(OVERRIDES)} locale codes")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
