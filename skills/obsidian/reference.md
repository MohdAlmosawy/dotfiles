# Obsidian vault — reference

Vault: `6-AI-Master-UOB`, path from the `devices` skill.

Folder names use hyphens and contain no spaces. `&` is written `and`. LuaTeX drops a font file whose path contains a space, so a new folder in this vault follows the same rule.

## Top level

| Folder | What belongs here |
|--------|-------------------|
| `00-Inbox` | Unsorted captures. File them out |
| `01-MSc-UOB` | Admission archive and the current semester |
| `02-Knowledge-Base` | Permanent notes, by subject |
| `03-Papers` | `To-Read`, `Reading-Notes`, `Literature-Maps` |
| `04-Projects-and-Research` | `MSc-Research-Ideas`, `Experiments`, `Thesis` |
| `05-Teaching-and-YouTube` | `Ideas`, `Scripts`, `Published` |
| `90-Resources` | Shared reference material, including `UOB-LaTeX/` |
| `99-Archive` | Retired notes |

Semester courses live under `01-MSc-UOB/Semester-1-2026/`:

- `ITML601-AI-and-NLP`
- `ITML602-Machine-Learning`
- `ITML603-Research-Methodology`

Each course has `Course-Material/`, `Lectures/`, `Assignments/`, `Exam-Prep/`, and `TextBooks/`. ITML 601 also has `Lab/`.

Knowledge base subjects: `Artificial-Intelligence`, `NLP`, `Machine-Learning`, `Deep-Learning`, `Mathematics`, `Computer-Science`, `Research-Methods`.

## Lecture pipeline

1. Lecturer files go in that course's `Course-Material/`.
2. The student annotates slides on the BOOX. Red ink is Sunday prep (questions). Black ink is live lecture notes.
3. The write-up is `Lectures/L01 - ….md` inside the course.
4. A settled concept can become a note under `02-Knowledge-Base/`.
5. Anki cards are a later exit, handled by the `anki` skill, and only after a proposed change is accepted.

## Reading note

Create under `03-Papers/Reading-Notes/` when the user is actually reading. Include the Zotero item key. Do not copy the PDF into the vault when Zotero already stores it.

Dashboard for the semester: `Index.md` at the vault root. Deadline dates in that file are unconfirmed unless a brief prints them.

## LaTeX

Shared template: `90-Resources/UOB-LaTeX/template.tex`. Times New Roman is the four files in `90-Resources/UOB-LaTeX/fonts/` (`Times.TTF`, `Timesbd.TTF`, `Timesbi.TTF`, `Timesi.TTF`). Point `fontspec` at that folder. Do not use a system font path, and do not put a second copy of the font elsewhere in the vault.

Build with LuaLaTeX, then Biber, then LuaLaTeX again. On the AlSalam PC, Cursor's LaTeX Workshop recipe is `latexmk (lualatex)`. The plain latexmk recipe uses pdfLaTeX, which cannot load this template. The laptop editor is TeXstudio. The `devices` skill checks the commands, the vault fonts, and the Cursor extension on the current host.
