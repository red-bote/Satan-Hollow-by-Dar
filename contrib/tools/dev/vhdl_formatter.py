#!/usr/bin/env python3
"""Format VHDL files: 2 spaces per indent level, with optional column alignment.

Run with --help for options.
"""

import argparse
import os
import re
import sys


OPEN_KEYWORDS = {"if", "case", "loop", "generate", "process", "architecture", "block"}
CLOSE_KEYWORDS = {"if", "case", "loop", "process", "generate", "block", "architecture", "entity"}
FRAME_OF = {
    "if": "if",
    "case": "case",
    "loop": "loop",
    "generate": "generate",
    "process": "process",
    "architecture": "architecture",
    "block": "block",
}


def strip_comment(raw):
    """Return (code, comment). `--` comment stripped outside strings/char literals."""
    i = 0
    n = len(raw)
    while i < n:
        c = raw[i]
        if c == '"':
            i += 1
            while i < n and raw[i] != '"':
                i += 1
            i += 1
        elif c == "'":
            # char literal 'x' (3 chars) or attribute apostrophe
            if i + 2 < n and raw[i + 2] == "'":
                i += 3
            else:
                i += 1
        elif c == "-" and i + 1 < n and raw[i + 1] == "-":
            return raw[:i], raw[i:]
        else:
            i += 1
    return raw, ""


def tokenize(code):
    """Yield tokens (identifiers and single punctuation chars), skipping strings."""
    i = 0
    n = len(code)
    while i < n:
        c = code[i]
        if c == '"':
            i += 1
            while i < n and code[i] != '"':
                i += 1
            i += 1
        elif c == "'":
            if i + 2 < n and code[i + 2] == "'":
                i += 3
            else:
                i += 1
        elif c.isalnum() or c == "_":
            j = i
            while j < n and (code[j].isalnum() or code[j] == "_"):
                j += 1
            yield code[i:j]
            i = j
        elif c in "()<=>:;,":
            yield c
            i += 1
        else:
            i += 1


def paren_delta(tokens):
    opens = closes = 0
    for t in tokens:
        if t == "(":
            opens += 1
        elif t == ")":
            closes += 1
    return opens - closes


class Indenter:
    def __init__(self, indent):
        self.indent = indent
        self.stack = []
        self.depth = 0

    def classify(self, tokens):
        """Compute (print_level, paren_for_print) and mutate stack/depth."""
        openers = []
        closers = []
        branches = []
        prev_end = False
        i = 0
        n = len(tokens)
        while i < n:
            t = tokens[i]
            if t == "end":
                if i + 1 < n and tokens[i + 1] in CLOSE_KEYWORDS:
                    closers.append(tokens[i + 1])
                    i += 2
                    prev_end = False
                    continue
                closers.append(None)
                i += 1
                prev_end = True
                continue
            if t == "if":
                # opener if...then, unless preceded by end
                j = i + 1
                saw_then = False
                while j < n:
                    if tokens[j] == "then":
                        saw_then = True
                        break
                    j += 1
                if saw_then and not prev_end:
                    openers.append("if")
                i += 1
                prev_end = False
                continue
            if t == "case":
                openers.append("case")
                i += 1
                prev_end = False
                continue
            if t in ("loop", "generate", "block"):
                openers.append(t)
                i += 1
                prev_end = False
                continue
            if t == "process":
                openers.append("process")
                i += 1
                prev_end = False
                continue
            if t == "architecture":
                openers.append("architecture")
                i += 1
                prev_end = False
                continue
            if t in ("elsif", "else"):
                i += 1
                prev_end = False
                continue
            if t == "when":
                i += 1
                prev_end = False
                continue
            i += 1
            prev_end = False

        # Detect the controlling keyword (for single-line netting & begin/branch).
        first_kw = None
        for t in tokens:
            if t in OPEN_KEYWORDS or t in ("elsif", "else", "when", "end", "begin"):
                first_kw = t
                break

        # A `when`/`else`/`elsif` is a branch ONLY if it is the first token of the
        # line (case `when`, or `else`/`elsif` opening a new branch). Mid-line
        # `when ... else` (concurrent conditional assignment) is not a branch.
        first_tok = tokens[0] if tokens else None
        branch = first_tok if first_tok in ("else", "elsif", "when") else None

        # net: balanced inline blocks cancel; branch tokens are not counted.
        net = len(openers) - len(closers)

        # paren for this line
        delta = paren_delta(tokens)
        before = self.depth
        after = before + delta
        if delta > 0:
            paren_for_print = before
        else:
            paren_for_print = after

        # Determine print_level (before applying block changes) -----------------
        if first_kw == "begin":
            # begin aligns with its block keyword (base level); body stays +1.
            print_level = max(len(self.stack) - 1, 0)
        elif closers and len(openers) == 0:
            # pure closer: pop when-bodies above the target frame, then print at
            # the target frame's base level, then pop the target frame.
            target = closers[-1]
            while self.stack and self.stack[-1] == "when":
                self.stack.pop()
            if target is not None:
                while self.stack and self.stack[-1] != FRAME_OF.get(target):
                    self.stack.pop()
            print_level = max(len(self.stack) - 1, 0)
            if self.stack:
                self.stack.pop()
        elif openers and closers:
            # balanced single-line block (e.g. `if x then a; else b; end if;`):
            # net zero — ignore inline else/elsif/when, no stack change.
            print_level = len(self.stack)
        elif branch == "when":
            # case `when`: close any open when-body, sit at the case level, reopen.
            if self.stack and self.stack[-1] == "when":
                self.stack.pop()
            print_level = len(self.stack)
            self.stack.append("when")
        elif branch in ("else", "elsif"):
            # else/elsif: at the if base (body stays at +1).
            print_level = len(self.stack) - 1
        elif openers and not closers:
            # pure opener: print at current level then push
            print_level = len(self.stack)
            for op in openers:
                self.stack.append(op)
        else:
            # net 0 (balanced inline) or neither: no stack change
            print_level = len(self.stack)

        self.depth = after
        return print_level + paren_for_print


def format_lines(lines, indent, align):
    out = []
    ind = Indenter(indent)
    for raw in lines:
        if not raw.strip():
            out.append(raw)
            continue
        if raw.lstrip().startswith("--"):
            level = len(ind.stack)
            out.append(" " * (indent * level) + raw.lstrip())
            continue
        code, _ = strip_comment(raw)
        tokens = list(tokenize(code))
        level = ind.classify(tokens)
        out.append(" " * (indent * level) + raw.lstrip())
    if align:
        out = align_columns(out)
    return out


def align_columns(lines):
    """Align `<=` and `:` within contiguous runs of the same kind."""
    result = list(lines)
    runs = []
    current = []
    current_kind = None
    for idx, line in enumerate(result):
        if not line.strip() or line.lstrip().startswith("--"):
            if current:
                runs.append((current_kind, current))
                current = []
            current_kind = None
            continue
        kind, op_col = find_operator(line)
        if kind is None:
            if current:
                runs.append((current_kind, current))
                current = []
            current_kind = None
            continue
        if kind != current_kind:
            if current:
                runs.append((current_kind, current))
                current = []
            current_kind = kind
        current.append((idx, op_col))
    if current:
        runs.append((current_kind, current))

    for kind, members in runs:
        if len(members) < 2:
            continue
        target = max(op_col for _, op_col in members)
        for idx, op_col in members:
            line = result[idx]
            if op_col is None or op_col < 0:
                continue
            left = line[:op_col]
            rest = line[op_col:]
            new_left = left.rstrip().ljust(target)
            result[idx] = new_left + rest
    return result


def find_operator(line):
    """Return (kind, op_col) for the line's single top-level `<=` or `:` target."""
    code, _ = strip_comment(line)
    # skip `<=` comparison on if/elsif/while lines
    first = None
    m = re.match(r"^\s*(\w+)", code)
    if m:
        first = m.group(1)

    # find assignment `<=` positions (outside strings)
    assign_positions = []
    paren = 0
    i = 0
    n = len(code)
    while i < n - 1:
        c = code[i]
        if c == '"':
            i += 1
            while i < n and code[i] != '"':
                i += 1
            i += 1
            continue
        if c == "'":
            if i + 2 < n and code[i + 2] == "'":
                i += 3
                continue
            i += 1
            continue
        if c == "(":
            paren += 1
        elif c == ")":
            paren -= 1
        elif code[i] == "<" and code[i + 1] == "=" and paren == 0:
            assign_positions.append(i)
            i += 2
            continue
        i += 1

    if first in ("if", "elsif", "while"):
        assign_positions = []

    if len(assign_positions) == 1:
        return "assign", assign_positions[0]

    # declaration/port colon `\s*\w+\s*:`
    m = re.match(r"^(\s*\w+\s*):", code)
    if m:
        return "decl", len(m.group(1))

    return None, None


def format_text(text, indent, align):
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]
    formatted = format_lines(lines, indent, align)
    return "\n".join(formatted) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Format VHDL to a fixed spaces-per-indent-level, optionally aligning columns."
    )
    parser.add_argument("files", nargs="*", metavar="FILE")
    parser.add_argument("--check", action="store_true", help="report files that would change; exit 1 if any")
    parser.add_argument("--align", action="store_true", help="align `<=` and `:` columns")
    parser.add_argument("--indent", type=int, default=2, help="spaces per indent level (default 2)")
    args = parser.parse_args(argv)

    if not args.files:
        sys.stdout.write(format_text(sys.stdin.read(), args.indent, args.align))
        return 0

    changed = False
    for path in args.files:
        with open(path, "r", encoding="utf-8") as f:
            orig = f.read()
        new = format_text(orig, args.indent, args.align)
        if new != orig:
            changed = True
            if args.check:
                print(path, file=sys.stderr)
            else:
                tmp = path + ".tmp"
                with open(tmp, "w", encoding="utf-8", newline="") as f:
                    f.write(new)
                os.replace(tmp, path)
                print(path, file=sys.stderr)

    return 1 if (changed and args.check) else 0


if __name__ == "__main__":
    sys.exit(main())