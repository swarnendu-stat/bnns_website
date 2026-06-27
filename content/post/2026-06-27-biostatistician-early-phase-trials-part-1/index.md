---
title: "A Biostatistician in Early Phase Trials — Part 1"
author: "Swarnendu Chatterjee"
date: "2026-06-27T09:00:00+0530"
slug: biostatistician-early-phase-trials-part-1
categories: ["Clinical Trials", "Biostatistics"]
tags: ["clinical trials", "biostatistician", "early phase", "drug development"]
description: "What a statistician actually does in an early-phase clinical trial — and why the hardest part happens long before the data arrives. Part 1 of a series."
---

It's almost 9 PM, and the safety review call starts in ten minutes. The numbers on my screen don't agree with what the clinical team is about to say.

There are eight patients in the cohort: six on active, two on placebo. One patient on active had a mild lab abnormality that resolved on its own. Across the cohort, the rate is still within what we pre-specified as acceptable, so the rule says proceed to the next dose. The principal investigator has a feeling that says slow down.

Neither read is wrong. That's the part people don't expect.

A lot of my work is about making decisions when a single number isn't enough to trust. It's the reason I built [`bnns`](https://swarnendu-stat.github.io/bnns/), where the output carries its uncertainty with it instead of reporting a clean point estimate. A Phase I safety review is the same problem in a simpler form: very little data, a real decision, and no honest way to remove the uncertainty.

This is a Phase I trial, first-in-human. No one has been given this molecule at this dose before. There is no efficacy signal yet and no large sample to average away the noise. Every cohort carries a placebo arm so that any signal we see isn't just an artifact of attention or coincidence. Every data point is a person, and the decision about the next dose rests on a design that was fixed in the protocol months earlier.

In the next ten minutes I have to either defend what the design says, or explain why it might be missing something it was never built to see.

## What people think the job is

Ask most people what a biostatistician does on a clinical trial, and you'll get some version of "runs the numbers after the data comes in." Tests for significance, builds a table, writes a report.

That's part of it. It is not the part that matters most in early-phase work.

## What the job actually is

By the time that 9 PM call happens, the real work is already months old. In a lot of non-oncology, non-vaccine first-in-human work, the design is a cohort-based 6+2 structure: six patients on active, two on placebo, reviewed together before anyone moves to the next dose. The statistician's job starts long before the first patient is dosed:

- Choosing the 6+2 cohort itself: what it buys you in interim safety review, and why pairing active with placebo in every cohort matters even when efficacy isn't the question yet.
- Pre-specifying what a cohort's safety data has to look like to justify moving on, what triggers a pause, and what falls into the grey zone that needs a human in the room.
- Pressure-testing that stopping logic with simulation, so everyone knows how the design should behave before real data arrives.
- Translating pharmacological priors and clinical judgment into review criteria the protocol can commit to in writing, weeks before anyone sees a borderline result.

None of that shows up in a results table. All of it shows up at 9 PM, when the design and the room have to agree on what happens next.

## Why this moment is hard

A cohort safety review in a Phase I trial is not a hypothesis test. It's closer to a decision made with very little data, where the cost of being wrong in either direction is a person.

Proceed too cautiously, and the trial drags on. Useful dose levels go untested, and a potentially effective regimen takes longer to reach the patients who need it.

Proceed too readily, and you risk missing a real signal that a more careful read of the cohort, placebo included, would have caught.

The design exists to make that decision defensible. It doesn't remove the judgment; it gives the judgment some structure to stand on. On a good day, the design and the clinical instinct agree. On a harder day, like this one, they don't, and the statistician's job is to know exactly why the cohort data says what it says: well enough to trust it under pressure, or to explain its blind spot in real time.

## Coming up

That's the part of the job nobody sees: not the code and not the report, but the structure built weeks in advance that has to hold up in a single tense conversation.

In Part 2, I'll open up that structure. We'll walk through a 6+2 active-plus-placebo cohort design with R code and dummy data, simulate and review a cohort, and see how that design would have informed the decision in tonight's call.

💬 If you've sat on either side of a call like this, the design side or the clinical side, I'd love to hear how you read it. Share your take on [LinkedIn](https://www.linkedin.com/in/swarnendu-stat/) and tag [me](https://www.linkedin.com/in/swarnendu-stat/).

*This post describes a composite, anonymized scenario representative of early-phase trial work, not any specific trial or patient.*