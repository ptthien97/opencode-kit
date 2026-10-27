#!/usr/bin/env python3
"""Contract tests for management-report-docx skill CLI."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import report_docx as rd  # noqa: E402

SKILL_ROOT = Path(__file__).resolve().parents[1]


class TestSkillPackage(unittest.TestCase):
    def test_skill_frontmatter_discoverable(self) -> None:
        skill = (SKILL_ROOT / "SKILL.md").read_text(encoding="utf-8")
        self.assertTrue(skill.startswith("---"))
        self.assertIn("name: management-report-docx", skill)
        self.assertIn("description:", skill)
        self.assertTrue("docx" in skill.lower() or "Word" in skill)
        desc_line = next(ln for ln in skill.splitlines() if ln.startswith("description:"))
        self.assertGreater(len(desc_line), 40)
        self.assertTrue((SKILL_ROOT / "references" / "report-protocol.md").is_file())
        self.assertTrue((SKILL_ROOT / "references" / "report-template.md").is_file())

    def test_usage_guidance_and_git_example(self) -> None:
        skill = (SKILL_ROOT / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("Example:", skill)
        self.assertIn("git log", skill.lower())
        self.assertIn("report_docx.py", skill)


class TestSanitizer(unittest.TestCase):
    def test_redacts_private_key_and_token(self) -> None:
        raw = (
            "key=-----BEGIN PRIVATE KEY-----\nABC\n-----END PRIVATE KEY-----\n"
            "token=ghp_abcdefghijklmnopqrstuvwxyz012345\n"
            "password: supersecretvalue99\n"
        )
        cleaned, tags = rd.sanitize_text(raw)
        self.assertIn("[REDACTED]", cleaned)
        self.assertNotIn("BEGIN PRIVATE KEY", cleaned)
        self.assertNotIn("ghp_abcdefghijklmnopqrstuvwxyz012345", cleaned)
        self.assertTrue(
            any(t in tags for t in ("private_key", "github_pat", "generic_api_key_assign"))
        )

    def test_bounds_oversized_diff(self) -> None:
        lines = ["diff --git a/x b/x"] + [f"+line {i}" for i in range(80)]
        cleaned, tags = rd.sanitize_text("\n".join(lines), max_chars=5000)
        self.assertTrue("oversized_dump" in tags or "truncated" in tags or "truncated" in cleaned.lower())
        self.assertLess(len(cleaned.splitlines()), 80)


class TestMarkdownAndRender(unittest.TestCase):
    def test_json_to_markdown_has_mandatory_headings(self) -> None:
        md = rd.report_json_to_markdown(rd.sample_report_data())
        for heading in rd.DEFAULT_HEADINGS_EN.values():
            self.assertIn(f"## {heading}", md)
        self.assertIn("| ID | Type | Reference |", md)
        self.assertIn("a1b2c3d", md)
        self.assertIn("Fact:", md)
        self.assertIn("Analysis:", md)
        self.assertIn("Limitation:", md)

    def test_vietnamese_headings(self) -> None:
        data = rd.sample_report_data()
        data["language"] = "vi"
        data["title"] = "Báo cáo tiến độ"
        md = rd.report_json_to_markdown(data)
        self.assertIn("## Tóm tắt điều hành", md)
        self.assertIn("## Bằng chứng có thể kiểm chứng", md)

    def _assert_valid_report(self, path: Path) -> dict:
        self.assertTrue(path.is_file())
        with zipfile.ZipFile(path, "r") as zf:
            names = zf.namelist()
            self.assertIn("[Content_Types].xml", names)
            self.assertIn("word/document.xml", names)
        result = rd.validate_docx(path)
        self.assertTrue(result["ok"], msg=json.dumps(result, indent=2))
        self.assertEqual(result["missingSections"], [])
        text, headings = rd.extract_docx_text_and_headings(path)
        self.assertIn("a1b2c3d", text)
        joined_headings = " ".join(headings).lower()
        self.assertTrue(
            "evidence" in joined_headings
            or "bằng chứng" in " ".join(headings).lower()
            or "Verifiable Evidence" in text
            or "Bằng chứng" in text
        )
        self.assertNotIn("BEGIN PRIVATE KEY", text)
        self.assertTrue("Fact" in text or "Sự kiện" in text)
        return result

    def test_sample_render_pandoc_or_stdlib(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgmt-test-") as tmp:
            out = Path(tmp) / "management-report-2026-07-20.docx"
            md = rd.report_json_to_markdown(rd.sample_report_data())
            info = rd.render_markdown_to_docx(md, out, prefer="auto")
            self.assertIn(info["engine"], {"pandoc", "stdlib-ooxml"})
            self._assert_valid_report(out)

    def test_stdlib_fallback_engine(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgmt-test-std-") as tmp:
            out = Path(tmp) / "management-report-2026-07-20-stdlib.docx"
            md = rd.report_json_to_markdown(rd.sample_report_data())
            info = rd.render_markdown_to_docx(md, out, prefer="stdlib")
            self.assertEqual(info["engine"], "stdlib-ooxml")
            self._assert_valid_report(out)

    def test_validate_detects_missing_section(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgmt-test-miss-") as tmp:
            out = Path(tmp) / "bad.docx"
            md = "# Title\n\n## Executive Summary\nOnly one section\n"
            rd.render_markdown_to_docx(md, out, prefer="stdlib")
            result = rd.validate_docx(out)
            self.assertFalse(result["ok"])
            self.assertGreaterEqual(len(result["missingSections"]), 1)

    def test_sample_discloses_gaps_and_avoids_release_claim(self) -> None:
        md = rd.report_json_to_markdown(rd.sample_report_data())
        self.assertIn("No production release evidence", md)
        self.assertNotRegex(md.lower(), r"\breleased to production\b")
        self.assertIn("Limitation:", md)

    def test_cli_self_check_and_sample(self) -> None:
        rc = rd.main(["self-check"])
        self.assertEqual(rc, 0)
        with tempfile.TemporaryDirectory(prefix="mgmt-cli-") as tmp:
            out = Path(tmp) / "management-report-2026-07-20.docx"
            rc2 = rd.main(["sample", "--output", str(out), "--engine", "stdlib"])
            self.assertEqual(rc2, 0)
            rc3 = rd.main(["validate", "--docx", str(out)])
            self.assertEqual(rc3, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
