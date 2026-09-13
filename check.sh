#!/bin/bash
# Dependency-free local validation for the static legal site.
# Usage: bash check.sh

set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

python3 - "$repo_root" <<'PY'
from __future__ import annotations

from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import re
import sys

root = Path(sys.argv[1])
pages = sorted(root.glob("*.html"))
failures: list[str] = []
known_hosts = {"purposelabstudio.com", "purposelabstudio.github.io"}
expected_pages = {
    "index.html",
    "bplog.html",
    "bplog-terms.html",
    "crumbs.html",
    "crumbs-terms.html",
    "folio.html",
    "folio-terms.html",
    "hushly.html",
    "hushly-terms.html",
    "waterwise.html",
    "waterwise-terms.html",
}
void_elements = {
    "area", "base", "br", "col", "embed", "hr", "img", "input", "link",
    "meta", "param", "source", "track", "wbr",
}


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.lang = ""
        self.title_parts: list[str] = []
        self.in_title = False
        self.html_count = 0
        self.head_count = 0
        self.body_count = 0
        self.title_count = 0
        self.main_count = 0
        self.headings: list[tuple[int, str]] = []
        self.heading_level = 0
        self.heading_parts: list[str] = []
        self.links: list[str] = []
        self.ids: set[str] = set()
        self.duplicate_ids: set[str] = set()
        self.images: list[dict[str, str | None]] = []
        self.controls: list[tuple[str, dict[str, str | None], bool]] = []
        self.label_for: set[str] = set()
        self.label_depth = 0
        self.meta: list[dict[str, str | None]] = []
        self.open_elements: list[str] = []
        self.structure_errors: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if element_id := values.get("id"):
            if element_id in self.ids:
                self.duplicate_ids.add(element_id)
            self.ids.add(element_id)
        if tag not in void_elements:
            self.open_elements.append(tag)
        if tag == "html":
            self.html_count += 1
            self.lang = (values.get("lang") or "").strip()
        elif tag == "head":
            self.head_count += 1
        elif tag == "body":
            self.body_count += 1
        elif tag == "title":
            self.title_count += 1
            self.in_title = True
        elif tag == "main":
            self.main_count += 1
        elif re.fullmatch(r"h[1-6]", tag):
            self.heading_level = int(tag[1])
            self.heading_parts = []
        elif tag == "a" and "href" in values:
            self.links.append(values["href"] or "")
        elif tag == "img":
            self.images.append(values)
        elif tag == "label":
            self.label_depth += 1
            if target := values.get("for"):
                self.label_for.add(target)
        elif tag in {"input", "select", "textarea"}:
            self.controls.append((tag, values, self.label_depth > 0))
        elif tag == "meta":
            self.meta.append(values)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)
        if tag not in void_elements:
            self.handle_endtag(tag)

    def handle_endtag(self, tag: str) -> None:
        if tag in void_elements:
            self.structure_errors.append(f"void element </{tag}> must not have an end tag")
        elif not self.open_elements:
            self.structure_errors.append(f"unexpected closing tag </{tag}>")
        elif self.open_elements[-1] != tag:
            self.structure_errors.append(
                f"closing tag </{tag}> does not match open <{self.open_elements[-1]}>"
            )
            if tag in self.open_elements:
                while self.open_elements and self.open_elements[-1] != tag:
                    self.open_elements.pop()
                self.open_elements.pop()
        else:
            self.open_elements.pop()
        if tag == "title":
            self.in_title = False
        elif tag == "label" and self.label_depth:
            self.label_depth -= 1
        elif self.heading_level and tag == f"h{self.heading_level}":
            self.headings.append((self.heading_level, " ".join(self.heading_parts).strip()))
            self.heading_level = 0
            self.heading_parts = []

    def handle_data(self, data: str) -> None:
        if self.in_title:
            self.title_parts.append(data)
        if self.heading_level:
            self.heading_parts.append(data)


def fail(page: Path, message: str) -> None:
    failures.append(f"FAIL  {page.name}: {message}")


def is_empty_document(text: str) -> bool:
    return not text.strip()


def local_target(page: Path, href: str) -> tuple[Path, str] | None:
    if any(character.isspace() for character in href):
        raise ValueError("link target contains whitespace")
    parsed = urlsplit(href)
    scheme = parsed.scheme.lower()
    if scheme in {"mailto", "tel", "data"}:
        return None
    if scheme == "javascript":
        raise ValueError("javascript links are not allowed")
    if scheme in {"http", "https"} or (not scheme and parsed.netloc):
        if not parsed.hostname:
            raise ValueError("network link has no hostname")
        if (parsed.hostname or "").lower() not in known_hosts:
            return None
        prefix = "/privacy-policies/"
        if parsed.path in {"/privacy-policies", "/privacy-policies/"}:
            raw_path = "index.html"
        elif parsed.path.startswith(prefix):
            raw_path = parsed.path.removeprefix(prefix)
        else:
            return None
        path = root / unquote(raw_path)
    elif scheme or parsed.netloc:
        raise ValueError(f"unsupported link scheme {scheme!r}")
    elif parsed.path in {"/privacy-policies", "/privacy-policies/"}:
        path = root / "index.html"
    elif parsed.path.startswith("/privacy-policies/"):
        path = root / unquote(parsed.path.removeprefix("/privacy-policies/"))
    elif parsed.path.startswith("/"):
        return None
    else:
        decoded_path = unquote(parsed.path)
        if "\\" in decoded_path or "\x00" in decoded_path:
            raise ValueError("invalid local link path")
        path = page.parent / decoded_path if decoded_path else page
    if path.is_dir():
        path /= "index.html"
    resolved = path.resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as exc:
        raise ValueError("local link escapes the site root") from exc
    return resolved, unquote(parsed.fragment)


parsers: dict[Path, PageParser] = {}
for page in pages:
    text = page.read_text(encoding="utf-8")
    parser = PageParser()
    parser.feed(text)
    parser.close()
    parsers[page.resolve()] = parser

    if is_empty_document(text):
        fail(page, "empty HTML document")
    if not re.match(r"\s*<!doctype\s+html", text, re.IGNORECASE):
        fail(page, "missing HTML doctype")
    if parser.html_count != 1:
        fail(page, f"expected exactly one html element, found {parser.html_count}")
    if parser.head_count != 1:
        fail(page, f"expected exactly one head element, found {parser.head_count}")
    if parser.body_count != 1:
        fail(page, f"expected exactly one body element, found {parser.body_count}")
    if not re.fullmatch(r"[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*", parser.lang):
        fail(page, "missing or invalid html lang")
    if parser.title_count != 1:
        fail(page, f"expected exactly one title element, found {parser.title_count}")
    if not "".join(parser.title_parts).strip():
        fail(page, "missing non-empty title")
    if parser.main_count != 1:
        fail(page, f"expected exactly one main element, found {parser.main_count}")
    if not parser.headings or parser.headings[0][0] != 1:
        fail(page, "first heading must be h1")
    if sum(level == 1 for level, _ in parser.headings) != 1:
        fail(page, "expected exactly one h1")
    for (previous, _), (current, text_value) in zip(parser.headings, parser.headings[1:]):
        if current > previous + 1:
            fail(page, f"heading level skips to h{current}: {text_value!r}")
    if any(not text_value for _, text_value in parser.headings):
        fail(page, "contains an empty heading")
    for error in parser.structure_errors:
        fail(page, f"malformed HTML: {error}")
    for tag in reversed(parser.open_elements):
        fail(page, f"malformed HTML: unclosed <{tag}>")
    for element_id in sorted(parser.duplicate_ids):
        fail(page, f"duplicate id {element_id!r}")

    descriptions = [
        meta for meta in parser.meta
        if (meta.get("name") or "").lower() == "description" and (meta.get("content") or "").strip()
    ]
    if not descriptions:
        fail(page, "missing non-empty meta description")
    if not any((meta.get("name") or "").lower() == "viewport" for meta in parser.meta):
        fail(page, "missing viewport meta tag")

    for image in parser.images:
        if "alt" not in image:
            fail(page, "image missing alt attribute")
    for target in sorted(parser.label_for - parser.ids):
        fail(page, f"label references missing id {target!r}")
    for tag, attrs, wrapped in parser.controls:
        input_type = (attrs.get("type") or "").lower()
        if tag == "input" and input_type == "hidden":
            continue
        if tag == "input" and input_type == "image":
            if not (attrs.get("alt") or "").strip():
                fail(page, "image input lacks non-empty alt text")
            continue
        labelled_by = (attrs.get("aria-labelledby") or "").split()
        missing_labels = [label_id for label_id in labelled_by if label_id not in parser.ids]
        if missing_labels:
            fail(page, f"{tag} control references missing aria-labelledby id(s): {missing_labels}")
        if tag == "input" and input_type in {"submit", "reset"}:
            continue
        if tag == "input" and input_type == "button":
            if not (
                (attrs.get("value") or "").strip()
                or (attrs.get("aria-label") or "").strip()
                or labelled_by
            ):
                fail(page, "button input lacks an accessible name")
            continue
        control_id = attrs.get("id") or ""
        named = bool(
            wrapped
            or (control_id and control_id in parser.label_for)
            or (attrs.get("aria-label") or "").strip()
            or labelled_by
        )
        if not named:
            fail(page, f"{tag} control lacks a label or accessible name")

actual_pages = {page.name for page in pages}
for missing in sorted(expected_pages - actual_pages):
    failures.append(f"FAIL  missing expected HTML page: {missing}")
for unexpected in sorted(actual_pages - expected_pages):
    failures.append(
        f"FAIL  unexpected HTML page not registered in check.sh: {unexpected}"
    )


def link_problem(page: Path, href: str) -> str | None:
    if not href.strip():
        return "empty link target"
    try:
        target = local_target(page, href)
    except ValueError as exc:
        return f"invalid link {href!r}: {exc}"
    if target is None:
        return None
    target_path, fragment = target
    if target_path not in parsers:
        return f"broken internal link {href!r}"
    if fragment and fragment not in parsers[target_path].ids:
        return f"missing fragment target in {href!r}"
    return None


def self_test(name: str, condition: bool) -> None:
    if not condition:
        failures.append(f"FAIL  self-test {name}")
    else:
        print(f"PASS  self-test {name}")


index = root / "index.html"
self_test(
    "link-routing-valid-forms",
    all(
        link_problem(index, href) is None
        for href in (
            "bplog.html",
            "bplog.html?source=self-test",
            "/privacy-policies/bplog.html",
            "https://purposelabstudio.com/privacy-policies/bplog.html",
            "//purposelabstudio.github.io/privacy-policies/bplog.html",
            "/privacy-policies/",
        )
    ),
)
self_test(
    "link-routing-rejects-missing-and-traversal",
    link_problem(index, "/privacy-policies/__missing-link-self-test__.html") is not None
    and link_problem(index, "../outside.html") is not None
    and link_problem(index, "%2e%2e/outside.html") is not None,
)
self_test(
    "link-routing-fragments-and-query",
    link_problem(index, "index.html?source=self-test#missing-fragment") is not None
    and link_problem(index, "index.html?source=self-test") is None,
)
self_test(
    "link-routing-external-and-unsafe",
    link_problem(index, "https://example.com/privacy") is None
    and link_problem(index, "javascript:void(0)") is not None
    and link_problem(index, "unknown-scheme:target") is not None
    and link_problem(index, "https://example.com/bad path") is not None
    and link_problem(index, "") is not None,
)
malformed_fixture = PageParser()
malformed_fixture.feed("<!doctype html><html><body><main></body></html>")
malformed_fixture.close()
self_test(
    "malformed-html-guard",
    bool(malformed_fixture.structure_errors or malformed_fixture.open_elements),
)
self_test("empty-html-guard", is_empty_document(" \n\t"))
self_test("expected-page-inventory", actual_pages == expected_pages)

external_http_links: set[str] = set()
for page, parser in parsers.items():
    for href in parser.links:
        if problem := link_problem(page, href):
            fail(page, problem)
            continue
        parsed = urlsplit(href)
        if parsed.scheme.lower() in {"http", "https"} or parsed.netloc:
            host = (parsed.hostname or "").lower()
            local_site_path = (
                host in known_hosts
                and (
                    parsed.path in {"/privacy-policies", "/privacy-policies/"}
                    or parsed.path.startswith("/privacy-policies/")
                )
            )
            if not local_site_path:
                external_http_links.add(href)

# Folio keeps notebook content local by default. A cloud copy exists only when
# the person explicitly asks Folio to use their own Google Drive or iCloud.
for name in ("folio.html", "folio-terms.html"):
    text = (root / name).read_text(encoding="utf-8")
    if "personal Google Drive or iCloud account you choose" not in text:
        fail(root / name, "Folio personal-cloud boundary missing")
folio = (root / "folio.html").read_text(encoding="utf-8")
if "never sent to Folio or PurposeLab servers" not in folio:
    fail(root / "folio.html", "Folio server boundary missing")
if "never read, access, analyze, or transmit your journal entries" in folio:
    fail(root / "folio.html", "absolute no-transmission claim is not allowed")
if not any(message.startswith("FAIL  folio") for message in failures):
    print("PASS  self-test folio-policy-boundaries")
folio_app_store_url = "https://apps.apple.com/us/app/folio-daily-journal-diary/id6781551692"
if folio_app_store_url not in folio:
    fail(root / "folio.html", "canonical Folio App Store link missing")
else:
    print("PASS  self-test folio-app-store-link")

for message in failures:
    print(message)

print("MANUAL readability: review changed policy text at mobile and desktop widths.")
print("MANUAL keyboard: tab through every link/control and confirm visible focus and logical order.")
print("MANUAL contrast: check text, links, and focus indicators against their backgrounds.")
print(
    f"MANUAL external links: verify {len(external_http_links)} distinct off-site/out-of-scope "
    "HTTP(S) targets; the local check validates syntax only."
)

if failures:
    print(f"{len(failures)} problem(s) across {len(pages)} HTML pages")
    raise SystemExit(1)
print(
    f"PASS  {len(pages)} HTML pages: structure, metadata, headings, accessible names, "
    "alt text, internal links, and Folio boundaries"
)
PY
