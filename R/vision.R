#' Load an Unsloth vision model
#'
#' Loads a vision-language model and returns a wrapper compatible with the
#' package's model workflows.
#'
#' @param model_name Hugging Face model identifier.
#' @param load_in_4bit Load the model in 4-bit precision.
#' @param max_seq_length Maximum sequence length retained on the wrapper.
#' @param ... Additional arguments passed to `FastVisionModel$from_pretrained()`.
#' @return A `runsloth_vision_model` wrapper.
#' @export
#' @examples
#' \dontrun{unsloth_load_vision_model("unsloth/Llama-3.2-11B-Vision-Instruct-bnb-4bit")}
unsloth_load_vision_model <- function(
    model_name = "unsloth/Llama-3.2-11B-Vision-Instruct-bnb-4bit",
    load_in_4bit = TRUE, max_seq_length = 2048L, ...) {
  max_seq_length <- as_py_int(max_seq_length)
  fn <- unsloth$FastVisionModel$from_pretrained
  params <- py_callable_params(fn)
  args <- c(list(model_name = model_name, load_in_4bit = load_in_4bit),
            list(...))
  if ("max_seq_length" %in% params) args$max_seq_length <- max_seq_length
  loaded <- do.call(fn, args)
  structure(
    list(model = loaded[[1L]], tokenizer = loaded[[2L]],
         max_seq_length = max_seq_length, has_lora = FALSE, is_vision = TRUE),
    class = c("runsloth_vision_model", "runsloth_model")
  )
}

#' Add vision LoRA adapters
#'
#' Applies Unsloth vision LoRA settings to a vision model wrapper.
#'
#' @param object A vision model wrapper.
#' @param finetune_vision_layers Whether to train vision layers.
#' @param finetune_language_layers Whether to train language layers.
#' @param finetune_attention_modules Whether to train attention modules.
#' @param finetune_mlp_modules Whether to train MLP modules.
#' @param r LoRA rank.
#' @param lora_alpha LoRA scaling value.
#' @param ... Additional arguments passed to `get_peft_model()`.
#' @return The updated vision model wrapper.
#' @export
#' @examples
#' \dontrun{model <- unsloth_add_vision_lora(model)}
unsloth_add_vision_lora <- function(
    object, finetune_vision_layers = TRUE, finetune_language_layers = TRUE,
    finetune_attention_modules = TRUE, finetune_mlp_modules = TRUE,
    r = 16L, lora_alpha = 16L, ...) {
  if (!inherits(object, "runsloth_vision_model")) {
    cli::cli_abort("`object` must be a vision model.")
  }
  object$model <- unsloth$FastVisionModel$get_peft_model(
    object$model,
    finetune_vision_layers = finetune_vision_layers,
    finetune_language_layers = finetune_language_layers,
    finetune_attention_modules = finetune_attention_modules,
    finetune_mlp_modules = finetune_mlp_modules,
    r = as_py_int(r), lora_alpha = as_py_int(lora_alpha), ...
  )
  object$has_lora <- TRUE
  object
}

#' Build a multimodal vision dataset
#'
#' Opens image files in Python and creates Unsloth-compatible user/assistant
#' conversations. Images larger than `max_size_img` are resized proportionally.
#'
#' @param image_paths Paths to image files.
#' @param instructions User instructions, one per image.
#' @param responses Assistant responses, one per image.
#' @param max_size_img Maximum image width or height in pixels.
#' @return A Python list of multimodal conversation dictionaries.
#' @export
#' @examples
#' \dontrun{data <- as_vision_dataset("image.png", "Describe it", "A cat")}
as_vision_dataset <- function(image_paths, instructions, responses,
                              max_size_img = 768L) {
  if (!is.character(image_paths) || !length(image_paths) ||
      anyNA(image_paths) || any(!file.exists(image_paths))) {
    cli::cli_abort("`image_paths` must contain existing image file paths.")
  }
  if (length(instructions) != length(image_paths) ||
      length(responses) != length(image_paths) ||
      anyNA(instructions) || anyNA(responses)) {
    cli::cli_abort("Each image must have one non-missing instruction and response.")
  }
  max_size_img <- as_py_int(max_size_img)
  if (length(max_size_img) != 1L || is.na(max_size_img) || max_size_img < 1L) {
    cli::cli_abort("`max_size_img` must be a positive integer.")
  }

  pil <- reticulate::import("PIL.Image", delay_load = FALSE)
  tuple <- reticulate::import_builtins()$tuple
  conversations <- lapply(seq_along(image_paths), function(i) {
    image <- pil$open(image_paths[[i]])
    size <- reticulate::py_to_r(image$size)
    if (max(size) > max_size_img) {
      image$thumbnail(tuple(as.integer(c(max_size_img, max_size_img))))
    }
    list(list(
      role = "user",
      content = list(
        list(type = "text", text = as.character(instructions[[i]])),
        list(type = "image", image = image)
      )
    ), list(
      role = "assistant",
      content = list(list(type = "text", text = as.character(responses[[i]])))
    ))
  })
  reticulate::r_to_py(conversations, convert = FALSE)
}

#' Train a vision-language model
#'
#' Builds an Unsloth vision collator and TRL SFT trainer, avoiding dataset
#' preparation and image-token truncation when the installed signatures allow.
#'
#' @param object A vision model wrapper.
#' @param dataset Multimodal conversations or a Hugging Face dataset.
#' @param output_dir Trainer output directory.
#' @param train_on_responses_only Apply response-only loss masking.
#' @param instruction_part Instruction delimiter for response masking.
#' @param response_part Response delimiter for response masking.
#' @param ... Additional SFT configuration arguments.
#' @return Invisibly returns the trained model wrapper.
#' @export
#' @examples
#' \dontrun{unsloth_train_vision(model, dataset)}
unsloth_train_vision <- function(
    object, dataset, output_dir = "outputs",
    train_on_responses_only = FALSE, instruction_part = NULL,
    response_part = NULL, ...) {
  if (!inherits(object, "runsloth_vision_model")) {
    cli::cli_abort("`object` must be a vision model.")
  }
  unsloth$FastVisionModel$for_training(object$model)
  collator_args <- list()
  if (isTRUE(train_on_responses_only)) {
    collator_args$train_on_responses_only <- TRUE
    if (!is.null(instruction_part)) collator_args$instruction_part <- instruction_part
    if (!is.null(response_part)) collator_args$response_part <- response_part
  }
  collator <- do.call(unsloth$trainer$UnslothVisionDataCollator, c(
    list(model = object$model, tokenizer = object$tokenizer), collator_args
  ))
  config_fn <- if (!is.null(trl$SFTConfig)) trl$SFTConfig else transformers$TrainingArguments
  trainer_fn <- trl$SFTTrainer
  config_params <- py_callable_params(config_fn)
  trainer_params <- py_callable_params(trainer_fn)
  config <- c(list(output_dir = output_dir), list(...))
  if ("max_length" %in% config_params) config["max_length"] <- list(NULL)
  config <- do.call(config_fn, config)
  trainer_args <- list(
    model = object$model, args = config, train_dataset = dataset,
    data_collator = collator,
    dataset_kwargs = reticulate::dict(skip_prepare_dataset = TRUE)
  )
  if ("processing_class" %in% trainer_params) {
    trainer_args$processing_class <- object$tokenizer
  } else if ("tokenizer" %in% trainer_params) {
    trainer_args$tokenizer <- object$tokenizer
  }
  trainer <- do.call(trainer_fn, trainer_args)
  trainer$train()
  invisible(object)
}
