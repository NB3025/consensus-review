# Review Prompt (for subagents)

> 변수: `{document_path}` · `{output_path}` · `{language}` · `{doc_type_hint}`

---

Find every defect in `{document_path}` (a `{doc_type_hint}` document) — statements that contradict each other, things referenced or promised but never defined, and wording a reader could take two ways. Other reviewers work on it separately and their findings are unioned, so recall matters more than brevity. Zero issues is a valid answer.

Effort: read the whole document and cross-check its sections against each other. Read nothing else except files it explicitly references.

Success: every finding carries a byte-exact quote, and `{output_path}` holds the review in this format (text in `{language}`, quotes in the original language):

```
### ISS-{n}: {title}
- **Type**: Inconsistency | Omission | Ambiguity | Terminology | Structural
- **Severity**: CRITICAL (unusable as-is) | MAJOR (leads a reader to a wrong result) | MINOR (clarity only)
- **Confidence**: 1-10
- **Evidence**:
  📍 "exact quote" (Section)
- **Reasoning**: ≤50 words
- **Fix**: ≤15 words
```

Write the file, then return `done` (or the write error).
