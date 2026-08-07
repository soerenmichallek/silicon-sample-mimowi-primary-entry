# Silicon Sample Benchmark — method registration form

Fill in every item before the prediction lock; this file ships inside your repo's Zenodo release
(see the README's *Deposit* step). This form covers **one entry** (one repo / one Zenodo release,
`primary` or `secondary-k` — see the README's *What counts as a submission*); if you submit several
entries, fill one form per entry. Items marked **★**
must be disclosed **fully publicly** (never escrowed or withheld). Items marked **†** must be at
minimum escrowed — they may be sealed from the public, but never withheld from the core team. Items
not applicable to your approach: write `N/A`. When several models serve different pipeline stages, complete the model
sections (B) once per model. See the call's *Disclosure policy* for escrow rules.

---

## 0 · Approach identity and output
- **0.1 Team ★** — name, the one or two members (teams are at most two, unless a larger team was approved on request), affiliations, corresponding contact: names: Sören Michallek, Sophie Möller, Tobias Wingen; affiliations: FernUniversität in Hagen; corresponding contact: soeren.michallek@fernuni-hagen.de
- **0.2 Plain-language summary ★** — one paragraph, what the approach does (not how): In this approach we model a low-barrier-of-entry workflow using a standardized prompting procedure. We use a large language model to independently predict the average treatment effect for every intervention–outcome combination in the study. For each combination, the model produces five separate forecasts, and the median of these forecasts is used as the final submitted prediction. The model receives only the descriptions of the intervention, the control condition, the study sample, and the outcome, and returns a single quantitative estimate of the expected treatment effect.
- **0.3 Submission tier & approach family ★** — tier (1/2/3); family (e.g. per-respondent simulation / agent / direct forecast; single model / ensemble / multi-agent; zero-shot / literature-conditioned): tier 3; family: direct forecast
- **0.4 Pipeline diagram** — ordered steps from raw inputs to submitted file: Loading raw study inputs; input validation/configuration; prompt construction; request generation; model inference; raw response archival; prediction extraction/transformation; creation of trial-level prediction file; aggregation across forecasts; submission file generation; run artifact archival.
- **0.5 Coverage ★** — number of respondents/cells/estimates; mapping to conditions. Full coverage is required: every submission predicts **all 16 interventions and all 13 outcomes** (partial coverage is not accepted). Confirm here: Full coverage has been achieved.

## A · Scope of LLM use
- **A.1 Purpose** — every workflow stage where LLMs are used: LLMs are used to: handle and process requests; generate outcomes in the required format.
- **A.2 Degree of automation ★** — confirm fully automated, no human in the loop at prediction time; note any exception: the approach was fully automated.

## B · Model / system details (once per model)
- **B.1 Model name(s)** — exact identifiers incl. provider, size, version/timestamp, source link: claude-fable-5 by Anthropic; size unknown; version: not explicitly disclosed by the provider, only the alias claude-fable-5 is provided; source: https://platform.claude.com/docs/en/about-claude/models/overview; 
- **B.2 Access & context mode** — API/web/local; API name + version; chat vs stateless; exact call dates: API; Anthropic Messages API; version 2023-06-01; https://api.anthropic.com/v1/messages; stateless; run starttime: 2026-08-04 14:58:25 UTC, run endtime: 2026-08-04 15:16:50 UTC.
- **B.3 Configuration** — temperature, top-p/top-k, max tokens, penalties, stop sequences, seeds, reasoning effort, completions per item: since we used a proprietary model by Anthropic, most of these parameters are unknown to us. max tokens: 8192; reasoning effort: "high"; completions per item: 5.
- **B.4 Customization** — fine-tuning, RAG, prompt optimization, tool use, web search, agentic scaffolds (cross-ref H): no customization steps were employed.
- **B.5 Persistent memory** — across interactions? what persisted: no persistent memory was used.
- **B.6 Inference stack** — for local models: serving framework + version, quantization, hardware: NA
- **B.7 Ensembles** — members + exact aggregation rule: NA

## C · Prompts
- **C.1 Exact prompts** — verbatim text or link to deposited file; were they iteratively refined? pre-specified vs in response to outputs: the prompt text can be found in scripts\mimowi_T3_final_Fable_submission.R, while an overview over each request we sent (including the prompt) can be found in frozen_artifacts\request_manifest.csv.
- **C.2 System-wide instructions**: NA
- **C.3 Prompt-design rationale** — brief rationale for the prompt design: why prompts were structured as they were, and the reasoning behind major design choices (recommended, not required):

## D · Persona / profile construction (Tiers 1–2)
- **D.1 Profile source** — source of demographic profiles you constructed: a public survey (e.g. GSS / ANES / Census), other survey, fully synthetic, or none. The benchmark ships no participant pool; report how you built yours, incl. condition assignments: NA
- **D.2 Profile verbalization** — which variables, rendered how (template vs generated narrative; if generated: model + prompt): NA
- **D.3 Assignment & weighting** — number of personas, assignment to conditions (your responsibility, all 17 conditions), reuse, weighting/matching: NA

## E · Stimulus and survey administration
- **E.1 Stimulus presentation** — verbatim vs paraphrase; how state-contingent content is handled: Stimuli were presented verbatim from the frozen frozen_artifacts\conditions.csv, frozen_artifacts\outcomes.csv, and frozen_artifacts\study_constants.csv input files. Each API call received the same template prompt containing the control condition, one intervention condition, the sample description, and one outcome description. No paraphrasing, summarization, or dynamic modification of the experimental materials was performed; state-contingent or adaptive content was not used.
- **E.2 Survey walk-through** — one item/call vs blocks vs whole survey; context carry-over; item/option ordering & randomization; scale display; attention/comprehension handling: Each intervention–outcome pair was evaluated in a separate, independent API call (16 interventions × 13 outcomes × 5 repeated forecasts = 1,040 total calls). Each call contained only a single intervention and a single outcome, with no carry-over of context, conversation history, or persistent memory. Intervention and outcome order followed the ordering of the input files, and no randomization of stimuli or response options was used. No attention checks, or comprehension checks were presented.
- **E.3 Response elicitation** — free text / constrained choice / structured output / token log-probabilities (if logprobs: normalization & mapping): Responses were elicited using structured output. The model was instructed to return exactly one numeric estimate in a JSON object (ate_pp) conforming to a JSON schema. The estimate represented the average treatment effect in percentage points of the outcome's full scale range (−100 to 100).

## F · Stochasticity and aggregation
- **F.1 Runs & seeds** — runs per respondent/item/estimate; seeds; reproducibility under identical settings: no seed was set. We used Anthropic's API, meaning that attempts at reproducing the predictions will likely yield very similar, but not identical outcomes. Each individual request is documented under frozen_artifacts\request_manifest.csv.
- **F.2 Aggregation rule** — how multiple generations become submitted values (mean/median/mode/first/sampled/…): computation of median of the five values per outcome-intervention pair.

## G · Validation & post-processing
- **G.1 Human validation** — any human review of outputs (often N/A): no human validation besides a sanity check of the correct outcome format (i.e., validating that the generated .csv indeed contains the needed information for the submission)
- **G.2 Post-processing** — parsing rules; handling of refusals/malformed/missing/out-of-range; exclusions; for approaches that generate individual responses, the resulting effective N per condition (descriptive disclosure, not a scoring input): NA
- **G.3 Calibration corrections** — any post-hoc scaling/shifting/debiasing and exactly what data it was fit on (cross-ref H/I): NA

## H · Learning and conditioning components
- **H.1 Fine-tuning data** — exact corpus (hashes/DOIs), hyperparameters, checkpoints:
- **H.2 Context & retrieval corpora** — exact document set in context / indexed, archived in the deposit: the model was given a description of the conditions (frozen_artifacts\conditions.csv) and outcomes (frozen_artifacts\outcomes.csv), as well as a summary of the control condition and the sample, definitions of ate and a description of the scale (frozen_artifacts\study_constants.csv).

## I · Data inputs, blinding, and competing interests
- **I.1 Competing interests ★** — funding, in-kind compute/model access, relationships with LLM-interested entities: NA
- **I.2 External human data †** — all external human datasets that informed the approach anywhere (training/fine-tuning/retrieval/ICL/calibration): NA
- **I.3 Blinding attestation ★** — **mandatory.** Signed attestation that no team member accessed, solicited, or was shown any human outcome data from this study, including pilots, before the prediction lock: We confirm that the blinding protocol was strictly maintained without any exception. Signed on behalf of all authors by: Sören Michallek on 07.08.2026.
- **I.4 Contamination note †** — training cutoff of every model vs public release dates of this project's materials; note any known exposure: training cutoff for Claude-Fable-5 was January 2026. Public release of this project's materials is 06.08.2026.

## J · Internal selection procedure
- **J.1 Design-space search †** — how the final pipeline was chosen: how many configurations tried, internal validation criterion, what data it ran against: The idea for the pipeline stems from the HaGenAi project (https://osf.io/preprints/psyarxiv/m8p42_v1), which aimed at investigating the performance of LLM-based predictions of research results with a simple systematic prompting approach. While the general pipeline for this project was the same from the start, the exact prompt sent to the model was iteratively improved until a legible outcome was generated that conformed to all requirements for the submission. The R code was developed with assistance from ChatGPT 5.6 Sol High. All code, workflows, and associated materials were independently reviewed by the author team. The authors retain full responsibility for the accuracy, integrity, and performance of the implemented code and the resulting predictions.

## K · Reproducibility & frozen artifacts
- **K.1 Code & materials** — link/DOI, secrets removed, determinism/seeds documented (also record the link in `metadata.json` → `code_repository` / `code_doi`):
- **K.2 Raw output logs †** — complete unprocessed model responses archived, hashed, time-stamped (required for Tiers 1–2, public or escrowed; Tier 3 where intermediate generations exist; oversized logs may be a separate linked Zenodo upload): see raw_data_deposit\raw_responses for the raw responses and raw_data_deposit\raw_response_hashes.csv for the hashes
- **K.3 Computational resources** — API-call counts, total tokens, cost, compute time: API-call count = 1040; total tokens = 873.163; cost = $11.6414; compute time: 1104,8813 seconds

## L · Disclosure class
Each item above is deposited as **public**, **escrowed** (sealed from the public but available to the
core team and auditors under confidentiality, with a public SHA-256 hash + timestamp so the lock is
still verifiable — an embargo with a sunset date is encouraged), or **withheld** (permitted only for
items marked neither ★ nor †). Your entry's class is set by its **most restricted item** and recorded
in `metadata.json` → `disclosure_class` (and `escrow_doi` if anything is escrowed):
- **A · Open** — all items public. Full results-table standing; all features enter the design-choice analysis.

★ items must always be public (never escrowed or withheld); † items must be at minimum escrowed. Full
policy: <https://janpfander.github.io/llm_predictions_megastudy/#disclosure>
