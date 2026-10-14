"""Fingerprint V8 intacto; V9 incorpora somente respostas da fonte atual."""

import hashlib
import json


def source_hash(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def clarifications_current(report):
    return bool(
        report
        and getattr(report, "clarifications_source_hash", None) == source_hash(report.original_text)
    )


def current_clarifications(report):
    if not clarifications_current(report):
        return []
    return sorted(
        (
            row
            for row in report.clarifications
            if row.source_hash == report.clarifications_source_hash
        ),
        key=lambda row: row.position,
    )


def answered_context(report):
    return [
        {
            "question_text": row.question_text,
            "answer_kind": row.answer_kind,
            "answer_text": row.answer_text,
        }
        for row in current_clarifications(report)
        if row.answer_kind is not None
    ]


def organization_source_hash(report):
    answers = answered_context(report)
    if not answers:
        return source_hash(report.original_text)
    canonical = json.dumps(answers, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return source_hash("v9\n" + report.original_text + "\n" + canonical)
