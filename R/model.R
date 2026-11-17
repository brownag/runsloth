.optional_py_attr <- function(object, name) {
  if (is.list(object)) return(object[[name]])
  tryCatch(reticulate::py_get_attr(object, name), error = function(e) NULL)
}

#' Load an Unsloth language model
#'
#' @param model_name Hugging Face model identifier.
#' @param max_seq_length Maximum sequence length.
#' @param load_in_4bit Load weights in 4-bit precision.
#' @param load_in_8bit Load weights in 8-bit precision.
#' @param full_finetuning Enable full fine-tuning.
#' @param dtype Optional model dtype.
#' @param token Optional Hugging Face token.
#' @param ... Additional supported `from_pretrained()` arguments.
#' @return A `runsloth_model` list containing the Python model and tokenizer.
#' @export
#' @examples
#' \dontrun{model <- unsloth_load_model("unsloth/Llama-3.2-3B-Instruct-bnb-4bit")}
unsloth_load_model <- function(
    model_name = "unsloth/Llama-3.2-3B-Instruct-bnb-4bit",
    max_seq_length = 2048L, load_in_4bit = TRUE, load_in_8bit = FALSE,
    full_finetuning = FALSE, dtype = NULL, token = NULL, ...) {
  modes <- c(load_in_4bit, load_in_8bit, full_finetuning)
  if (sum(as.logical(modes)) > 1L) {
    cli::cli_abort("At most one of `load_in_4bit`, `load_in_8bit`, and `full_finetuning` can be TRUE.")
  }
  fn <- unsloth$FastLanguageModel$from_pretrained
  params <- py_callable_params(fn)
  args <- c(list(model_name = model_name, max_seq_length = as_py_int(max_seq_length)),
            list(...))
  optional <- list(load_in_4bit = load_in_4bit, load_in_8bit = load_in_8bit,
                   full_finetuning = full_finetuning, dtype = as_py_dtype(dtype),
                   token = token)
  for (name in names(optional)) {
    value <- optional[[name]]
    if (name == "dtype" && name %in% params) {
      args[name] <- list(value)
    } else if (!is.null(value) && (name %in% params || !identical(
        value, switch(name, load_in_4bit = TRUE, load_in_8bit = FALSE,
                      full_finetuning = FALSE, NULL)))) {
      args[[name]] <- value
    }
  }
  result <- do.call(fn, args)
  structure(list(model = result[[1L]], tokenizer = result[[2L]],
                 max_seq_length = as_py_int(max_seq_length),
                 has_lora = FALSE, is_vision = FALSE),
            class = "runsloth_model")
}

#' Add tokens before attaching LoRA
#'
#' @param object A `runsloth_model`.
#' @param new_tokens Character vector of tokens to add.
#' @return The updated model object.
#' @export
#' @examples
#' \dontrun{object <- unsloth_add_tokens(object, c("<extra>"))}
unsloth_add_tokens <- function(object, new_tokens) {
  if (isTRUE(object$has_lora)) cli::cli_abort("Add tokens before applying LoRA.")
  updated <- unsloth$add_new_tokens(
    object$model, object$tokenizer, new_tokens = as.list(new_tokens))
  object$model <- updated[[1L]]
  object$tokenizer <- updated[[2L]]
  object
}

#' Attach LoRA adapters
#'
#' @param object A `runsloth_model`.
#' @param r LoRA rank.
#' @param lora_alpha LoRA scaling factor.
#' @param lora_dropout LoRA dropout.
#' @param target_modules Python list of module names to adapt.
#' @param use_gradient_checkpointing Checkpointing mode.
#' @param random_state Random seed.
#' @param bias Bias handling mode.
#' @param ... Additional supported `get_peft_model()` arguments.
#' @return The updated model object.
#' @export
#' @examples
#' \dontrun{object <- unsloth_add_lora(object)}
unsloth_add_lora <- function(
    object, r = 16L, lora_alpha = 16L, lora_dropout = 0,
    target_modules = c("q_proj", "k_proj", "v_proj", "o_proj",
                       "gate_proj", "up_proj", "down_proj"),
    use_gradient_checkpointing = "unsloth", random_state = 3407L,
    bias = "none", ...) {
  object$model <- unsloth$FastLanguageModel$get_peft_model(
    object$model, r = as_py_int(r), lora_alpha = as_py_int(lora_alpha),
    lora_dropout = lora_dropout, target_modules = as.list(target_modules),
    use_gradient_checkpointing = use_gradient_checkpointing,
    random_state = as_py_int(random_state), bias = bias, ...)
  object$has_lora <- TRUE
  object
}
