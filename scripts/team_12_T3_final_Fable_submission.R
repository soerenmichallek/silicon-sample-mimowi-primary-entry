# =============================================================================
# Claude direct-effect forecasts — submission and disclosure version
#
# Design:
#   16 interventions x 13 outcomes x 5 independent forecasts
#
# Required packages:
#   httr2, jsonlite, digest
#
# Required files in the working directory:
#   conditions.csv
#   outcomes.csv
#   study_constants.csv
#
# Required environment variable:
#   ANTHROPIC_API_KEY
#
# Main outputs:
#   predictions/<team_id>_T3_<entry>_v1.csv
#   run_artifacts/<timestamp>/
# =============================================================================

library(httr2)
library(jsonlite)
library(digest)


# -----------------------------------------------------------------------------
# Submission settings
# -----------------------------------------------------------------------------

team_id <- "mimowi"
entry <- "primary"

model <- "claude-fable-5"
model_source <- "https://platform.claude.com/docs/en/about-claude/models/overview"
model_training_data_cutoff <- "January 2026"
endpoint <- "https://api.anthropic.com/v1/messages"
anthropic_version <- "2023-06-01"

n_trials <- 5L
max_active_requests <- 5L
max_tokens <- 8192L
reasoning_effort <- "high"

# Claude Fable 5 standard synchronous pricing on 2026-08-04
input_price_per_million <- 10
output_price_per_million <- 50
pricing_source <- "https://platform.claude.com/docs/en/about-claude/pricing"

api_key <- Sys.getenv("ANTHROPIC_API_KEY")

if (!nzchar(api_key)) {
  stop("ANTHROPIC_API_KEY was not found.")
}


# -----------------------------------------------------------------------------
# Read frozen study inputs
# -----------------------------------------------------------------------------

conditions <- read.csv(
  "conditions.csv",
  fileEncoding = "UTF-8-BOM",
  stringsAsFactors = FALSE,
  check.names = FALSE
)

outcomes <- read.csv(
  "outcomes.csv",
  fileEncoding = "UTF-8-BOM",
  stringsAsFactors = FALSE,
  check.names = FALSE
)

study_constants <- read.csv(
  "study_constants.csv",
  fileEncoding = "UTF-8-BOM",
  stringsAsFactors = FALSE,
  check.names = FALSE
)

control_summary <- study_constants$value[
  study_constants$key == "control_summary"
]

sample_summary <- study_constants$value[
  study_constants$key == "sample_summary"
]

stopifnot(
  team_id != "REPLACE_WITH_TEAM_ID",
  model == "claude-fable-5",
  n_trials == 5L,
  max_tokens == 8192L,
  reasoning_effort == "high",
  nrow(conditions) == 16L,
  nrow(outcomes) == 13L
)


# -----------------------------------------------------------------------------
# Prompt and API request
# -----------------------------------------------------------------------------

make_prompt <- function(condition_summary, outcome_description) {
  paste0(
    "You are asked to predict the results of a real experiment involving two ",
    "conditions described below. Provide your best estimate of the exact average ",
    "treatment effect of Condition 2 relative to Condition 1 on the dependent ",
    "variable, expressed in percentage points of the dependent variable's full ",
    "scale range. You must provide exactly one signed numeric value, with no range ",
    "or uncertainty. A positive value means that Condition 2 produces a higher ",
    "score than Condition 1, and a negative value means that Condition 2 produces ",
    "a lower score. Return the estimate in the JSON field ate_pp and provide no ",
    "other information.\n\n",
    "Condition 1: ", control_summary, "\n\n",
    "Condition 2: ", condition_summary, "\n\n",
    "Sample: ", sample_summary, "\n\n",
    "Dependent Variable: ", outcome_description
  )
}

output_format <- list(
  type = "json_schema",
  schema = list(
    type = "object",
    properties = list(
      ate_pp = list(
        type = "number",
        description = paste(
          "Signed average treatment effect in percentage points of the",
          "dependent variable's full scale range. Must lie between -100 and 100."
        )
      )
    ),
    required = list("ate_pp"),
    additionalProperties = FALSE
  )
)

make_request <- function(prompt) {
  request(endpoint) |>
    req_headers(
      `x-api-key` = api_key,
      `anthropic-version` = anthropic_version,
      `content-type` = "application/json"
    ) |>
    req_body_json(
      list(
        model = model,
        max_tokens = max_tokens,
        output_config = list(
          effort = reasoning_effort,
          format = output_format
        ),
        messages = list(
          list(
            role = "user",
            content = prompt
          )
        )
      ),
      auto_unbox = TRUE
    ) |>
    req_throttle(
      capacity = 5,
      fill_time_s = 1
    ) |>
    req_retry(
      max_tries = 3,
      retry_on_failure = TRUE,
      is_transient = function(resp) {
        resp_status(resp) %in% c(
          408, 409, 429, 500, 502, 503, 504, 529
        )
      }
    ) |>
    req_timeout(seconds = 300)
}


# -----------------------------------------------------------------------------
# Create all independent requests
# -----------------------------------------------------------------------------

jobs <- expand.grid(
  condition_row = seq_len(nrow(conditions)),
  outcome_row = seq_len(nrow(outcomes)),
  trial = seq_len(n_trials),
  KEEP.OUT.ATTRS = FALSE
)

jobs <- jobs[
  order(jobs$condition_row, jobs$outcome_row, jobs$trial),
]

jobs$custom_id <- sprintf(
  "c%02d_o%02d_t%02d",
  conditions$condition_number[jobs$condition_row],
  outcomes$outcome_number[jobs$outcome_row],
  jobs$trial
)

jobs$prompt <- mapply(
  function(condition_row, outcome_row) {
    make_prompt(
      conditions$condition_summary[condition_row],
      outcomes$prompt_description[outcome_row]
    )
  },
  jobs$condition_row,
  jobs$outcome_row,
  USE.NAMES = FALSE
)

requests <- lapply(jobs$prompt, make_request)


# -----------------------------------------------------------------------------
# Prepare frozen run-artifact directory
# -----------------------------------------------------------------------------

run_started <- Sys.time()
run_id <- format(run_started, "%Y%m%dT%H%M%SZ", tz = "UTC")

run_dir <- file.path("run_artifacts", run_id)
raw_dir <- file.path(run_dir, "raw_responses")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("predictions", showWarnings = FALSE)

file.copy(
  c("conditions.csv", "outcomes.csv", "study_constants.csv"),
  run_dir,
  overwrite = TRUE
)

request_manifest <- data.frame(
  custom_id = jobs$custom_id,
  condition_number = conditions$condition_number[jobs$condition_row],
  condition = conditions$condition_title[jobs$condition_row],
  outcome_number = outcomes$outcome_number[jobs$outcome_row],
  outcome = outcomes$variable[jobs$outcome_row],
  trial = jobs$trial,
  prompt = jobs$prompt
)

write.csv(
  request_manifest,
  file.path(run_dir, "request_manifest.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# -----------------------------------------------------------------------------
# Run the stateless API requests in parallel
# -----------------------------------------------------------------------------

responses <- req_perform_parallel(
  requests,
  max_active = max_active_requests,
  on_error = "stop",
  progress = TRUE
)

run_finished <- Sys.time()


# -----------------------------------------------------------------------------
# Preserve raw responses and extract predictions/usage
# -----------------------------------------------------------------------------

parsed <- vector("list", length(responses))

for (i in seq_along(responses)) {
  response <- responses[[i]]
  raw_text <- resp_body_string(response)

  raw_path <- file.path(
    raw_dir,
    paste0(jobs$custom_id[i], ".json")
  )

  writeLines(raw_text, raw_path, useBytes = TRUE)

  body <- fromJSON(raw_text, simplifyVector = FALSE)

  text_blocks <- Filter(
    function(block) identical(block$type, "text"),
    body$content
  )

  structured_text <- paste(
    vapply(text_blocks, function(block) block$text, character(1)),
    collapse = ""
  )

  ate_pp <- fromJSON(structured_text)$ate_pp

  parsed[[i]] <- data.frame(
    custom_id = jobs$custom_id[i],
    ate_pp = ate_pp,
    message_id = body$id,
    model_returned = body$model,
    stop_reason = body$stop_reason,
    input_tokens = body$usage$input_tokens,
    output_tokens = body$usage$output_tokens,
    thinking_tokens = body$usage$output_tokens_details$thinking_tokens,
    server_date = resp_header(response, "date"),
    request_id = resp_header(response, "request-id"),
    raw_response_file = file.path(
      "raw_responses",
      paste0(jobs$custom_id[i], ".json")
    ),
    stringsAsFactors = FALSE
  )
}

response_index <- do.call(rbind, parsed)

write.csv(
  response_index,
  file.path(run_dir, "response_index.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# -----------------------------------------------------------------------------
# Trial-level and median predictions
# -----------------------------------------------------------------------------

trial_level <- merge(
  request_manifest,
  response_index,
  by = "custom_id",
  sort = FALSE
)

trial_level <- trial_level[
  match(jobs$custom_id, trial_level$custom_id),
]

trial_level$ate <- trial_level$ate_pp *
  outcomes$pp_to_original_multiplier[jobs$outcome_row]

write.csv(
  trial_level,
  file.path(run_dir, "predictions_trial_level.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

median_predictions <- aggregate(
  cbind(ate_pp, ate) ~
    condition_number + condition + outcome_number + outcome,
  data = trial_level,
  FUN = median
)

median_predictions <- median_predictions[
  order(
    median_predictions$condition_number,
    median_predictions$outcome_number
  ),
]

submission_predictions <- median_predictions[
  c("condition", "outcome", "ate")
]

prediction_file <- file.path(
  "predictions",
  paste0(team_id, "_T3_", entry, "_v1.csv")
)

write.csv(
  submission_predictions,
  prediction_file,
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


# -----------------------------------------------------------------------------
# Archive hashes and computational-resource summary
# -----------------------------------------------------------------------------

raw_files <- sort(
  list.files(
    raw_dir,
    pattern = "\\.json$",
    full.names = TRUE
  )
)

stopifnot(length(raw_files) == nrow(jobs))

raw_response_hashes <- data.frame(
  raw_response_file = file.path(
    "raw_responses",
    basename(raw_files)
  ),
  sha256 = vapply(
    raw_files,
    digest,
    character(1),
    algo = "sha256",
    file = TRUE
  ),
  stringsAsFactors = FALSE
)

raw_hash_manifest_file <- file.path(
  run_dir,
  "raw_response_hashes.csv"
)

write.csv(
  raw_response_hashes,
  raw_hash_manifest_file,
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

raw_response_set_sha256 <- digest(
  paste(raw_response_hashes$sha256, collapse = "\n"),
  algo = "sha256",
  serialize = FALSE
)

total_input_tokens <- sum(response_index$input_tokens)
total_output_tokens <- sum(response_index$output_tokens)
total_thinking_tokens <- sum(response_index$thinking_tokens)

estimated_cost_usd <- (
  total_input_tokens / 1e6 * input_price_per_million +
  total_output_tokens / 1e6 * output_price_per_million
)

run_metadata <- list(
  approach = list(
    tier = 3,
    family = "direct forecast, single model, zero-shot",
    coverage = list(
      interventions = nrow(conditions),
      outcomes = nrow(outcomes),
      forecasts_per_estimate = n_trials,
      submitted_estimates = nrow(submission_predictions)
    )
  ),
  access = list(
    provider = "Anthropic",
    endpoint = endpoint,
    api = "Messages API",
    anthropic_version = anthropic_version,
    context_mode = "stateless; one independent call per intervention-outcome-trial",
    run_started_utc = format(run_started, tz = "UTC", usetz = TRUE),
    run_finished_utc = format(run_finished, tz = "UTC", usetz = TRUE)
  ),
  model_configuration = list(
    model_requested = model,
    model_identifier_note = paste(
      "Provider exposes the alias claude-fable-5 rather than a dated snapshot;",
      "the model identifier returned by every call is archived in response_index.csv."
    ),
    model_source = model_source,
    training_data_cutoff = model_training_data_cutoff,
    max_tokens = max_tokens,
    reasoning_effort = reasoning_effort,
    temperature = "omitted; provider default",
    top_p = "omitted; provider default",
    top_k = "omitted; provider default",
    penalties = "omitted",
    stop_sequences = "omitted",
    seed = "not set",
    completions_per_estimate = n_trials,
    persistent_memory = "none",
    tools = "none",
    web_search = "none",
    retrieval_augmented_generation = "none",
    fine_tuning = "none"
  ),
  aggregation_and_postprocessing = list(
    response_format = "JSON schema with one numeric field: ate_pp",
    scale = "percentage points of each outcome's full scale range",
    conversion = "ate = ate_pp * pp_to_original_multiplier",
    aggregation = "median across five independent calls",
    failed_requests = "the run stops; no failed call is silently excluded"
  ),
  computational_resources = list(
    api_call_count = nrow(jobs),
    max_parallel_requests = max_active_requests,
    compute_time_seconds = as.numeric(
      difftime(run_finished, run_started, units = "secs")
    ),
    total_input_tokens = total_input_tokens,
    total_output_tokens = total_output_tokens,
    total_thinking_tokens = total_thinking_tokens,
    input_price_per_million_usd = input_price_per_million,
    output_price_per_million_usd = output_price_per_million,
    pricing_source = pricing_source,
    estimated_cost_usd = estimated_cost_usd
  ),
  software = list(
    R = R.version.string,
    platform = R.version$platform,
    httr2 = as.character(packageVersion("httr2")),
    jsonlite = as.character(packageVersion("jsonlite")),
    digest = as.character(packageVersion("digest"))
  ),
  frozen_artifacts = list(
    request_manifest = file.path(run_dir, "request_manifest.csv"),
    response_index = file.path(run_dir, "response_index.csv"),
    raw_response_directory = raw_dir,
    raw_response_count = length(raw_files),
    raw_response_hash_manifest = raw_hash_manifest_file,
    raw_response_set_sha256 = raw_response_set_sha256,
    prediction_file = prediction_file,
    prediction_file_sha256 = digest(
      prediction_file,
      algo = "sha256",
      file = TRUE
    ),
    conditions_sha256 = digest(
      "conditions.csv",
      algo = "sha256",
      file = TRUE
    ),
    outcomes_sha256 = digest(
      "outcomes.csv",
      algo = "sha256",
      file = TRUE
    ),
    study_constants_sha256 = digest(
      "study_constants.csv",
      algo = "sha256",
      file = TRUE
    )
  )
)

write_json(
  run_metadata,
  file.path(run_dir, "run_metadata.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

stopifnot(
  nrow(response_index) == 1040L,
  nrow(trial_level) == 1040L,
  nrow(submission_predictions) == 208L,
  length(unique(submission_predictions$condition)) == 16L,
  length(unique(submission_predictions$outcome)) == 13L,
  !anyNA(submission_predictions$ate),
  all(response_index$stop_reason == "end_turn"),
  length(raw_files) == 1040L
)

print(submission_predictions)
cat("\nPrediction file:", prediction_file, "\n")
cat("Run artifacts:", run_dir, "\n")
cat("Estimated cost (USD):", round(estimated_cost_usd, 4), "\n")
