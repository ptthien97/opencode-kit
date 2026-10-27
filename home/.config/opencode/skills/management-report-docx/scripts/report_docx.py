#!/usr/bin/env python3
"""Management report DOCX CLI — render, validate, sanitize (stdlib + optional pandoc)."""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Iterable
from xml.sax.saxutils import escape

SKILL_ROOT = Path(__file__).resolve().parents[1]
SKILL_NAME = "management-report-docx"
SKILL_VERSION = "1.0.0"

# ---------------------------------------------------------------------------
# Section contract
# ---------------------------------------------------------------------------

MANDATORY_SECTION_KEYS = (
    "executive_summary",
    "scope_and_period",
    "key_work_and_results",
    "verifiable_evidence",
    "status_assessment",
    "risks_and_blockers",
    "recommendations_or_next_steps",
    "sources_and_appendix",
)

SECTION_ALIASES: dict[str, tuple[str, ...]] = {
    "executive_summary": (
        "executive summary",
        "tóm tắt điều hành",
        "tom tat dieu hanh",
        "tóm tắt",
        "tom tat",
    ),
    "scope_and_period": (
        "scope and reporting period",
        "scope / reporting period",
        "scope and period",
        "phạm vi và kỳ báo cáo",
        "pham vi va ky bao cao",
        "phạm vi",
        "pham vi",
        "kỳ báo cáo",
        "ky bao cao",
    ),
    "key_work_and_results": (
        "key work and results",
        "key results",
        "công việc và kết quả chính",
        "cong viec va ket qua chinh",
        "kết quả chính",
        "ket qua chinh",
    ),
    "verifiable_evidence": (
        "verifiable evidence",
        "evidence",
        "bằng chứng có thể kiểm chứng",
        "bang chung co the kiem chung",
        "bằng chứng",
        "bang chung",
    ),
    "status_assessment": (
        "status assessment",
        "status",
        "đánh giá trạng thái",
        "danh gia trang thai",
        "trạng thái",
        "trang thai",
    ),
    "risks_and_blockers": (
        "risks and blockers",
        "risks",
        "rủi ro và trở ngại",
        "rui ro va tro ngai",
        "rủi ro",
        "rui ro",
    ),
    "recommendations_or_next_steps": (
        "recommendations or next steps",
        "recommendations / next steps",
        "recommendations",
        "next steps",
        "kiến nghị hoặc bước tiếp theo",
        "kien nghi hoac buoc tiep theo",
        "kiến nghị",
        "kien nghi",
        "bước tiếp theo",
        "buoc tiep theo",
    ),
    "sources_and_appendix": (
        "sources and appendix",
        "sources / appendix",
        "sources",
        "appendix",
        "limitations",
        "nguồn và phụ lục",
        "nguon va phu luc",
        "nguồn",
        "nguon",
        "phụ lục",
        "phu luc",
        "hạn chế",
        "han che",
    ),
}

DEFAULT_HEADINGS_EN = {
    "executive_summary": "Executive Summary",
    "scope_and_period": "Scope and Reporting Period",
    "key_work_and_results": "Key Work and Results",
    "verifiable_evidence": "Verifiable Evidence",
    "status_assessment": "Status Assessment",
    "risks_and_blockers": "Risks and Blockers",
    "recommendations_or_next_steps": "Recommendations or Next Steps",
    "sources_and_appendix": "Sources and Appendix",
}

DEFAULT_HEADINGS_VI = {
    "executive_summary": "Tóm tắt điều hành",
    "scope_and_period": "Phạm vi và kỳ báo cáo",
    "key_work_and_results": "Công việc và kết quả chính",
    "verifiable_evidence": "Bằng chứng có thể kiểm chứng",
    "status_assessment": "Đánh giá trạng thái",
    "risks_and_blockers": "Rủi ro và trở ngại",
    "recommendations_or_next_steps": "Kiến nghị hoặc bước tiếp theo",
    "sources_and_appendix": "Nguồn và phụ lục",
}

KIND_PREFIX_EN = {
    "fact": "Fact",
    "analysis": "Analysis",
    "recommendation": "Recommendation",
    "gap": "Limitation",
}

KIND_PREFIX_VI = {
    "fact": "Sự kiện",
    "analysis": "Phân tích",
    "recommendation": "Kiến nghị",
    "gap": "Hạn chế",
}

# ---------------------------------------------------------------------------
# Sanitizer
# ---------------------------------------------------------------------------

_SECRET_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    (
        "private_key",
        re.compile(
            r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----[\s\S]*?"
            r"-----END (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----",
            re.MULTILINE,
        ),
    ),
    (
        "aws_access_key",
        re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    ),
    (
        "github_pat",
        re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}\b"),
    ),
    (
        "slack_token",
        re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"),
    ),
    (
        "bearer_jwt",
        re.compile(
            r"\b(?:Bearer\s+)?eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"
        ),
    ),
    (
        "generic_api_key_assign",
        re.compile(
            r"(?i)\b(api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|"
            r"password|passwd|pwd|client_secret)\b\s*[:=]\s*['\"]?([^\s'\"\\]{8,})"
        ),
    ),
    (
        "connection_string",
        re.compile(
            r"(?i)\b(?:postgres|mysql|mongodb|redis|amqp)://[^\s]+:[^\s]+@[^\s]+"
        ),
    ),
]

_HOME_PATH = re.compile(r"(?i)(/Users/[^/\s]+|/home/[^/\s]+|C:\\Users\\[^\\\s]+)")

DEFAULT_FIELD_LIMIT = 4000
DEFAULT_EVIDENCE_DETAIL_LIMIT = 500
DEFAULT_DIFF_LINES = 20


def sanitize_text(
    text: str,
    *,
    max_chars: int = DEFAULT_FIELD_LIMIT,
    redact_home: bool = True,
) -> tuple[str, list[str]]:
    """Return sanitized text and list of redaction tags applied."""
    if text is None:
        return "", []
    s = str(text)
    tags: list[str] = []

    for name, pattern in _SECRET_PATTERNS:
        if pattern.search(s):
            tags.append(name)
            if name == "generic_api_key_assign":
                s = pattern.sub(r"\1=[REDACTED]", s)
            else:
                s = pattern.sub("[REDACTED]", s)

    if redact_home and _HOME_PATH.search(s):
        tags.append("home_path")
        s = _HOME_PATH.sub(lambda m: m.group(0).split("/")[0] + "/[USER]" if "/" in m.group(0)
                           else m.group(0).split("\\")[0] + "\\[USER]", s)
        # Simpler stable redaction:
        s = re.sub(r"(?i)(/Users/)[^/\s]+", r"\1[USER]", s)
        s = re.sub(r"(?i)(/home/)[^/\s]+", r"\1[USER]", s)
        s = re.sub(r"(?i)(C:\\Users\\)[^\\\s]+", r"\1[USER]", s)

    # Bound oversized raw-looking dumps
    lines = s.splitlines()
    if len(lines) > DEFAULT_DIFF_LINES * 3 and (
        sum(1 for ln in lines if ln.startswith(("+", "-", "@@", "diff "))) > 10
        or len(s) > max_chars
    ):
        tags.append("oversized_dump")
        head = "\n".join(lines[:DEFAULT_DIFF_LINES])
        s = (
            head
            + f"\n… [truncated {len(lines) - DEFAULT_DIFF_LINES} lines; "
            + "raw dump omitted for management report]"
        )

    if len(s) > max_chars:
        tags.append("truncated")
        s = s[: max_chars - 20].rstrip() + "… [truncated]"

    return s, tags


def sanitize_structure(obj: Any, *, max_chars: int = DEFAULT_FIELD_LIMIT) -> Any:
    """Deep-sanitize strings in dict/list structures."""
    if isinstance(obj, str):
        cleaned, _ = sanitize_text(obj, max_chars=max_chars)
        return cleaned
    if isinstance(obj, list):
        return [sanitize_structure(x, max_chars=max_chars) for x in obj]
    if isinstance(obj, dict):
        out: dict[str, Any] = {}
        for k, v in obj.items():
            limit = (
                DEFAULT_EVIDENCE_DETAIL_LIMIT
                if k in {"summary", "detail", "reference", "paths"}
                else max_chars
            )
            out[k] = sanitize_structure(v, max_chars=limit)
        return out
    return obj


def find_secret_hits(text: str) -> list[str]:
    hits: list[str] = []
    for name, pattern in _SECRET_PATTERNS:
        if name in {"generic_api_key_assign"}:
            # Avoid flagging prose like "password policy"
            if pattern.search(text):
                hits.append(name)
        elif pattern.search(text):
            hits.append(name)
    return hits


# ---------------------------------------------------------------------------
# JSON → Markdown
# ---------------------------------------------------------------------------

def _lang_headings(language: str) -> dict[str, str]:
    return DEFAULT_HEADINGS_VI if (language or "").lower().startswith("vi") else DEFAULT_HEADINGS_EN


def _kind_prefix(kind: str, language: str) -> str:
    table = KIND_PREFIX_VI if (language or "").lower().startswith("vi") else KIND_PREFIX_EN
    return table.get((kind or "fact").lower(), table["fact"])


def _as_items(value: Any) -> list[dict[str, Any]]:
    if value is None:
        return []
    if isinstance(value, str):
        return [{"kind": "fact", "text": value}]
    if isinstance(value, list):
        items: list[dict[str, Any]] = []
        for x in value:
            if isinstance(x, str):
                items.append({"kind": "fact", "text": x})
            elif isinstance(x, dict):
                items.append(x)
            else:
                items.append({"kind": "fact", "text": str(x)})
        return items
    if isinstance(value, dict):
        return [value]
    return [{"kind": "fact", "text": str(value)}]


def _format_item(item: dict[str, Any], language: str) -> str:
    kind = (item.get("kind") or "fact").lower()
    text = str(item.get("text") or "").strip()
    prefix = _kind_prefix(kind, language)
    evid = item.get("evidenceIds") or item.get("evidence") or []
    if isinstance(evid, str):
        evid = [evid]
    suffix = ""
    if evid:
        suffix = f" (Evidence: {', '.join(str(e) for e in evid)})"
    if not text:
        return f"- {prefix}:{suffix}".rstrip()
    # Avoid double-prefix if author already labeled
    lower = text.lower()
    if lower.startswith(prefix.lower() + ":") or lower.startswith(prefix.lower() + ":"):
        return f"- {text}{suffix}"
    return f"- {prefix}: {text}{suffix}"


def report_json_to_markdown(data: dict[str, Any]) -> str:
    data = sanitize_structure(data)
    language = str(data.get("language") or "en")
    headings = _lang_headings(language)
    title = str(data.get("title") or "Management Report")
    meta = data.get("metadata") or {}
    if not isinstance(meta, dict):
        meta = {}

    lines: list[str] = [f"# {title}", ""]

    # Metadata table
    vi = language.lower().startswith("vi")
    field_label = "Trường" if vi else "Field"
    value_label = "Giá trị" if vi else "Value"
    rows = [
        ("Ngày báo cáo" if vi else "Report date", meta.get("reportDate") or data.get("reportDate")),
        ("Người lập" if vi else "Author", meta.get("author") or data.get("author")),
        ("Người nhận" if vi else "Reader", meta.get("reader") or data.get("reader")),
        (
            "Kỳ báo cáo" if vi else "Period",
            _period_cell(meta, vi),
        ),
        (
            "Kho mã / nhánh" if vi else "Repository / branch",
            _repo_branch(meta),
        ),
        ("Phạm vi" if vi else "Scope", meta.get("scope") or data.get("scope")),
    ]
    lines += [f"| {field_label} | {value_label} |", "|---|---|"]
    for label, val in rows:
        if val:
            lines.append(f"| {label} | {_md_escape_cell(str(val))} |")
    lines.append("")

    # Sections
    section_sources: list[tuple[str, Any]] = [
        ("executive_summary", data.get("executiveSummary") or data.get("executive_summary")),
        ("scope_and_period", data.get("scopeAndPeriod") or data.get("scope_and_period")),
        ("key_work_and_results", data.get("keyWorkAndResults") or data.get("key_work_and_results")),
        ("verifiable_evidence", data.get("evidence") or data.get("verifiableEvidence")),
        ("status_assessment", data.get("statusAssessment") or data.get("status_assessment")),
        ("risks_and_blockers", data.get("risksAndBlockers") or data.get("risks_and_blockers")),
        (
            "recommendations_or_next_steps",
            data.get("recommendationsOrNextSteps") or data.get("recommendations_or_next_steps"),
        ),
        (
            "sources_and_appendix",
            data.get("sourcesAndAppendix") or data.get("sources_and_appendix"),
        ),
    ]

    limitations = data.get("limitations") or []

    for key, raw in section_sources:
        lines.append(f"## {headings[key]}")
        lines.append("")
        if key == "verifiable_evidence":
            lines.extend(_evidence_markdown(raw, vi=vi))
        elif key == "scope_and_period" and isinstance(raw, str):
            lines.append(raw.strip() or ("_(not specified)_" if not vi else "_(chưa nêu)_"))
            lines.append("")
        elif key == "sources_and_appendix":
            items = raw if isinstance(raw, list) else ([raw] if raw else [])
            if not items and not limitations:
                lines.append("- _(none)_" if not vi else "- _(không)_")
            for it in items:
                if isinstance(it, dict):
                    lines.append(_format_item(it, language))
                else:
                    lines.append(f"- {it}")
            for lim in limitations if isinstance(limitations, list) else [limitations]:
                if lim:
                    prefix = "Hạn chế" if vi else "Limitation"
                    lines.append(f"- {prefix}: {lim}")
            lines.append("")
        else:
            items = _as_items(raw)
            if not items:
                lines.append("- _(not provided)_" if not vi else "- _(chưa cung cấp)_")
            else:
                for it in items:
                    lines.append(_format_item(it, language))
            lines.append("")

    # Ensure limitations also surface under status if only there — already in sources
    return "\n".join(lines).rstrip() + "\n"


def _period_cell(meta: dict[str, Any], vi: bool) -> str:
    start = meta.get("periodStart") or meta.get("period_start")
    end = meta.get("periodEnd") or meta.get("period_end")
    if start and end:
        return f"{start} → {end}"
    if start:
        return str(start)
    if end:
        return str(end)
    return ""


def _repo_branch(meta: dict[str, Any]) -> str:
    repo = meta.get("repository") or meta.get("repo") or ""
    branch = meta.get("branch") or ""
    if repo and branch:
        return f"{repo} @ {branch}"
    return str(repo or branch or "")


def _md_escape_cell(s: str) -> str:
    return s.replace("|", "\\|").replace("\n", " ")


def _evidence_markdown(raw: Any, *, vi: bool) -> list[str]:
    lines: list[str] = []
    if not raw:
        lines.append("_No evidence rows provided._" if not vi else "_Chưa có hàng bằng chứng._")
        lines.append("")
        return lines

    rows = raw if isinstance(raw, list) else [raw]
    if vi:
        lines.append("| Mã | Loại | Tham chiếu | Tóm tắt | Đường dẫn / ghi chú |")
        lines.append("|----|------|------------|---------|---------------------|")
    else:
        lines.append("| ID | Type | Reference | Summary | Paths / notes |")
        lines.append("|----|------|-----------|---------|---------------|")

    for i, row in enumerate(rows, start=1):
        if isinstance(row, str):
            lines.append(
                f"| E{i} | note | — | {_md_escape_cell(row)} |  |"
            )
            continue
        if not isinstance(row, dict):
            lines.append(f"| E{i} | note | — | {_md_escape_cell(str(row))} |  |")
            continue
        eid = str(row.get("id") or f"E{i}")
        etype = str(row.get("type") or "note")
        ref = str(row.get("reference") or "—")
        summary = str(row.get("summary") or row.get("text") or "")
        paths = row.get("paths") or row.get("notes") or ""
        if isinstance(paths, list):
            paths = ", ".join(str(p) for p in paths)
        # sanitize bounds already applied; extra safety
        summary, _ = sanitize_text(summary, max_chars=DEFAULT_EVIDENCE_DETAIL_LIMIT)
        paths_s, _ = sanitize_text(str(paths), max_chars=DEFAULT_EVIDENCE_DETAIL_LIMIT)
        lines.append(
            f"| {_md_escape_cell(eid)} | {_md_escape_cell(etype)} | "
            f"{_md_escape_cell(ref)} | {_md_escape_cell(summary)} | "
            f"{_md_escape_cell(paths_s)} |"
        )
    lines.append("")
    return lines


# ---------------------------------------------------------------------------
# DOCX renderers
# ---------------------------------------------------------------------------

def pandoc_available() -> str | None:
    path = shutil.which("pandoc")
    return path


def render_with_pandoc(markdown: str, output: Path) -> str:
    pandoc = pandoc_available()
    if not pandoc:
        raise RuntimeError("pandoc not found")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mgmt-report-") as tmp:
        md_path = Path(tmp) / "report.md"
        md_path.write_text(markdown, encoding="utf-8")
        cmd = [pandoc, str(md_path), "-o", str(output), "--from=markdown", "--to=docx"]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(f"pandoc failed: {proc.stderr.strip() or proc.stdout.strip()}")
    return "pandoc"


W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
CT_NS = "http://schemas.openxmlformats.org/package/2006/content-types"
R_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"


def _w(tag: str) -> str:
    return f"{{{W_NS}}}{tag}"


def _paragraph(text: str, style: str | None = None, bold: bool = False) -> ET.Element:
    p = ET.Element(_w("p"))
    if style:
        pPr = ET.SubElement(p, _w("pPr"))
        ps = ET.SubElement(pPr, _w("pStyle"))
        ps.set(_w("val"), style)
    r = ET.SubElement(p, _w("r"))
    if bold:
        rPr = ET.SubElement(r, _w("rPr"))
        ET.SubElement(rPr, _w("b"))
    t = ET.SubElement(r, _w("t"))
    t.set("{http://www.w3.org/XML/1998/namespace}space", "preserve")
    t.text = text
    return p


def _table(rows: list[list[str]]) -> list[ET.Element]:
    """Return paragraphs approximating a table (simple rows) for fallback renderer."""
    elements: list[ET.Element] = []
    for i, row in enumerate(rows):
        cells = [c.replace("\n", " ") for c in row]
        line = " | ".join(cells)
        elements.append(_paragraph(line, bold=(i == 0)))
    return elements


def markdown_to_fallback_blocks(markdown: str) -> list[ET.Element]:
    body_children: list[ET.Element] = []
    table_buf: list[list[str]] = []

    def flush_table() -> None:
        nonlocal table_buf
        if table_buf:
            # drop markdown separator rows like ---|---
            filtered = [
                r
                for r in table_buf
                if not all(re.fullmatch(r":?-{3,}:?", c.strip()) for c in r if c.strip())
            ]
            body_children.extend(_table(filtered))
            table_buf = []

    for raw_line in markdown.splitlines():
        line = raw_line.rstrip()
        if not line.strip():
            flush_table()
            continue
        if line.lstrip().startswith("|") and line.rstrip().endswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            table_buf.append(cells)
            continue
        flush_table()
        if line.startswith("# "):
            body_children.append(_paragraph(line[2:].strip(), style="Heading1"))
        elif line.startswith("## "):
            body_children.append(_paragraph(line[3:].strip(), style="Heading2"))
        elif line.startswith("### "):
            body_children.append(_paragraph(line[4:].strip(), style="Heading3"))
        elif line.startswith(("- ", "* ")):
            body_children.append(_paragraph("• " + line[2:].strip()))
        elif re.match(r"^\d+\.\s+", line):
            body_children.append(_paragraph(line.strip()))
        else:
            body_children.append(_paragraph(line.strip()))
    flush_table()
    if not body_children:
        body_children.append(_paragraph(""))
    return body_children


def render_with_stdlib(markdown: str, output: Path) -> str:
    """Minimal OOXML DOCX writer using only the Python standard library."""
    output.parent.mkdir(parents=True, exist_ok=True)

    document = ET.Element(_w("document"))
    body = ET.SubElement(document, _w("body"))
    for el in markdown_to_fallback_blocks(markdown):
        body.append(el)
    sect = ET.SubElement(body, _w("sectPr"))
    pgSz = ET.SubElement(sect, _w("pgSz"))
    pgSz.set(_w("w"), "12240")
    pgSz.set(_w("h"), "15840")
    pgMar = ET.SubElement(sect, _w("pgMar"))
    for k, v in (("top", "1440"), ("right", "1440"), ("bottom", "1440"), ("left", "1440")):
        pgMar.set(_w(k), v)

    # Register namespace for cleaner output
    ET.register_namespace("w", W_NS)
    xml_body = ET.tostring(document, encoding="utf-8", xml_declaration=True)

    content_types = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="{CT_NS}">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
"""

    rels = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="{R_NS}">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
"""

    doc_rels = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="{R_NS}">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
"""

    styles = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="{W_NS}">
  <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
    <w:name w:val="Normal"/>
    <w:qFormat/>
    <w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:uiPriority w:val="9"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:uiPriority w:val="9"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:before="200" w:after="100"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="26"/><w:szCs w:val="26"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:rPr><w:b/><w:sz w:val="24"/></w:rPr>
  </w:style>
</w:styles>
"""

    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    core = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:dcmitype="http://purl.org/dc/dcmitype/"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Management Report</dc:title>
  <dc:creator>{escape(SKILL_NAME)}</dc:creator>
  <cp:lastModifiedBy>{escape(SKILL_NAME)}</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>
"""

    app = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
  xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>{escape(SKILL_NAME)}/{escape(SKILL_VERSION)}</Application>
</Properties>
"""

    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", content_types)
        zf.writestr("_rels/.rels", rels)
        zf.writestr("word/document.xml", xml_body)
        zf.writestr("word/_rels/document.xml.rels", doc_rels)
        zf.writestr("word/styles.xml", styles)
        zf.writestr("docProps/core.xml", core)
        zf.writestr("docProps/app.xml", app)

    return "stdlib-ooxml"


def render_markdown_to_docx(markdown: str, output: Path, *, prefer: str = "auto") -> dict[str, Any]:
    markdown, tags = sanitize_text(markdown, max_chars=200_000)
    engine = None
    errors: list[str] = []

    if prefer in ("auto", "pandoc") and pandoc_available():
        try:
            engine = render_with_pandoc(markdown, output)
        except Exception as exc:  # noqa: BLE001 — fallback is intentional
            errors.append(f"pandoc: {exc}")
            if prefer == "pandoc":
                raise

    if engine is None:
        engine = render_with_stdlib(markdown, output)

    validation = validate_docx(output)
    return {
        "output": str(output.resolve()),
        "engine": engine,
        "sanitizeTags": tags,
        "validation": validation,
        "errors": errors,
    }


# ---------------------------------------------------------------------------
# Validator
# ---------------------------------------------------------------------------

def _normalize_heading(text: str) -> str:
    s = text.strip().lower()
    s = re.sub(r"\s+", " ", s)
    # strip simple diacritics for Vietnamese alias matching flexibility
    repl = str.maketrans(
        "áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ",
        "aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd",
    )
    s2 = s.translate(repl)
    return s2


def extract_docx_text_and_headings(path: Path) -> tuple[str, list[str]]:
    with zipfile.ZipFile(path, "r") as zf:
        xml_bytes = zf.read("word/document.xml")
    root = ET.fromstring(xml_bytes)
    texts: list[str] = []
    headings: list[str] = []
    for p in root.iter(_w("p")):
        style = None
        pPr = p.find(_w("pPr"))
        if pPr is not None:
            ps = pPr.find(_w("pStyle"))
            if ps is not None:
                style = ps.get(_w("val")) or ps.get("val")
        parts: list[str] = []
        for t in p.iter(_w("t")):
            if t.text:
                parts.append(t.text)
        para = "".join(parts).strip()
        if not para:
            continue
        texts.append(para)
        if style and style.lower().startswith("heading"):
            headings.append(para)
        # Also treat ALL-CAPS short lines? No — stick to styles + markdown ## already converted
    # If no styled headings found (some engines), heuristic: lines that match aliases
    if not headings:
        for para in texts:
            norm = _normalize_heading(para)
            for aliases in SECTION_ALIASES.values():
                if norm in aliases or any(norm == a for a in aliases):
                    headings.append(para)
                    break
    return "\n".join(texts), headings


def validate_docx(path: Path) -> dict[str, Any]:
    result: dict[str, Any] = {
        "path": str(path.resolve()) if path.exists() else str(path),
        "ok": False,
        "zipOk": False,
        "hasContentTypes": False,
        "hasDocumentXml": False,
        "xmlOk": False,
        "mandatorySections": {},
        "missingSections": [],
        "secretHits": [],
        "headings": [],
        "errors": [],
    }
    if not path.is_file():
        result["errors"].append("file not found")
        return result

    try:
        with zipfile.ZipFile(path, "r") as zf:
            names = set(zf.namelist())
            result["zipOk"] = True
            result["hasContentTypes"] = "[Content_Types].xml" in names
            result["hasDocumentXml"] = "word/document.xml" in names
            if not result["hasContentTypes"]:
                result["errors"].append("missing [Content_Types].xml")
            if not result["hasDocumentXml"]:
                result["errors"].append("missing word/document.xml")
            else:
                try:
                    ET.fromstring(zf.read("word/document.xml"))
                    result["xmlOk"] = True
                except ET.ParseError as exc:
                    result["errors"].append(f"document.xml parse error: {exc}")
    except zipfile.BadZipFile:
        result["errors"].append("not a valid ZIP/DOCX package")
        return result

    if not (result["zipOk"] and result["hasContentTypes"] and result["hasDocumentXml"] and result["xmlOk"]):
        return result

    text, headings = extract_docx_text_and_headings(path)
    result["headings"] = headings
    norm_headings = {_normalize_heading(h) for h in headings}
    # Also allow matching against full document text lines for robust checks
    norm_lines = {_normalize_heading(line) for line in text.splitlines() if line.strip()}

    missing: list[str] = []
    found: dict[str, bool] = {}
    for key in MANDATORY_SECTION_KEYS:
        aliases = SECTION_ALIASES[key]
        ok = any(a in norm_headings or a in norm_lines for a in aliases)
        # partial contains match for longer headings
        if not ok:
            ok = any(
                any(a in h for a in aliases)
                for h in list(norm_headings) + list(norm_lines)
            )
        found[key] = ok
        if not ok:
            missing.append(key)
    result["mandatorySections"] = found
    result["missingSections"] = missing

    # Secret scan — private keys are hard fail; others soft
    hits = find_secret_hits(text)
    result["secretHits"] = hits
    hard = [h for h in hits if h == "private_key"]
    if hard:
        result["errors"].append(f"secret material detected: {', '.join(hard)}")

    if missing:
        result["errors"].append("missing mandatory sections: " + ", ".join(missing))

    result["ok"] = not result["errors"]
    return result


# ---------------------------------------------------------------------------
# Sample report data
# ---------------------------------------------------------------------------

def sample_report_data() -> dict[str, Any]:
    today = dt.date.today().isoformat()
    return {
        "language": "en",
        "title": "Weekly Management Progress Report",
        "metadata": {
            "reportDate": today,
            "author": "Delivery Team",
            "reader": "Project Supervisor",
            "periodStart": "2026-07-13",
            "periodEnd": "2026-07-20",
            "repository": "example/payments-app",
            "branch": "main",
            "scope": "Checkout validation and reporting for weekly status",
        },
        "executiveSummary": [
            {
                "kind": "fact",
                "text": "Checkout validation rules were expanded and covered by automated checks in the reporting period.",
                "evidenceIds": ["E1", "E2"],
            },
            {
                "kind": "analysis",
                "text": "The change reduces manual review effort for invalid invoices, based on the added automated coverage.",
            },
            {
                "kind": "gap",
                "text": "No production release evidence was found for this period.",
            },
        ],
        "scopeAndPeriod": (
            "Scope: payments checkout validation and related automated checks on branch main. "
            "Reporting period: 2026-07-13 to 2026-07-20. "
            "Uncommitted worktree changes were excluded."
        ),
        "keyWorkAndResults": [
            {
                "kind": "fact",
                "text": "Validation for incomplete payment references was added to the checkout path.",
                "evidenceIds": ["E1"],
            },
            {
                "kind": "fact",
                "text": "Automated tests were added for the new validation cases.",
                "evidenceIds": ["E2"],
            },
            {
                "kind": "analysis",
                "text": "Together, these changes make invalid submissions detectable before hand-off to finance operations.",
            },
        ],
        "evidence": [
            {
                "id": "E1",
                "type": "commit",
                "reference": "a1b2c3d",
                "summary": "Add checkout validation for incomplete payment references",
                "paths": ["src/payments/checkout.py", "docs/checkout.md"],
            },
            {
                "id": "E2",
                "type": "commit",
                "reference": "d4e5f6a",
                "summary": "Add automated tests for checkout validation cases",
                "paths": ["tests/test_checkout_validation.py"],
            },
            {
                "id": "E3",
                "type": "note",
                "reference": "git log main --since=2026-07-13 --until=2026-07-20",
                "summary": "Two feature commits in scope; no release tag in range",
                "paths": [],
            },
        ],
        "statusAssessment": [
            {
                "kind": "fact",
                "text": "In-repository work for checkout validation is present on main with accompanying tests.",
                "evidenceIds": ["E1", "E2"],
            },
            {
                "kind": "gap",
                "text": "Deployment/release status cannot be confirmed from Git history alone.",
            },
        ],
        "risksAndBlockers": [
            {
                "kind": "analysis",
                "text": "If production configuration differs from the tested defaults, residual invalid cases may still reach operations.",
            }
        ],
        "recommendationsOrNextSteps": [
            {
                "kind": "recommendation",
                "text": "Confirm whether a release is planned and record the release identifier in the next report.",
            },
            {
                "kind": "recommendation",
                "text": "Add a short operational checklist for finance hand-off once the change is released.",
            },
        ],
        "sourcesAndAppendix": [
            "Git history on main for 2026-07-13..2026-07-20",
            "Changed paths under src/payments and tests/",
        ],
        "limitations": [
            "Commit messages were short; path-level review was used to confirm intent.",
            "No business-impact metrics were available in the repository evidence.",
        ],
    }


# ---------------------------------------------------------------------------
# Package self-check
# ---------------------------------------------------------------------------

def package_paths() -> dict[str, Path]:
    return {
        "skill_md": SKILL_ROOT / "SKILL.md",
        "protocol": SKILL_ROOT / "references" / "report-protocol.md",
        "template": SKILL_ROOT / "references" / "report-template.md",
        "cli": SKILL_ROOT / "scripts" / "report_docx.py",
        "tests": SKILL_ROOT / "scripts" / "test_report_docx.py",
    }


def command_self_check(_: argparse.Namespace) -> int:
    paths = package_paths()
    missing = [k for k, p in paths.items() if not p.is_file()]
    skill_text = paths["skill_md"].read_text(encoding="utf-8") if paths["skill_md"].is_file() else ""
    has_frontmatter = skill_text.startswith("---") and "name: management-report-docx" in skill_text
    has_description = "description:" in skill_text and "docx" in skill_text.lower()

    # Smoke: sample render + validate in temp dir, then remove
    with tempfile.TemporaryDirectory(prefix="mgmt-selfcheck-") as tmp:
        out = Path(tmp) / f"management-report-{dt.date.today().isoformat()}.docx"
        md = report_json_to_markdown(sample_report_data())
        render_info = render_markdown_to_docx(md, out, prefer="auto")
        validation = render_info["validation"]
        smoke_ok = validation.get("ok") is True

    status = {
        "status": "OK" if not missing and has_frontmatter and has_description and smoke_ok else "FAIL",
        "skill": SKILL_NAME,
        "version": SKILL_VERSION,
        "skillRoot": str(SKILL_ROOT),
        "missingFiles": missing,
        "frontmatterOk": has_frontmatter,
        "descriptionOk": has_description,
        "pandoc": pandoc_available() or "",
        "smokeRenderOk": smoke_ok,
        "smokeEngine": render_info.get("engine"),
        "smokeMissingSections": validation.get("missingSections", []),
    }
    print(json.dumps(status, indent=2, ensure_ascii=False))
    return 0 if status["status"] == "OK" else 1


def command_render(args: argparse.Namespace) -> int:
    output = Path(args.output).expanduser()
    prefer = args.engine or "auto"

    if args.input:
        data = json.loads(Path(args.input).expanduser().read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            print(json.dumps({"status": "FAIL", "error": "input JSON must be an object"}))
            return 2
        markdown = report_json_to_markdown(data)
    elif args.markdown:
        markdown = Path(args.markdown).expanduser().read_text(encoding="utf-8")
        markdown, _ = sanitize_text(markdown, max_chars=200_000)
    else:
        print(json.dumps({"status": "FAIL", "error": "provide --input or --markdown"}))
        return 2

    # Ensure date in default naming hint is not required if user path given
    try:
        info = render_markdown_to_docx(markdown, output, prefer=prefer)
    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"status": "FAIL", "error": str(exc)}, ensure_ascii=False))
        return 1

    ok = bool(info.get("validation", {}).get("ok"))
    payload = {"status": "OK" if ok else "FAIL", **info}
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0 if ok else 1


def command_validate(args: argparse.Namespace) -> int:
    path = Path(args.docx).expanduser()
    result = validate_docx(path)
    result["status"] = "OK" if result.get("ok") else "FAIL"
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result["ok"] else 1


def command_sanitize(args: argparse.Namespace) -> int:
    if args.file:
        text = Path(args.file).expanduser().read_text(encoding="utf-8")
    else:
        text = args.text or ""
    cleaned, tags = sanitize_text(text)
    print(json.dumps({"text": cleaned, "tags": tags}, ensure_ascii=False, indent=2))
    return 0


def command_sample(args: argparse.Namespace) -> int:
    output = Path(args.output).expanduser()
    data = sample_report_data()
    if args.language:
        data["language"] = args.language
        if args.language.lower().startswith("vi") and data["title"] == "Weekly Management Progress Report":
            data["title"] = "Báo cáo tiến độ quản lý tuần"
    md = report_json_to_markdown(data)
    if args.markdown_out:
        Path(args.markdown_out).expanduser().write_text(md, encoding="utf-8")
    info = render_markdown_to_docx(md, output, prefer=args.engine or "auto")
    ok = bool(info.get("validation", {}).get("ok"))
    print(json.dumps({"status": "OK" if ok else "FAIL", **info}, indent=2, ensure_ascii=False))
    return 0 if ok else 1


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="report_docx.py",
        description="Evidence-based management report DOCX renderer and validator",
    )
    sub = p.add_subparsers(dest="command", required=True)

    s = sub.add_parser("self-check", help="Verify skill package and smoke-render a sample")
    s.set_defaults(func=command_self_check)

    r = sub.add_parser("render", help="Render JSON or Markdown to DOCX")
    r.add_argument("--input", help="Path to report JSON")
    r.add_argument("--markdown", help="Path to prepared Markdown")
    r.add_argument("--output", required=True, help="Output .docx path")
    r.add_argument("--engine", choices=["auto", "pandoc", "stdlib"], default="auto")
    r.set_defaults(func=command_render)

    v = sub.add_parser("validate", help="Validate DOCX package and mandatory sections")
    v.add_argument("--docx", required=True)
    v.set_defaults(func=command_validate)

    z = sub.add_parser("sanitize", help="Sanitize text for report inclusion")
    z.add_argument("--text", default="")
    z.add_argument("--file")
    z.set_defaults(func=command_sanitize)

    sp = sub.add_parser("sample", help="Generate a synthetic sample management report DOCX")
    sp.add_argument("--output", required=True)
    sp.add_argument("--markdown-out")
    sp.add_argument("--language", default="en")
    sp.add_argument("--engine", choices=["auto", "pandoc", "stdlib"], default="auto")
    sp.set_defaults(func=command_sample)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
