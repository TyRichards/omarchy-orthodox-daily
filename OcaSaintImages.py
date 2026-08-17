#!/usr/bin/env python3
"""Resolve Orthocal saint stories to locally cached OCA icon images."""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import tempfile
import urllib.parse
import urllib.request
from datetime import date, timedelta
from html.parser import HTMLParser
from pathlib import Path

USER_AGENT = "Omarchy Orthodox Daily/1.0 (+https://www.oca.org/)"
STOP_WORDS = {
    "a", "and", "holy", "in", "late", "martyr", "martyrs", "new", "of",
    "presbyter", "saint", "saints", "st", "the", "venerable",
}


class OcaImageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.images: list[dict[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() != "img":
            return
        values = dict(attrs)
        source = html.unescape(values.get("src") or "")
        alt = html.unescape(values.get("alt") or "").strip()
        if source.startswith("https://images.oca.org/icons/") and alt:
            self.images.append({"url": source, "alt": alt})


def request_bytes(url: str, timeout: int = 12) -> tuple[bytes, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        content_type = response.headers.get_content_type()
        data = response.read(5 * 1024 * 1024 + 1)
    if len(data) > 5 * 1024 * 1024:
        raise ValueError("OCA image exceeds local cache limit")
    return data, content_type


def normalized_tokens(value: str) -> set[str]:
    value = re.sub(r"\([^)]*\)", " ", value.lower())
    return {
        token for token in re.findall(r"[a-z0-9]+", value)
        if len(token) > 1 and token not in STOP_WORDS
    }


def match_score(title: str, alt: str) -> float:
    title_tokens = normalized_tokens(title)
    alt_tokens = normalized_tokens(alt)
    if not title_tokens or not alt_tokens:
        return 0.0
    overlap = title_tokens & alt_tokens
    if not overlap:
        return 0.0
    coverage = len(overlap) / len(title_tokens)
    precision = len(overlap) / len(alt_tokens)
    return coverage * 0.75 + precision * 0.25


def daily_images(day: date) -> list[dict[str, str]]:
    page = f"https://www.oca.org/saints/lives/{day:%Y/%m/%d}"
    raw, _ = request_bytes(page)
    parser = OcaImageParser()
    parser.feed(raw.decode("utf-8", errors="replace"))
    return [{**image, "page": page} for image in parser.images]


def preferred_image_url(source: str) -> str:
    return source.replace("/icons/xsm/", "/icons/sm/", 1)


def cache_image(image: dict[str, str], destination: Path) -> str:
    candidates = [preferred_image_url(image["url"]), image["url"]]
    last_error: Exception | None = None
    for url in dict.fromkeys(candidates):
        try:
            data, content_type = request_bytes(urllib.parse.quote(url, safe=":/%?=&"))
            if not content_type.startswith("image/"):
                raise ValueError(f"Unexpected content type: {content_type}")
            suffix = ".png" if content_type == "image/png" else ".jpg"
            target = destination.with_suffix(suffix)
            target.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as handle:
                handle.write(data)
                temporary = Path(handle.name)
            os.replace(temporary, target)
            return str(target)
        except Exception as error:  # Try the OCA thumbnail if the larger icon is absent.
            last_error = error
    if last_error:
        raise last_error
    return ""


def atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
        temporary = Path(handle.name)
    os.replace(temporary, path)


def resolve(day: date, titles: list[str], cache_root: Path) -> list[dict[str, str]]:
    day_dir = cache_root / day.isoformat()
    manifest_path = day_dir / "manifest.json"
    if manifest_path.exists():
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            images = manifest.get("images") or []
            cache_files_exist = all(
                not image.get("path") or Path(image["path"]).exists()
                for image in images if isinstance(image, dict)
            )
            if manifest.get("version") == 1 and manifest.get("titles") == titles and cache_files_exist:
                return images
        except (OSError, ValueError, TypeError):
            pass

    candidates: list[dict[str, str]] = []
    for offset in (-1, 0, 1):
        try:
            candidates.extend(daily_images(day + timedelta(days=offset)))
        except Exception:
            continue

    results: list[dict[str, str]] = []
    used_urls: set[str] = set()
    for index, title in enumerate(titles):
        ranked = sorted(
            ((match_score(title, candidate["alt"]), candidate) for candidate in candidates),
            key=lambda item: item[0],
            reverse=True,
        )
        score, match = ranked[0] if ranked else (0.0, None)
        result = {"path": "", "url": "", "alt": "", "page": ""}
        if match and score >= 0.58 and match["url"] not in used_urls:
            try:
                path = cache_image(match, day_dir / f"story-{index}")
                result = {
                    "path": path,
                    "url": preferred_image_url(match["url"]),
                    "alt": match["alt"],
                    "page": match["page"],
                }
                used_urls.add(match["url"])
            except Exception:
                pass
        results.append(result)

    atomic_json(manifest_path, {"version": 1, "titles": titles, "images": results})
    return results


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True)
    parser.add_argument("--cache-dir", required=True)
    parser.add_argument("--titles", required=True)
    args = parser.parse_args()

    day = date.fromisoformat(args.date)
    titles_value = json.loads(args.titles)
    titles = [str(title) for title in titles_value] if isinstance(titles_value, list) else []
    print(json.dumps(resolve(day, titles, Path(args.cache_dir)), ensure_ascii=False))


if __name__ == "__main__":
    main()
