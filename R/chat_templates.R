#' List available Unsloth chat templates
#'
#' @return Character vector of template names.
#' @export
#' @examples
#' \dontrun{unsloth_list_chat_templates()}
unsloth_list_chat_templates <- function() {
  ct <- unsloth$chat_templates
  reticulate::py_to_r(reticulate::import_builtins()$list(ct$CHAT_TEMPLATES$keys()))
}

#' Set a model's chat template
#'
#' @param object A `runsloth_model`.
#' @param chat_template Template name.
#' @param map_eos_token Whether to map the end-of-turn token.
#' @param system_message Optional system message.
#' @return The updated model object.
#' @export
#' @examples
#' \dontrun{object <- unsloth_set_chat_template(object, "chatml")}
unsloth_set_chat_template <- function(object, chat_template = "chatml",
                                      map_eos_token = TRUE,
                                      system_message = NULL) {
  object$tokenizer <- unsloth$chat_templates$get_chat_template(
    object$tokenizer, chat_template = chat_template,
    mapping = list(role = "role", content = "content", user = "user",
                   assistant = "assistant"),
    map_eos_token = map_eos_token, system_message = system_message)
  object$chat_template <- chat_template
  object
}

#' Standardize and format chat data
#'
#' @param object A `runsloth_model`.
#' @param dataset Data frame, conversations, or Hugging Face Dataset.
#' @param conversations_col Name of the conversations column.
#' @param standardize_sharegpt Standardize ShareGPT data when supported.
#' @return A Hugging Face Dataset with a formatted `text` column.
#' @export
#' @examples
#' \dontrun{dataset <- unsloth_apply_chat_template(object, dataset)}
unsloth_apply_chat_template <- function(object, dataset,
                                        conversations_col = "conversations",
                                        standardize_sharegpt = TRUE) {
  ct <- unsloth$chat_templates
  if (is.data.frame(dataset)) dataset <- as_hf_dataset(dataset)
  if (is.list(dataset) && !is.data.frame(dataset)) {
    dataset <- datasets$Dataset$from_dict(
      stats::setNames(list(dataset), conversations_col))
  }
  if (isTRUE(standardize_sharegpt)) {
    standardize <- .optional_py_attr(ct, "standardize_data_formats")
    if (is.null(standardize)) {
      standardize <- .optional_py_attr(ct, "standardize_sharegpt")
    }
    if (!is.null(standardize)) {
      dataset <- standardize(dataset)
    }
  }
  tokenizer <- object$tokenizer
  map_batch <- function(batch) {
    list(text = tokenizer$apply_chat_template(
      batch[[conversations_col]], tokenize = FALSE,
      add_generation_prompt = FALSE))
  }
  dataset$map(map_batch, batched = TRUE)
}

#' Mask loss to assistant responses
#'
#' @param trainer An untrained SFT trainer.
#' @param instruction_part Optional instruction delimiter.
#' @param response_part Optional response delimiter.
#' @return The trainer after applying response-only masking.
#' @export
#' @examples
#' \dontrun{trainer <- unsloth_train_on_responses_only(trainer)}
unsloth_train_on_responses_only <- function(
    trainer, instruction_part = NULL, response_part = NULL) {
  args <- list()
  if (!is.null(instruction_part)) args$instruction_part <- instruction_part
  if (!is.null(response_part)) args$response_part <- response_part
  do.call(unsloth$trainer$train_on_responses_only, c(list(trainer), args))
}
