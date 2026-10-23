---
name: journey
description: >-
  Conducts the UOB MSc and research journey: the weekly rhythm, coursework,
  knowledge base, papers, thesis, and experiments. Use when the user asks what
  to do this week, where a note or paper goes next, for a study session, or
  for thesis and experiment planning. Names the devices, obsidian, zotero, and
  anki skills for the actual read or write. Does not edit those tools itself.
---

# Journey

University of Bahrain MSc in Machine Learning and Computational Intelligence, plus the research that grows out of it. This skill decides the next artifact. The tool skills perform it.

Success order:

1. Digest the week's concepts and know strong versus weak areas.
2. Be ready for exams (midterm around week 8, finals early January).
3. Keep the ideas for the thesis, a later PhD, and the long term.

## Week

Week starts Saturday. Lecture days follow the course codes. The vault `Index.md` column titles swap "ML" and "Research" on Tuesday and Wednesday; ignore those titles.

| Day | Work |
|-----|------|
| Sat | Produce: assignments, coding, research, optional teaching recording |
| Sun | Prepare: next slides on the BOOX, red questions |
| Mon | ITML 601. Attend, black BOOX notes, then cards |
| Tue | ITML 603 Research Methodology. Same |
| Wed | ITML 602 Machine Learning. Same |
| Thu | Understand: BOOX notes into the vault, fill gaps, improve cards, mark concepts worth teaching |
| Fri | Master: problems, homework, exam prep, weak topics |

Deadline dates in the vault index are unconfirmed unless a brief prints them.

## Where work goes

**Lecture.** `Course-Material/`, then BOOX annotation, then a lecture note, then a knowledge-base note once the idea is settled, then Anki cards. The `obsidian` skill files the notes. The `anki` skill makes the cards.

**Paper.** Zotero item first (`zotero`). A reading note in `03-Papers/Reading-Notes` only when the user is reading it, with the Zotero item key (`obsidian`). Knowledge-base notes and Anki cards only if the user asks.

**Thesis and experiments.** `04-Projects-and-Research/` in the vault. Papers that support them still enter through Zotero.

**Teaching.** Optional exit into `05-Teaching-and-YouTube` (Ideas, then Scripts, then Published). Not its own tool. A card flag `flag::teach` or a Thursday "worth teaching" mark can start an idea note.

## How to hand off

1. Resolve the host with the `devices` skill when a tool will be touched.
2. Say which skill does the next step, then follow that skill.
3. Do not write the vault, the library, or the Anki collection from this skill.
4. The BOOX is not connected. Do not plan a sync that has no path. Captures already in the inbox are an Obsidian filing job.

## Do not

- Restate deck rules, tag catalogs, folder trees, or API calls that belong to the tool skills.
- Treat teaching as a peer of Anki, Obsidian, or Zotero.
- Switch Anki to Exam Mode except during the one to two weeks before a midterm or final. The `anki` skill owns that switch.
