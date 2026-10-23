---
name: uob-tex
description: >-
  Formats University of Bahrain LaTeX on the graduate thesis-guide page
  (A4, Times-like type, 1.5 spacing, UOB margins and heading sizes) with
  APA 7th edition citations through biblatex-apa and a Better BibTeX
  export. Use when creating or editing a .tex file for UOB, a thesis, a
  coursework paper, or when the user mentions UOB formatting, APA
  references, Biber, or a Zotero bibliography.
---

# UOB LaTeX

English course papers and theses for the University of Bahrain. The page follows دليل كتابة الأطروحات العلمية (عمادة الدراسات العليا, 2014). Citations and the reference list follow APA 7th edition.

If the file is in the AI-Master vault, the `obsidian` skill still decides where it lives. This skill only owns `.tex` formatting.

## Before editing

Read the `.tex` file. If it already uses the preamble below, keep that preamble and change only what the user asked for. Do not restyle it onto `apa7` or pdfLaTeX.

A new English paper starts from the vault template `90-Resources/UOB-LaTeX/template.tex`. Resolve the vault with the `devices` skill. Copy `template.tex`, `references.bib`, and `uob-logo.png` into the paper's folder. Do not put that template inside a course folder. The preamble below is the same file. Do not copy placeholder prose from an old assignment into a new paper.

## Page

| Item | Set |
| --- | --- |
| Paper | A4 |
| Margins | left and right 3.17 cm; top and bottom 2.54 cm |
| Body | 14 pt, regular, black |
| Abstract | 12 pt, no first-line indent, at most one page |
| Headings | 20 pt centred; 18 pt flush left; 16 pt flush left. All bold. Unnumbered |
| Spacing | 1.5 (`\onehalfspacing`) |
| Paragraphs | justified; first line indented 1.5 cm |
| Page number | bottom centre, no parentheses (`\pagestyle{plain}`). The cover uses `\thispagestyle{empty}`, so its number is not printed |
| Type | Times New Roman, loaded with `fontspec` |

APA 7 student papers use double spacing, 12 pt, 1-inch margins, and a top-right page number. Do not switch a UOB file to that page. APA wins only for citations, the reference list, and table and figure captions.

Do not use the `titlepage` environment. On a one-sided article it resets the page counter, so the title page and the next page are both page 1.

## Preamble

```latex
% !TEX program = lualatex
% !BIB program = biber
\documentclass[14pt,a4paper]{extarticle}
\usepackage{fontspec}
\setmainfont{Times New Roman}[
  Path = /usr/share/fonts/truetype/msttcorefonts/,
  UprightFont = times.ttf,
  BoldFont = timesbd.ttf,
  ItalicFont = timesi.ttf,
  BoldItalicFont = timesbi.ttf
]
\usepackage[american]{babel}
\usepackage{csquotes}
\usepackage{setspace}
\usepackage{geometry}
\usepackage{titlesec}
\usepackage[style=apa,sortcites=true,backend=biber]{biblatex}
\usepackage{booktabs}
\usepackage[hidelinks]{hyperref}
\addbibresource{references.bib}
\geometry{a4paper,left=3.17cm,right=3.17cm,top=2.54cm,bottom=2.54cm}
\onehalfspacing
\setlength{\parindent}{1.5cm}
\pagestyle{plain}
\titleformat{\section}{\centering\normalfont\bfseries\fontsize{20}{24}\selectfont}{}{0pt}{}
\titleformat{\subsection}{\raggedright\normalfont\bfseries\fontsize{18}{22}\selectfont}{}{0pt}{}
\titleformat{\subsubsection}{\raggedright\normalfont\bfseries\fontsize{16}{20}\selectfont}{}{0pt}{}
\setlength{\bibhang}{1.27cm}
\defbibheading{bibliography}[\refname]{%
  \clearpage
  \begin{center}{\normalfont\bfseries\fontsize{20}{24}\selectfont #1\par}\end{center}
  \vspace{1em}%
}
```

Heading spacing may be added with `\titlespacing*`. Keep the sizes above.

## Citations

Bibliography file beside the `.tex` file, named `references.bib` unless one already exists. When the sources are in Zotero, that file is a Better BibTeX auto-export in Better BibLaTeX format. Do not hand-edit it. Cite its citation keys. A source that is not in Zotero yet goes to the `zotero` skill first. The Zotero item key is not a citation key.

- Narrative: `\textcite{key}`
- Parenthetical: `\parencite{key}`
- Quotation: `\parencite[p.~4]{key}` — page or paragraph required
- Three or more authors: APA 7 prints "et al." from the first citation
- Two authors: "and" in the sentence, `\&` in parentheses
- Several works in one parenthesis: alphabetical, separated by semicolons
- A quotation of 40 or more words: indent as a block quote, no quotation marks, citation after the final full stop
- Print a reference only when it is cited. Do not invent given names; use the initials on the source

Entry patterns: [reference.md](reference.md).

## Course paper and thesis

A course paper has a centred title page. The vault template already prints University of Bahrain, College of Information Technology, Department of Computer Science, M.Sc. in Machine Learning and Computational Intelligence, Sayed Mohamed Aqeel Ebrahim, and student ID 20101969. Replace only the paper title, the course, the instructor, and the date. An abstract with an italic *Keywords:* line follows when the paper uses one, then the body, then `\printbibliography`.

A thesis adds the front matter and back matter in [reference.md](reference.md). Do not add those pages to a course paper unless the user asks.

## Build

LuaLaTeX, then Biber, then LuaLaTeX. The magic comments above make LaTeX Workshop select that recipe. An empty reference list warns that the bibliography is empty until the first citation; that warning is expected.

pdfLaTeX cannot load Times New Roman. Do not compile an English UOB file with pdfLaTeX.

## Arabic thesis

Only when the thesis language is Arabic: Simplified Arabic, single spacing, bold titles, subheadings aligned right, and XeLaTeX or LuaLaTeX. Load `geometry` and `hyperref` before `polyglossia` (the `bidi` package errors otherwise). English UOB files stay on the preamble above.
