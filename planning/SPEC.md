# **Grounding Document and Coding Agent Prompt for the runsloth R Package**

This grounding document specifies the architecture, dependency mechanics, module contracts, prototype defect remediations, and verification requirements for runsloth (v0.1.0), an R package under Apache License (\>= 2.0) that wraps Python's unsloth SDK via reticulate1. The package exposes a pipe-friendly (\|\>) R interface for 4-bit QLoRA, 8-bit LoRA, and full fine-tuning of language models (FastLanguageModel), multimodal vision fine-tuning (FastVisionModel), reinforcement-learning reasoning (GRPOTrainer), real-time token streaming into the R console, dataset chat-template standardization, Hugging Face Hub publishing, and local GGUF inference using llama.cpp (llama-server and llama-cli) as the first-class runtime alongside optional ollama registration1. Because runsloth delegates kernel execution, training loops, and GGUF quantization to Python and llama.cpp, headline performance figures in the design prototype ("2x faster" and "70% less VRAM") and in Hugging Face's TRL v0.17.0 documentation ("2x faster, 60% less memory," alongside a 1 A100 40 GB comparison entry reporting 2.74x and \-57.8%) originate from upstream Unsloth and TRL framework documentation rather than independent benchmarks of this R wrapper1.  
Translating the initial design prototype into a reliable, R CMD check-clean implementation requires resolving twelve categories of syntax defects, runtime bugs, and upstream API shifts before scaffolding begins. A line-by-line audit against unsloth, Hugging Face trl (v0.9.4 through v0.25.0), reticulate (up to 1.47.0), llama.cpp, and ellmer (0.5.0) documentation uncovered transcription syntax errors, fatal Python class-name typos in GRPO (GRP0Config and GRP0Trainer spelled with zeros plus adam\_betal), SFTConfig and SFTTrainer parameter migrations (max\_seq\_length moving to max\_length in SFTConfig alongside processing\_class), unreachable response-masking hooks, reticulate length-1 scalar collapse traps, a misplaced writeLines() call in Modelfile synthesis, duplicate GGUF exports under the Ollama backend, a race-prone llama-server startup sleep lacking /health polling, and an incompatible ellmer::chat\_openai() client call2. The specification below codifies every remediation and concludes with a self-contained implementation prompt ready for a local coding agent.

## **Package Architecture and Target File Layout**

The runsloth package centers its user API on lightweight S3 wrapper lists so R developers can chain operations with \|\> without manually managing Python object pointers1. Language models returned by unsloth\_load\_model() carry class "runsloth\_model" and bundle the Python model, tokenizer, max\_seq\_length, has\_lora state, is\_vision \= FALSE, and optional chat\_template metadata1. Multimodal vision models returned by unsloth\_load\_vision\_model() inherit from "runsloth\_model" with class c("runsloth\_vision\_model", "runsloth\_model") and is\_vision \= TRUE, enabling shared S3/class-aware routing in unsloth\_stream(), unsloth\_push\_to\_hub(), and unsloth\_export\_and\_run()1. Local server sessions launched by launch\_llamacpp() return a "runsloth\_server" object holding the backend identifier, OpenAI-compatible base\_url, gguf\_path, host, port, and an optional processx handle for clean shutdown2.  
Because the package examples and workflows rely on the native pipe \|\>, utils::flush.console(), stats::setNames(), and rlang's %\|\|% operator, DESCRIPTION should declare Depends: R (\>= 4.1.0), Imports: cli, reticulate (\>= 1.34.0), rlang, stats, utils, and Suggests: ellmer, httr2, jsonlite, ollamar, processx, testthat (\>= 3.0.0), tibble, matching the prototype's reticulate (\>= 1.34.0) floor and Roxygen: list(markdown \= TRUE) configuration (RoxygenNote: 7.3.1)1. Where managed uv environments via reticulate::py\_require() are desired—documented in reticulate 1.46.0–1.47.07—runsloth should detect py\_require capability at runtime rather than hardcoding an undocumented minimum version constraint above 1.34.0. The table below defines the target package layout and file responsibilities.

| File Path | Layer / Role | Key Exported and Internal Symbols | Notes & Dependencies |
| :---- | :---- | :---- | :---- |
| DESCRIPTION | Package metadata and dependency declarations | Depends: R (\>= 4.1.0), Imports, Suggests | Apache License (\>= 2.0); Roxygen markdown enabled1 |
| NAMESPACE | Generated S3 exports and namespace imports | Generated via roxygen2::roxygenise() | Imports \`% |
| LICENSE | Apache 2.0 license text | Standard Apache 2.0 license file | Matches DESCRIPTION license field2 |
| R/zzz.R | Delayed Python bindings and import-order guard | .onLoad(), ensure\_unsloth(), Python proxies | Forces unsloth import before trl/transformers2 |
| R/utils.R | R-Python interop and internal shared helpers | as\_py\_int(), as\_py\_dtype(), py\_callable\_params(), validate\_py\_identifier(), resolve\_model\_device(), .export\_gguf\_internal(), .find\_exported\_gguf() | Handles reticulate scalar rules, TRL signatures, and single-pass GGUF export2 |
| R/install.R | Environment installer and diagnostic checks | install\_unsloth(), unsloth\_use\_managed\_python(), unsloth\_doctor() | Supports virtualenv, conda, py\_require(), optional xformers2 |
| R/model.R | LLM loading, LoRA patching, token expansion | unsloth\_load\_model(), unsloth\_add\_lora(), unsloth\_add\_tokens() | Wraps FastLanguageModel; enforces token-before-LoRA order2 |
| R/chat\_templates.R | Chat templates, dataset standardization, masking | unsloth\_list\_chat\_templates(), unsloth\_set\_chat\_template(), unsloth\_apply\_chat\_template(), unsloth\_train\_on\_responses\_only() | Wraps unsloth.chat\_templates and standardize\_data\_formats()2 |
| R/train.R | Dataset conversion, SFT trainer, GGUF export | as\_hf\_dataset(), unsloth\_build\_trainer(), unsloth\_train(), unsloth\_export\_gguf() | Introspects SFTConfig/SFTTrainer signatures across TRL versions2 |
| R/vision.R | Vision model loading, LoRA, VLM SFT | unsloth\_load\_vision\_model(), unsloth\_add\_vision\_lora(), as\_vision\_dataset(), unsloth\_train\_vision() | Configures UnslothVisionDataCollator and max\_length \= NULL2 |
| R/grpo.R | GRPO RL patching, R reward wrapper, training | unsloth\_patch\_grpo(), as\_grpo\_reward(), unsloth\_train\_grpo() | Fixes GRPOConfig/GRPOTrainer/adam\_beta1; supports \*\*kwargs2 |
| R/infer.R | Threaded non-blocking token streaming | unsloth\_stream() | Ensures streamer.end() in finally:; dynamic device lookup2 |
| R/hub\_ollama.R | Hugging Face Hub uploads and Ollama registration | unsloth\_push\_to\_hub(), unsloth\_register\_ollama(), .register\_ollama\_from\_dir() | Fixes Modelfile write bug and cli markup errors2 |
| R/backends.R | Unified GGUF export, llama.cpp runner, shutdown | unsloth\_export\_and\_run(), launch\_llamacpp(), unsloth\_stop\_server() | Defaults to llama-server \--jinja with /health polling2 |
| tests/testthat.R | Test suite entry point and skip helpers | skip\_if\_no\_unsloth(), skip\_if\_no\_gpu() | Keeps CI green on CPU hosts without Python/CUDA |
| tests/testthat/test-\*.R | Unit tests for R logic, serialization, mocks | Tests covering helpers, templates, GRPO bridge, backends | Verifies R contracts without GPU dependencies |

## **Prototype Audit and Critical Remediation Matrix**

Comparing the design prototype verbatim against upstream unsloth, trl, reticulate, llama.cpp, and ellmer behavior reveals twelve distinct categories of syntax corruption, logic bugs, or API drift that must be corrected during implementation2. Several issues arise from malformed operators and missing delimiters in the prototype's core files (DESCRIPTION, R/zzz.R, R/install.R, R/model.R, and R/train.R)2, whereas others reflect real behavioral incompatibilities across TRL versions (v0.9.4–v0.13.0 versus v0.17.0–v0.25.0), reticulate data conversion rules, and ellmer 0.5.0 provider endpoints4.

| Module | Prototype Behavior or Defect | Failure Mode or Upstream Drift | Required Remediation |
| :---- | :---- | :---- | :---- |
| DESCRIPTION, R/zzz.R, R/model.R | Corrupted operators (\<\<\<-, \<\<\<\<\<-), missing \=, stray } in install.R, malformed Config/reticulate, omitted utils/\`% |  | %\` imports2 |
| R/zzz.R | Separate delay\_load \= TRUE proxies on unsloth, trl, transformers, datasets, torch2 | Accessing trl or transformers first bypasses Unsloth monkey-patches, emitting warnings and losing optimizations15 | Attach delay\_load \= list(before\_load \= ensure\_unsloth) to trl, transformers, and datasets so unsloth always initializes first13 |
| R/install.R | Hardcodes "xformers" in package list and tells all users to run use\_virtualenv()2 | xformers breaks on mismatched CUDA/PyTorch builds (e.g., Blackwell); misleads conda users2 | Make xformers optional (with\_xformers \= FALSE, defaulting to PyTorch SDPA); adapt success alert to conda vs virtualenv8 |
| R/train.R | Uses transformers\$TrainingArguments and passes tokenizer, max\_seq\_length, packing, dataset\_text\_field to SFTTrainer2 | max\_seq\_length removed from SFTTrainer and rejected in newer SFTConfig; TRL v0.17.0–v0.25.0 use SFTConfig(max\_length, packing, dataset\_text\_field) and processing\_class4 | Introspect inspect.signature() on trl$SFTConfigandtrl$SFTTrainer at runtime to route parameters safely across TRL/Unsloth releases5 |
| R/train.R, R/chat\_templates.R | unsloth\_train() runs trainer\$train() immediately; unsloth\_train\_on\_responses\_only(trainer) expects an untrained SFTTrainer2 | Pipe users calling unsloth\_train() cannot attach response-only loss masking before training begins | Add unsloth\_build\_trainer() and expose train\_on\_responses\_only, instruction\_part, and response\_part inside unsloth\_train()21 |
| R/train.R | as\_hf\_dataset() runs r\_to\_py(as.list(df)) directly2 | Length-1 atomic vectors from 1-row data.frame objects convert to Python scalars, crashing Dataset.from\_dict()8 | Coerce atomic columns via lapply(..., as.list) while leaving existing list-columns intact8 |
| R/vision.R | Unqualified dict(...); omits max\_length \= NULL in SFTConfig; misses max\_seq\_length on model list2 | could not find function "dict"; TRL SFTConfig defaults max\_length to 1024, risking truncated VLM image tokens2 | Call reticulate::dict(), set max\_length \= NULL (None) in SFTConfig, and expose collator response-masking parameters22 |
| R/grpo.R | Calls trl$GRP0Config,trl$GRP0Trainer, and adam\_betal \= 0.9; drops \*\*kwargs and fails on length-1 R vectors2 | Guaranteed Python AttributeError/TypeError; drops completion\_ids and dataset ground-truth kwargs; breaks when R returns scalar numeric2 | Fix GRPOConfig, GRPOTrainer, adam\_beta1; validate name; coerce Python scalar returns to 1-element lists; support optional \*\*kwargs forwarding8 |
| R/infer.R | Hardcodes $to("cuda");runsrawmodel$generate in thread without try/finally; passes temperature \= 0 with do\_sample \= FALSE2 | Fails on CPU/MPS/AMD/sharded models; generation error deadlocks reticulate::iterate() forever; emits HF warnings2 | Resolve model\$device dynamically; wrap generate in Python try/finally: streamer.end(); pass temperature only when do\_sample is TRUE |
| R/chat\_templates.R | Hardcodes dict(conversations \= dataset) ignoring conversations\_col; leaves \<lim\_end \> / \<im\_start\> typos in docs2 | Crashes with KeyError when conversations\_col \!= "conversations"2 | Build input dict dynamically keyed by conversations\_col; prefer standardize\_data\_formats() when present20 |
| R/hub\_ollama.R | writeLines(lines, modelfile\_path) trapped inside if (\!is.null(eos\_token)...); broken {. code ...} / .code cli tags; picks gguf\_files\[1\]2 | Fails to create Modelfile when eos\_token is empty; malformed CLI alerts; may register wrong .gguf file2 | Move writeLines() outside the conditional; fix cli inline markup; filter .gguf files by requested quantization method |
| R/backends.R | backend \= "ollama" triggers duplicate save\_pretrained\_gguf(); Sys.sleep(2) replaces /health check; example uses ellmer::chat\_openai()1 | Re-merges and re-quantizes weights twice; fails on slow model loads; chat\_openai() targets OpenAI's Responses API10 | Export GGUF once prior to backend routing; spawn via processx and poll /health for HTTP 200; use ellmer::chat\_openai\_compatible()10 |

## **Python Runtime, reticulate, and Dependency Semantics**

Unsloth achieves its training and inference accelerations by setting UNSLOTH\_IS\_PRESENT=1 and monkey-patching transformers, peft, and trl modules at import time3. Upstream Unsloth issue trackers and training logs repeatedly document that importing trl, transformers, or peft before unsloth causes Unsloth to emit warnings, bypass kernel patches, or fail during trainer initialization15. In R packages using reticulate::import(..., delay\_load \= TRUE), delayed module proxies do not import the underlying Python package until an R call accesses an attribute via \$13. Consequently, if a user calls as\_hf\_dataset() (touching datasets) or another helper touching transformers before loading a model, Python can import transformers or trl in an unpatched state. To prevent order-dependent failures regardless of call sequence, R/zzz.R must supply delay\_load \= list(before\_load \= ensure\_unsloth) on trl, transformers, and datasets, where ensure\_unsloth() forces evaluation of the unsloth proxy first13.  
Provisioning Unsloth's Python environment requires balancing reticulate's modern uv workflow against GPU driver constraints. Current reticulate guidance (1.46.0–1.47.0) documents reticulate::py\_require() inside .onLoad() to automatically provision ephemeral virtual environments via uv, replacing older Config/reticulate entries in DESCRIPTION and use\_virtualenv() calls inside .onLoad()12. However, unsloth requires CUDA-aligned torch builds (for instance, \--torch-backend=cu128 for NVIDIA Blackwell RTX 50-series GPUs), optional xformers wheels strictly matched to the PyTorch minor version, and synchronized unsloth\_zoo releases17. Calling py\_require() unconditionally in .onLoad() could override pre-built GPU conda environments or fail during R CMD check or air-gapped sessions unless UV\_OFFLINE=1 or RETICULATE\_PYTHON is configured13. Accordingly, runsloth should keep py\_require() strictly opt-in (via options(runsloth.use\_py\_require \= TRUE) or unsloth\_use\_managed\_python() guarded by runtime capability detection) while maintaining install\_unsloth() for explicit virtualenv or conda setup and offering an upgrade \= TRUE troubleshooting path modeled on Unsloth's recommended \--upgrade \--force-reinstall \--no-cache-dir \--no-deps unsloth unsloth\_zoo recovery workflow2.  
Across the R-to-Python boundary, reticulate maps R length-1 atomic vectors to Python scalars rather than single-element lists, and maps R numeric doubles to Python float rather than int8. Every integer hyperparameter (max\_seq\_length, r, lora\_alpha, random\_state, max\_steps, per\_device\_train\_batch\_size, gradient\_accumulation\_steps, warmup\_steps, logging\_steps, seed, dataset\_num\_proc, num\_generations, max\_prompt\_length, max\_completion\_length, max\_new\_tokens, port, n\_gpu\_layers, ctx\_size, max\_size\_img) must be coerced via as.integer()2. Every parameter expecting a Python list—such as target\_modules, new\_tokens, reward\_funcs, and multi-quantization quantization\_method—must be wrapped with as.list() so single-item character vectors do not collapse into plain strings2. Similarly, as\_hf\_dataset() must explicitly transform atomic data.frame columns into lists (lapply(as.list(df), function(col) if (is.list(col)) col else as.list(col))) before invoking datasets$Dataset$from\_dict(), preventing single-row data frames from crashing2.

## **Detailed Module Specifications**

### **Environment Setup, Utilities, and Model Loading (R/zzz.R, R/utils.R, R/install.R, R/model.R)**

R/zzz.R declares package-level bindings (unsloth, trl, datasets, transformers, torch, inspect) initialized to NULL2. Inside .onLoad(), it registers unsloth with delay\_load \= TRUE, registers trl, transformers, and datasets with delay\_load \= list(before\_load \= ensure\_unsloth), and registers torch and inspect with delay\_load \= TRUE2. If isTRUE(getOption("runsloth.use\_py\_require", FALSE)) and py\_require exists in the reticulate namespace, .onLoad() may declare "unsloth" through reticulate::py\_require() without initializing Python prematurely13.  
R/utils.R centralizes internal conversions and shared export mechanics: as\_py\_int() (safely casts non-NULL inputs to integer), as\_py\_dtype() (passes NULL through as Python None and maps "float16"/"fp16" and "bfloat16"/"bf16" to torch$float16andtorch$bfloat16), py\_callable\_params() (inspects inspect$signature(fn)$parameters keys to insulate runsloth from TRL/Unsloth keyword drift), validate\_py\_identifier() (guards Python code generation in R/grpo.R), resolve\_model\_device() (retrieves object$model$device safely across CUDA, MPS, XPU, and CPU), .export\_gguf\_internal(), and .find\_exported\_gguf()2.  
R/install.R implements install\_unsloth(envname \= "r-unsloth", method \= c("auto", "virtualenv", "conda"), with\_xformers \= FALSE, upgrade \= FALSE), unsloth\_use\_managed\_python(), and unsloth\_doctor(). The installer keeps "xformers" opt-in because Unsloth natively falls back to PyTorch SDPA when xformers is omitted, reducing wheel conflicts18. Final activation messages tailor themselves to reticulate::use\_condaenv() when method \== "conda" and reticulate::use\_virtualenv() otherwise2. When upgrade \= TRUE, install\_unsloth() passes pip\_options \= c("--upgrade", "--force-reinstall", "--no-cache-dir", "--no-deps") for c("unsloth", "unsloth\_zoo") and reminds users to clear unsloth\_compiled\_cache if stale compiled artifacts cause GRPOConfig or kernel errors17. unsloth\_doctor() audits Python configuration, torch and CUDA availability, is\_bfloat16\_supported(), package versions (unsloth, unsloth\_zoo, trl, transformers), and PATH availability for llama-server, llama-cli, and ollama2.  
R/model.R exports unsloth\_load\_model(), unsloth\_add\_tokens(), and unsloth\_add\_lora(). unsloth\_load\_model() wraps unsloth$FastLanguageModel$from\_pretrained(), exposing model\_name, max\_seq\_length \= 2048L, load\_in\_4bit \= TRUE, load\_in\_8bit \= FALSE, full\_finetuning \= FALSE, dtype \= NULL, token \= NULL, and ..., while validating that at most one precision/mode flag (load\_in\_4bit, load\_in\_8bit, full\_finetuning) is TRUE per TRL Unsloth integration rules2. unsloth\_add\_tokens(object, new\_tokens) calls unsloth$ad{d}_{n}e{w}_{t}okens(object$model, object$tokenizer,ne{w}_{t}okens=as.list(ne{w}_{t}okens))andabortsifisTRUE(object$has\_lora), enforcing Unsloth's requirement that token additions precede get\_peft\_model()19. unsloth\_add\_lora() wraps FastLanguageModel$ge{t}_{p}ef{t}_{m}odel()withdefaultsr=16L,lor{a}_{a}lpha=16L,lor{a}_{d}ropout=0,targe{t}_{m}odules=c("{q}_{p}roj","{k}_{p}roj","{v}_{p}roj","{o}_{p}roj","gat{e}_{p}roj","u{p}_{p}roj","dow{n}_{p}roj"),us{e}_{g}radien{t}_{c}heckpointing="unsloth",rando{m}_{s}tate=3407L,andbias="none",markingobject$has\_lora \<- TRUE2.

### **Chat Templates and Dataset Standardization (R/chat\_templates.R)**

R/chat\_templates.R exports four helpers around unsloth.chat\_templates2. unsloth\_list\_chat\_templates() returns template names cleanly by evaluating Python's CHAT\_TEMPLATES.keys() list via reticulate::import\_builtins()$list(ct$CHAT\_TEMPLATES\$keys()) instead of converting all template definitions into R2. unsloth\_set\_chat\_template(object, chat\_template \= "chatml", map\_eos\_token \= TRUE, system\_message \= NULL) calls ct$ge{t}_{c}ha{t}_{t}emplate()withtheOpenAIrole/content/user/assistantmappingandstoresobject$chat\_template \<- chat\_template2. Retaining the exact same chat template and eos\_token across training and llama.cpp inference is essential to avoid degraded or runaway completions after GGUF export31.  
unsloth\_apply\_chat\_template(object, dataset, conversations\_col \= "conversations", standardize\_sharegpt \= TRUE) accepts an R data.frame, an R list of conversations, or a Hugging Face Dataset2. When given an R list of conversations, it constructs the Dataset dict dynamically under conversations\_col via stats::setNames(list(dataset), conversations\_col) rather than hardcoding "conversations"2. When standardize\_sharegpt \= TRUE, it calls ct$standardiz{e}_{d}at{a}_{f}ormats(dataset)ifpresent(fallingbacktoct$standardize\_sharegpt(dataset)), then maps tokenizer.apply\_chat\_template(..., tokenize \= FALSE, add\_generation\_prompt \= FALSE) across batches to generate the "text" column2. unsloth\_train\_on\_responses\_only(trainer, instruction\_part \= NULL, response\_part \= NULL) passes explicit delimiters only when non-NULL, allowing Unsloth's auto-detection to work when omitted21. Documentation for this helper should warn users that mismatched delimiter strings (such as missing turn header tags in Gemma 3/4) can mask all dataset labels to \-100 and trigger ZeroDivisionError in Unsloth47.

### **Supervised and Vision Fine-Tuning (R/train.R, R/vision.R)**

R/train.R resolves breaking parameter differences across trl releases (v0.9.4–v0.13.0 vs v0.17.0–v0.25.0, as well as Unsloth's temporary SFTConfig max\_seq\_length regression tracked in \#10785/\#10825) by dynamically inspecting callable signatures in unsloth\_build\_trainer()4. unsloth\_build\_trainer() constructs the trainer in four steps:

> 1. Query bf16\_supported \<- isTRUE(unsloth$i{s}_{b}float1{6}_{s}upported())andinspectp{y}_{c}allabl{e}_{p}arams()fortrl$SFTConfig (if present, else transformers$TrainingArguments)andtrl$SFTTrainer2.  
> 2. Route max\_length (preferring max\_length when supported by SFTConfig, or max\_seq\_length if accepted), dataset\_text\_field, packing, and dataset\_num\_proc into the config object whenever those parameter names appear in SFTConfig's signature5.  
> 3. Instantiate trl$SFTTrainerusingprocessin{g}_{c}lass=object$tokenizer when processing\_class is in SFTTrainer's signature (falling back to tokenizer \= object\$tokenizer on older builds), forwarding dataset\_text\_field, max\_seq\_length, packing, and dataset\_num\_proc directly to SFTTrainer only if SFTConfig did not consume them2.  
> 4. Apply unsloth\_train\_on\_responses\_only(trainer, instruction\_part, response\_part) when train\_on\_responses\_only \= TRUE before returning the trainer2.

unsloth\_train() calls unsloth$FastLanguageModel$for\_training(object$model)ifexposed(ensuringmodelspreviouslyswitchedviaunslot{h}_{s}tream()returntotrainingmode),invokesunslot{h}_{b}uil{d}_{t}rainer(),executestrainer$train(), and returns invisible(object). unsloth\_export\_gguf() delegates to .export\_gguf\_internal(), passing tokenizer \= object\$tokenizer, quantization\_method \= quant\_arg, and maximum\_memory\_usage \= max\_memory\_usage explicitly by keyword per Unsloth issue \#2058 and returning the normalized .gguf file path invisibly16.  
R/vision.R implements unsloth\_load\_vision\_model(), unsloth\_add\_vision\_lora(), as\_vision\_dataset(), and unsloth\_train\_vision(). unsloth\_load\_vision\_model() wraps FastVisionModel\$from\_pretrained(), forwarding max\_seq\_length only if py\_callable\_params() confirms acceptance while still storing max\_seq\_length \= as\_py\_int(max\_seq\_length) (default 2048L) on the returned c("runsloth\_vision\_model", "runsloth\_model") list2. unsloth\_add\_vision\_lora() wraps FastVisionModel\$get\_peft\_model() with finetune\_vision\_layers, finetune\_language\_layers, finetune\_attention\_modules, finetune\_mlp\_modules, r, and lora\_alpha2. as\_vision\_dataset(image\_paths, instructions, responses, max\_size\_img \= 768L) opens images with PIL.Image\$open(), resizes dimensions exceeding max\_size\_img proportionally to control image-token VRAM consumption (matching Unsloth VLM guidance25), and returns a Python list of multimodal conversation dicts as recommended for UnslothVisionDataCollator24. unsloth\_train\_vision() calls FastVisionModel$fo{r}_{t}raining(object$model), builds unsloth$trainer$UnslothVisionDataCollator (exposing train\_on\_responses\_only, instruction\_part, and response\_part directly on the collator24), passes reticulate::dict(skip\_prepare\_dataset \= TRUE), and critically sets max\_length \= NULL (None in Python) in SFTConfig when supported so truncation never drops image tokens2.

### **Reasoning Reinforcement Learning with GRPO (R/grpo.R)**

R/grpo.R exposes unsloth\_patch\_grpo(), as\_grpo\_reward(), and unsloth\_train\_grpo(). unsloth\_patch\_grpo() invokes unsloth$PatchFastRL("GRPO",unsloth$FastLanguageModel)2. as\_grpo\_reward(r\_fn, name \= "r\_custom\_reward", pass\_kwargs \= FALSE) eliminates the fragility of the prototype bridge: it verifies is.function(r\_fn) and validates name against ^\[A-Za-z\_\]\[A-Za-z0-9\_\]\*\$, stores the R callback inside reticulate::import\_main(), and defines a Python wrapper def \<name\>(prompts, completions, \*\*kwargs): that forwards (prompts, completions, kwargs) when pass\_kwargs \= TRUE (exposing completion\_ids or dataset columns like answer28) and converts scalar numeric returns (isinstance(res, (int, float))) into \[float(res)\] so length-1 R vectors never raise TypeError: 'float' object is not iterable2. unsloth\_train\_grpo() corrects the prototype's identifier errors to trl$GRPOConfig,trl$GRPOTrainer, and adam\_beta1, calls for\_training(object$model)ifavailable,convertsdata.frameinputsviaa{s}_{h}{f}_{d}ataset(),passesprocessin{g}_{c}lass=object$tokenizer (with tokenizer signature fallback) and reward\_funcs \= as.list(reward\_funcs), and runs trainer\$train()2.

### **Real-Time Console Streaming (R/infer.R)**

unsloth\_stream(object, prompt, images \= NULL, max\_new\_tokens \= 512L, temperature \= 0.7, callback \= function(chunk) { cat(chunk); utils::flush.console() }) streams tokens asynchronously without freezing the R console2. First, it activates Unsloth's inference mode via FastVisionModel$fo{r}_{i}nference()orFastLanguageModel$for\_inference()2. Next, it applies apply\_chat\_template(..., tokenize \= FALSE, add\_generation\_prompt \= TRUE) when prompt is a list of chat turns, tokenizes text (or passes images and text to the vision processor when images is supplied on a runsloth\_vision\_model), and moves tensors to resolve\_model\_device(object\$model) rather than hardcoding "cuda"2. When temperature \<= 0, do\_sample is set to FALSE and temperature is excluded from gen\_kwargs.  
Because reticulate::iterate(streamer, ...) blocks on TextIteratorStreamer's internal queue until streamer.end() is called, passing object$model$generate directly to threading\$Thread risks hanging the R session permanently if generation fails2. Instead, unsloth\_stream() executes a Python wrapper inside the worker thread that catches any exception into a state dictionary and guarantees streamer.end() executes inside a finally: block. On the main R thread, reticulate::iterate() streams chunks to callback(), joins the worker thread, raises any captured Python exception via cli::cli\_abort(), prints a final newline, and returns the concatenated string invisibly2.

### **Local Runtimes and Hub Distribution (R/hub\_ollama.R, R/backends.R)**

R/hub\_ollama.R provides unsloth\_push\_to\_hub() and unsloth\_register\_ollama(). unsloth\_push\_to\_hub() checks HF\_TOKEN, supports "lora" (pushing adapter and tokenizer), "merged\_16bit", "merged\_4bit", and "gguf" (single or multi-quant list plus maximum\_memory\_usage), and fixes the prototype's broken {. code ...} cli formatting2. To prevent duplicate GGUF exports when called via unsloth\_export\_and\_run(..., backend \= "ollama"), GGUF creation is centralized in .export\_gguf\_internal() and .find\_exported\_gguf() inside R/utils.R: .find\_exported\_gguf() ranks .gguf files matching the requested quantization string ahead of intermediate f16 artifacts, and .register\_ollama\_from\_dir() handles Modelfile resolution and ollama create without re-exporting2. In Modelfile synthesis, writeLines(lines, modelfile\_path) is moved *outside* the if (\!is.null(eos\_token) && nzchar(eos\_token)) check so a valid Modelfile is always emitted even if eos\_token is unavailable2.  
R/backends.R implements unsloth\_export\_and\_run(), launch\_llamacpp(), and unsloth\_stop\_server(), making llama.cpp the default local runtime (backend \= c("llamacpp", "ollama", "none"))2. unsloth\_export\_and\_run() warns if save\_dir contains whitespace, exports the GGUF once, returns gguf\_path for "none", dispatches to launch\_llamacpp() for "llamacpp", or delegates to .register\_ollama\_from\_dir() for "ollama"2. For mode \= "server", launch\_llamacpp() invokes llama-server with \--model, \--host, \--port, \--n-gpu-layers, \--ctx-size, \--jinja, and extra\_args2. When processx is available, launch\_llamacpp() launches processx::process\$new() and retains the live handle on the returned "runsloth\_server" object for unsloth\_stop\_server(srv)2. Rather than relying on a brittle Sys.sleep(2), launch\_llamacpp() polls http\://{host}:{port}/health up to a configurable timeout (defaulting to 60 seconds as a runsloth safeguard) because llama-server binds its port early and returns HTTP 503 (Loading model) until ready, switching to HTTP 200 {"status":"ok"} once inference can proceed11. For mode \= "cli", it formats a clean llama-cli command (--model, \-ngl, \-c, \--jinja)2. Every @examples block and README.md snippet connecting ellmer to llama-server must use ellmer::chat\_openai\_compatible(base\_url \= srv\$base\_url, model \= "local-gguf") rather than ellmer::chat\_openai(), because ellmer 0.5.0 routes chat\_openai() to OpenAI's Responses API while llama-server serves /v1/chat/completions9.

## **Verification Strategy and R CMD check Standards**

Testing runsloth across developer workstations and CI runners requires separating offline R contract verification from GPU execution. Under Tier 1 (CPU and offline unit tests via testthat), test suites verify package loading without triggering Python initialization (reticulate::py\_available(initialize \= FALSE)), S3 class invariants, as\_py\_int() and validate\_py\_identifier() boundaries, unsloth\_add\_tokens() post-LoRA guards, .find\_exported\_gguf() quantization matching, Modelfile fallback synthesis with and without eos\_token, llama-cli command construction, and unsloth\_export\_and\_run() whitespace warnings, gating any Python calls behind skip\_if\_no\_unsloth(). Under Tier 2 (CUDA integration verification gated behind skip\_if\_no\_gpu()), end-to-end tests exercise unsloth\_doctor(), 4-bit model loading, LoRA patching, chat template formatting, unsloth\_train(..., train\_on\_responses\_only \= TRUE), unsloth\_stream(), unsloth\_export\_and\_run(..., backend \= "llamacpp"), ellmer::chat\_openai\_compatible(), and unsloth\_stop\_server()1.  
Before considering the build complete, the coding agent must pass three release-hygiene checks:

> * Run roxygen2::roxygenise() (or devtools::document()) so NAMESPACE and man/\*.Rd stay generated and synchronized with R/\*.R.  
> * Run R CMD check (rcmdcheck::rcmdcheck(args \= "--no-manual", error\_on \= "warning")) and confirm zero errors, zero warnings, and zero notes regarding missing imports (utils::flush.console(), stats::setNames(), rlang::"%\|\|%") or undocumented parameters.  
> * Verify in a clean R subprocess that library(runsloth) loads cleanly without initializing Python or invoking package installations at load time.

## **Implementation Prompt for the Local Coding Agent**

Paste the prompt below into your local coding agent inside a clean project directory (or existing runsloth/ git repository) to scaffold, implement, document, and verify the package.  
You are an expert R package engineer and Python/PyTorch ML systems developer. Scaffold, implement, document, and verify the complete runsloth R package (v0.1.0), which wraps the Python unsloth SDK via reticulate and treats llama.cpp (llama-server and llama-cli) as the first-class local inference backend alongside optional Hugging Face Hub and ollama deployment targets.

### **1\. Project Constraints & Standards**

> * Target R version: R (\>= 4.1.0) (native pipe \|\> compatibility).  
> * License: Apache License (\>= 2.0) — include both DESCRIPTION field and LICENSE file.  
> * Package dependencies in DESCRIPTION:  
  * Depends: R (\>= 4.1.0)  
  * Imports: cli, reticulate (\>= 1.34.0), rlang, stats, utils  
  * Suggests: ellmer, httr2, jsonlite, ollamar, processx, testthat (\>= 3.0.0), tibble  
  * Encoding: UTF-8, Roxygen: list(markdown \= TRUE), RoxygenNote: 7.3.1  
  * Note: Omit legacy Config/reticulate blocks that trigger unwanted auto-installs during R CMD check. Support reticulate::py\_require() optionally (opt-in via options(runsloth.use\_py\_require \= TRUE) or unsloth\_use\_managed\_python(), guarded by checking whether py\_require exists in asNamespace("reticulate")) alongside explicit install\_unsloth().  
> * Every exported function must include complete roxygen2 documentation (@param, @return, @export, and guarded @examples). Generate NAMESPACE and man/\*.Rd exclusively via roxygen2::roxygenise().  
> * Qualify or import all non-base symbols (utils::flush.console(), stats::setNames(), @importFrom rlang %\|\|%) so R CMD check passes with 0 errors, 0 warnings, and 0 notes on global variables.  
> * Never initialize Python during library(runsloth) or R CMD check (delay\_load \= TRUE must hold until an Unsloth function actually accesses Python).

### **2\. Required Package Directory Layout**

Create the full package structure:

> * DESCRIPTION, NAMESPACE (generated), LICENSE, README.md, .Rbuildignore  
> * R/zzz.R: Delayed Python bindings and Unsloth import-order enforcement.  
> * R/utils.R: Internal interop and export helpers (as\_py\_int, as\_py\_dtype, py\_callable\_params, validate\_py\_identifier, resolve\_model\_device, .export\_gguf\_internal, .find\_exported\_gguf).  
> * R/install.R: install\_unsloth(), unsloth\_use\_managed\_python(), and unsloth\_doctor().  
> * R/model.R: unsloth\_load\_model(), unsloth\_add\_tokens(), unsloth\_add\_lora().  
> * R/chat\_templates.R: unsloth\_list\_chat\_templates(), unsloth\_set\_chat\_template(), unsloth\_apply\_chat\_template(), unsloth\_train\_on\_responses\_only().  
> * R/train.R: as\_hf\_dataset(), unsloth\_build\_trainer(), unsloth\_train(), unsloth\_export\_gguf().  
> * R/vision.R: unsloth\_load\_vision\_model(), unsloth\_add\_vision\_lora(), as\_vision\_dataset(), unsloth\_train\_vision().  
> * R/grpo.R: unsloth\_patch\_grpo(), as\_grpo\_reward(), unsloth\_train\_grpo().  
> * R/infer.R: unsloth\_stream().  
> * R/hub\_ollama.R: unsloth\_push\_to\_hub(), unsloth\_register\_ollama(), .register\_ollama\_from\_dir().  
> * R/backends.R: unsloth\_export\_and\_run(), launch\_llamacpp(), unsloth\_stop\_server().  
> * tests/testthat.R and unit test suites under tests/testthat/.

### **3\. Critical Architectural & Bug-Fix Specifications**

#### **A. Import Order Enforcement (R/zzz.R)**

> * Python's unsloth MUST be imported BEFORE trl, transformers, and peft so Unsloth's kernel and trainer patches take effect.  
> * Declare package-level bindings unsloth, trl, datasets, transformers, torch, inspect initialized to NULL.  
> * Write ensure\_unsloth() to force evaluation of the unsloth module proxy (force(unsloth\$FastLanguageModel)).  
> * Attach delay\_load \= list(before\_load \= ensure\_unsloth) when importing trl, transformers, and datasets inside .onLoad().

#### **B. Dependency Installer & Diagnostics (R/install.R)**

> * install\_unsloth(envname \= "r-unsloth", method \= c("auto", "virtualenv", "conda"), with\_xformers \= FALSE, upgrade \= FALSE):  
  * Do NOT include "xformers" unless with\_xformers \= TRUE (Unsloth uses PyTorch SDPA natively when xformers is omitted, preventing CUDA wheel mismatches).  
  * Support installing "unsloth", "unsloth\_zoo", "trl", "peft", "accelerate", "bitsandbytes", "datasets" via reticulate::py\_install(..., pip \= TRUE). When upgrade \= TRUE, apply pip\_options \= c("--upgrade", "--force-reinstall", "--no-cache-dir", "--no-deps") on c("unsloth", "unsloth\_zoo") and remind users to remove stale unsloth\_compiled\_cache directories if needed.  
  * Tailor the post-install activation hint to reticulate::use\_condaenv() for method \== "conda" and reticulate::use\_virtualenv() otherwise.  
> * unsloth\_use\_managed\_python(packages \= c("unsloth", "trl", "datasets", "transformers"), python\_version \= NULL): check exists("py\_require", envir \= asNamespace("reticulate")), call reticulate::py\_require(), and abort cleanly with an upgrade message if the installed reticulate lacks py\_require().  
> * unsloth\_doctor(): report Python availability, torch \+ CUDA \+ is\_bfloat16\_supported(), versions of unsloth, unsloth\_zoo, trl, transformers, and PATH lookup results for llama-server, llama-cli, and ollama.

#### **C. R-to-Python Interop & Model Loading (R/utils.R, R/model.R)**

> * Cast all integer Python kwargs via as\_py\_int() (as.integer()).  
> * Wrap vector kwargs expecting Python lists (target\_modules, multi-quant quantization\_method, reward\_funcs, new\_tokens) in as.list() so length-1 R vectors never collapse into Python scalars.  
> * unsloth\_load\_model(): support model\_name \= "unsloth/Llama-3.2-3B-Instruct-bnb-4bit", max\_seq\_length \= 2048L, load\_in\_4bit \= TRUE, load\_in\_8bit \= FALSE, full\_finetuning \= FALSE, dtype \= NULL, token \= NULL, and .... Enforce that at most one of load\_in\_4bit, load\_in\_8bit, full\_finetuning is TRUE. Convert string "float16"/"fp16" and "bfloat16"/"bf16" dtype arguments via as\_py\_dtype() while passing NULL through as Python None. Only forward optional flags (load\_in\_8bit, full\_finetuning, token) if present in py\_callable\_params(unsloth$FastLanguageModel$from\_pretrained) or explicitly non-default. Return class "runsloth\_model" containing model, tokenizer, max\_seq\_length, has\_lora \= FALSE, and is\_vision \= FALSE.  
> * unsloth\_add\_tokens(object, new\_tokens): call unsloth$ad{d}_{n}e{w}_{t}okens(object$model, object$tokenizer,ne{w}_{t}okens=as.list(ne{w}_{t}okens)).AbortwithaclierrorifisTRUE(object$has\_lora).  
> * unsloth\_add\_lora(): wrap FastLanguageModel$ge{t}_{p}ef{t}_{m}odel(),setobject$has\_lora \<- TRUE, and return object.

#### **D. Chat Templates (R/chat\_templates.R)**

> * unsloth\_list\_chat\_templates(): return template names via reticulate::py\_to\_r(reticulate::import\_builtins()$list(ct$CHAT\_TEMPLATES\$keys())).  
> * unsloth\_set\_chat\_template(): wrap ct$ge{t}_{c}ha{t}_{t}emplate()withrole/content/user/assistantmapping,ma{p}_{e}o{s}_{t}oken=TRUE,syste{m}_{m}essage=NULL,storingobject$chat\_template.  
> * unsloth\_apply\_chat\_template(object, dataset, conversations\_col \= "conversations", standardize\_sharegpt \= TRUE):  
  * When dataset is an R list of conversations (not a data.frame or Python object), build the Dataset dict dynamically under conversations\_col using stats::setNames(list(dataset), conversations\_col) instead of hardcoding "conversations".  
  * When standardize\_sharegpt \= TRUE, prefer ct$standardiz{e}_{d}at{a}_{f}ormats(dataset)ifexposedonunsloth.cha{t}_{t}emplates,fallingbacktoct$standardize\_sharegpt(dataset).  
  * Format conversations via batched dataset\$map() calling tokenizer.apply\_chat\_template(..., tokenize=False, add\_generation\_prompt=False).  
> * unsloth\_train\_on\_responses\_only(trainer, instruction\_part \= NULL, response\_part \= NULL): pass instruction\_part and response\_part only when non-NULL so Unsloth auto-detects delimiters when omitted. Document the Gemma/ChatML ZeroDivisionError caveat when custom delimiters mask all tokens.

#### **E. Dataset Conversion & SFT Trainer Compatibility (R/train.R)**

> * as\_hf\_dataset(df): transform each atomic column of df via as.list() while keeping list-columns untouched so 1-row data.frame objects never collapse to Python scalars in datasets$Dataset$from\_dict().  
> * unsloth\_build\_trainer() and unsloth\_train():  
  * Inspect py\_callable\_params() on trl$SFTConfig(ifavailable,elsetransformers$TrainingArguments) and trl\$SFTTrainer so max\_length/max\_seq\_length, dataset\_text\_field, packing, dataset\_num\_proc, and processing\_class/tokenizer route cleanly across both older (v0.9.4–v0.13.0) and newer (v0.17.0–v0.25.0) trl releases.  
  * Ensure FastLanguageModel$fo{r}_{t}raining(object$model) runs (if attribute exists) before training.  
  * Expose train\_on\_responses\_only \= FALSE, instruction\_part \= NULL, response\_part \= NULL in both unsloth\_build\_trainer() and unsloth\_train(), returning invisible(object) from unsloth\_train().  
> * unsloth\_export\_gguf(object, save\_dir \= "model\_gguf", quantization\_method \= "q4\_k\_m", max\_memory\_usage \= 0.75): call .export\_gguf\_internal() and return the exported .gguf path invisibly.

#### **F. Vision Fine-Tuning (R/vision.R)**

> * unsloth\_load\_vision\_model(model\_name \= "unsloth/Llama-3.2-11B-Vision-Instruct-bnb-4bit", load\_in\_4bit \= TRUE, max\_seq\_length \= 2048L): wrap FastVisionModel\$from\_pretrained(), store max\_seq\_length \= as\_py\_int(max\_seq\_length) and is\_vision \= TRUE, and return class c("runsloth\_vision\_model", "runsloth\_model").  
> * unsloth\_add\_vision\_lora(): wrap FastVisionModel\$get\_peft\_model() with finetune\_vision\_layers, finetune\_language\_layers, finetune\_attention\_modules, finetune\_mlp\_modules, r, lora\_alpha.  
> * as\_vision\_dataset(image\_paths, instructions, responses, max\_size\_img \= 768L): load images via PIL.Image\$open(), proportionally resize images exceeding max\_size\_img, and return a Python list of conversation dicts compatible with UnslothVisionDataCollator.  
> * unsloth\_train\_vision(): expose hyperparameters plus train\_on\_responses\_only \= FALSE, instruction\_part \= NULL, response\_part \= NULL (passed to UnslothVisionDataCollator when enabled); use reticulate::dict(skip\_prepare\_dataset \= TRUE); explicitly set max\_length \= NULL (None in Python) in SFTConfig when supported so image tokens are never truncated; resolve processing\_class vs tokenizer via signature inspection.

#### **G. GRPO Reasoning RL (R/grpo.R)**

> * Fix ALL prototype typos: use trl$GRPOConfig(capitalO,notzero0),trl$GRPOTrainer, and adam\_beta1 (digit 1, not letter l).  
> * unsloth\_patch\_grpo(): invoke unsloth$PatchFastRL("GRPO",unsloth$FastLanguageModel).  
> * as\_grpo\_reward(r\_fn, name \= "r\_custom\_reward", pass\_kwargs \= FALSE):  
  * Validate is.function(r\_fn) and verify name matches ^\[A-Za-z\_\]\[A-Za-z0-9\_\]\*\$.  
  * Wrap via Python def \<name\>(prompts, completions, \*\*kwargs): so scalar int/float returns from R length-1 vectors become \[float(res)\] instead of raising TypeError, and forward kwargs when pass\_kwargs \= TRUE.  
> * unsloth\_train\_grpo(): call for\_training(object$model)ifexposed,convertdata.frameviaa{s}_{h}{f}_{d}ataset(),useprocessin{g}_{c}lass=object$tokenizer (with signature fallback to tokenizer), wrap reward\_funcs \= as.list(reward\_funcs), and run trainer\$train().

#### **H. Non-Blocking Token Streaming (R/infer.R)**

> * unsloth\_stream(object, prompt, images \= NULL, max\_new\_tokens \= 512L, temperature \= 0.7, callback \= function(chunk) { cat(chunk); utils::flush.console() }):  
  * Enable FastVisionModel$fo{r}_{i}nference()orFastLanguageModel$for\_inference().  
  * Support plain text prompts, chat message lists via apply\_chat\_template(..., tokenize \= FALSE, add\_generation\_prompt \= TRUE), and optional images on runsloth\_vision\_model.  
  * Resolve tensor device via resolve\_model\_device(object\$model) instead of hardcoding "cuda".  
  * Set do\_sample \= temperature \> 0; include temperature in gen\_kwargs only when do\_sample is TRUE.  
  * Wrap model$generate(**ge{n}_{k}wargs)insideaPythontry...exceptException...finally:streamer.end()helperforthreading$Thread so worker errors never deadlock reticulate::iterate(). Re-raise any captured Python error cleanly after thread\$join().

#### **I. Hub Publishing, Ollama, & llama.cpp First-Class Runner (R/utils.R, R/hub\_ollama.R, R/backends.R)**

> * Implement shared .export\_gguf\_internal() and .find\_exported\_gguf(save\_dir, quantization\_method) in R/utils.R so GGUF conversion runs exactly ONCE in unsloth\_export\_and\_run(..., backend \= "ollama"). Prefer .gguf files matching the requested quantization string ahead of intermediate f16 files.  
> * Fix all malformed cli inline markup ({.code ...}, {.file .gguf}).  
> * In unsloth\_register\_ollama() and .register\_ollama\_from\_dir(): move writeLines(lines, modelfile\_path) OUTSIDE the if (\!is.null(eos\_token) && nzchar(eos\_token)) conditional so fallback Modelfile creation always succeeds.  
> * In launch\_llamacpp() (R/backends.R):  
  * For mode \= "server", build args c("--model", gguf\_path, "--host", host, "--port", as.character(port), "--n-gpu-layers", as.character(n\_gpu\_layers), "--ctx-size", as.character(ctx\_size), "--jinja", extra\_args).  
  * Use processx::process\$new(bin, args \= args, stdout \= "\|", stderr \= "\|") when processx is installed (enabling unsloth\_stop\_server(server) and stderr reporting on crash), with system2 fallback otherwise.  
  * Poll http\://{host}:{port}/health until HTTP 200 (default timeout \= 60 seconds) rather than sleeping blindly, since llama-server returns HTTP 503 while weights load.  
  * Return a "runsloth\_server" S3 list (backend, base\_url, gguf\_path, host, port, process).  
  * Implement unsloth\_stop\_server(server).  
  * For mode \= "cli", format and return a valid llama-cli command (--model, \-ngl, \-c, \--jinja).  
> * In README.md and @examples, connect ellmer to llama-server using ellmer::chat\_openai\_compatible(base\_url \= srv\$base\_url, model \= "local-gguf") (NOT ellmer::chat\_openai()).

### **4\. Testing & Verification Protocol**

> 1. Add tests/testthat.R and test files covering:  
   * Package load safety (reticulate::py\_available(initialize \= FALSE) stays unmodified upon library(runsloth)).  
   * Pure-R logic: validate\_py\_identifier(), as\_py\_int(), unsloth\_add\_tokens() post-LoRA error, launch\_llamacpp(..., mode \= "cli") command formatting, .find\_exported\_gguf() quantization matching, Modelfile synthesis with and without eos\_token, and unsloth\_export\_and\_run() whitespace warning.  
   * Python/CUDA integration tests guarded behind skip\_if\_no\_unsloth() and skip\_if\_no\_gpu().  
> 2. Run and verify all three commands pass cleanly:  
   * Rscript \-e "roxygen2::roxygenise()"  
   * Rscript \-e "testthat::test\_local()"  
   * Rscript \-e "rcmdcheck::rcmdcheck(args \= '--no-manual', error\_on \= 'warning')"  
> 3. Summarize the created files, test pass/skip counts, and rcmdcheck output upon completion.

Once the coding agent completes scaffolding and passes R CMD check with zero errors or warnings on a CPU host, validate the Tier 2 GPU smoke workflow on a CUDA machine by executing unsloth\_doctor(), fine-tuning a compact 4-bit model (such as unsloth/Qwen2.5-3B-Instruct-bnb-4bit or unsloth/Llama-3.2-3B-Instruct-bnb-4bit), exporting to GGUF, verifying launch\_llamacpp() awaits HTTP 200 on /health, and querying the live server through ellmer::chat\_openai\_compatible()1.

#### **Works cited**

> 1. runsloth.pdf  
> 2.   
> 3. Unsloth Integration \- Hugging Face, [https\://huggingface.co/docs/trl/unsloth\_integration](https://huggingface.co/docs/trl/unsloth_integration)  
> 4. Supervised Fine-tuning Trainer \- Hugging Face, [https\://huggingface.co/docs/trl/v0.17.0/en/sft\_trainer](https://huggingface.co/docs/trl/v0.17.0/en/sft_trainer)  
> 5. SFTConfig.\_\_init\_\_() got an unexpected keyword argument ... \- GitHub, [https\://github.com/unslothai/unsloth/issues/10785](https://github.com/unslothai/unsloth/issues/10785)  
> 6. max\_seq\_length is no longer a valid param in SFTTrainer \#1171, [https\://github.com/huggingface/course/issues/1171](https://github.com/huggingface/course/issues/1171)  
> 7. Traverse a Python iterator or generator — as\_iterator • reticulate, [https\://rstudio.github.io/reticulate/reference/iterate.html](https://rstudio.github.io/reticulate/reference/iterate.html)  
> 8. Using Python in R with reticulate : : CHEAT SHEET \- GitHub, [https\://raw.githubusercontent.com/rstudio/cheatsheets/main/reticulate.pdf](https://raw.githubusercontent.com/rstudio/cheatsheets/main/reticulate.pdf)  
> 9. Chat with a local Ollama model — chat\_ollama \- ellmer, [https\://ellmer.tidyverse.org/reference/chat\_ollama.html](https://ellmer.tidyverse.org/reference/chat_ollama.html)  
> 10. Chat with an OpenAI model — chat\_openai \- ellmer, [https\://ellmer.tidyverse.org/reference/chat\_openai.html](https://ellmer.tidyverse.org/reference/chat_openai.html)  
> 11. How to check llama.cpp server health \- Simplified Guide, [https\://www\.simplified.guide/llama-cpp/server-check-health](https://www.simplified.guide/llama-cpp/server-check-health)  
> 12. Changelog • reticulate \- rstudio.github.io, [https\://rstudio.github.io/reticulate/news/index.html](https://rstudio.github.io/reticulate/news/index.html)  
> 13. Using reticulate in an R Package \- rstudio.github.io, [https\://rstudio.github.io/reticulate/articles/package.html](https://rstudio.github.io/reticulate/articles/package.html)  
> 14. Declare Python Requirements — py\_require • reticulate, [https\://rstudio.github.io/reticulate/reference/py\_require.html](https://rstudio.github.io/reticulate/reference/py_require.html)  
> 15. \[Bug\]Exception error due to indentation \#3665 \- unsloth \- GitHub, [https\://github.com/unslothai/unsloth/issues/3665](https://github.com/unslothai/unsloth/issues/3665)  
> 16. Error While Converting & Uploading GGUF Model After Fine-Tuning, [https\://github.com/unslothai/unsloth/issues/2058](https://github.com/unslothai/unsloth/issues/2058)  
> 17. \[Bug\] Error when import unsloth · Issue \#3293 \- GitHub, [https\://github.com/unslothai/unsloth/issues/3293](https://github.com/unslothai/unsloth/issues/3293)  
> 18. Fine-tuning LLMs with Blackwell, RTX 50 series & Unsloth, [https\://unsloth.ai/docs/blog/fine-tuning-llms-with-blackwell-rtx-50-series-and-unsloth](https://unsloth.ai/docs/blog/fine-tuning-llms-with-blackwell-rtx-50-series-and-unsloth)  
> 19. Chat Templates \| Unsloth Documentation, [https\://unsloth.ai/docs/basics/chat-templates](https://unsloth.ai/docs/basics/chat-templates)  
> 20. metascroy/Qwen3-4B-int8-int4-unsloth-v2 \- Hugging Face, [https\://huggingface.co/metascroy/Qwen3-4B-int8-int4-unsloth-v2](https://huggingface.co/metascroy/Qwen3-4B-int8-int4-unsloth-v2)  
> 21. Gemma3\_(4B).ipynb \- Google Colab, [https\://colab.research.google.com/github/unslothai/notebooks/blob/main/nb/Gemma3\_(4B).ipynb](https://colab.research.google.com/github/unslothai/notebooks/blob/main/nb/Gemma3_\(4B\).ipynb)  
> 22. SFT Trainer \- Hugging Face, [https\://huggingface.co/docs/trl/sft\_trainer](https://huggingface.co/docs/trl/sft_trainer)  
> 23. Generalized Knowledge Distillation Trainer \- Hugging Face, [https\://huggingface.co/docs/trl/gkd\_trainer](https://huggingface.co/docs/trl/gkd_trainer)  
> 24. Vision Fine-tuning \| Unsloth Documentation, [https\://unsloth.ai/docs/basics/vision-fine-tuning](https://unsloth.ai/docs/basics/vision-fine-tuning)  
> 25. Efficient Fine-Tuning for Vision-Language Models (VLMs) with Unsloth, [https\://colab.research.google.com/drive/1zk\_naZas436nX7fZ8Wq9MB3Gwvy4YIy4?usp=sharing](https://colab.research.google.com/drive/1zk_naZas436nX7fZ8Wq9MB3Gwvy4YIy4?usp=sharing)  
> 26. SFT Trainer \- Hugging Face, [https\://huggingface.co/docs/trl/en/sft\_trainer](https://huggingface.co/docs/trl/en/sft_trainer)  
> 27. GRPO Trainer \- Hugging Face, [https\://huggingface.co/docs/trl/grpo\_trainer](https://huggingface.co/docs/trl/grpo_trainer)  
> 28. Asynchronous GRPO Trainer \- Hugging Face, [https\://huggingface.co/docs/trl/en/async\_grpo\_trainer](https://huggingface.co/docs/trl/en/async_grpo_trainer)  
> 29. Unsloth Docs \| Unsloth Documentation, [https\://unsloth.ai/docs](https://unsloth.ai/docs)  
> 30. Probably the Easiest Tutorial for Python Threads, Processes and GIL, [https\://towardsdatascience.com/dont-know-what-is-python-gil-this-may-be-the-easiest-tutorial-3b99805d2225/](https://towardsdatascience.com/dont-know-what-is-python-gil-this-may-be-the-easiest-tutorial-3b99805d2225/)  
> 31. Saving to GGUF \| Unsloth Documentation, [https\://unsloth.ai/docs/basics/inference-and-deployment/saving-to-gguf](https://unsloth.ai/docs/basics/inference-and-deployment/saving-to-gguf)  
> 32. llama.cpp/tools/server/README.md at master · ggml-org ... \- GitHub, [https\://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md?plain=1](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md?plain=1)  
> 33. SFT Trainer \- Hugging Face, [https\://huggingface.co/docs/trl/v0.20.0/sft\_trainer](https://huggingface.co/docs/trl/v0.20.0/sft_trainer)  
> 34. OpenEnv Integration for Training LLMs with Environments, [https\://huggingface.co/docs/trl/v0.25.0/en/openenv](https://huggingface.co/docs/trl/v0.25.0/en/openenv)  
> 35. 单机多卡预训练BUG · Issue \#7604 · hiyouga/LlamaFactory \- GitHub, [https\://github.com/hiyouga/LlamaFactory/issues/7604](https://github.com/hiyouga/LlamaFactory/issues/7604)  
> 36. 使用unsloth加速报错 · Issue \#7177 · hiyouga/LlamaFactory \- GitHub, [https\://github.com/hiyouga/LlamaFactory/issues/7177](https://github.com/hiyouga/LlamaFactory/issues/7177)  
> 37. Chat with an OpenAI-compatible model — chat\_openai\_compatible, [https\://ellmer.tidyverse.org/reference/chat\_openai\_compatible.html](https://ellmer.tidyverse.org/reference/chat_openai_compatible.html)  
> 38. Getting Started \| unslothai/unsloth \| DeepWiki, [https\://deepwiki.com/unslothai/unsloth/2-getting-started](https://deepwiki.com/unslothai/unsloth/2-getting-started)  
> 39. GRPO Qwen3 0.6B on GSM8K \- Kaggle, [https\://www\.kaggle.com/code/sushovansaha9/grpo-qwen3-5-2b-on-gsm8k](https://www.kaggle.com/code/sushovansaha9/grpo-qwen3-5-2b-on-gsm8k)  
> 40. 'GRPOConfig' object has no attribute 'unsloth\_grpo\_mini\_batch, [https\://github.com/unslothai/unsloth/issues/3931](https://github.com/unslothai/unsloth/issues/3931)  
> 41. Use Python with R with reticulate :: Cheatsheet \- rstudio.github.io, [https\://rstudio.github.io/cheatsheets/html/reticulate.html](https://rstudio.github.io/cheatsheets/html/reticulate.html)  
> 42. module 'torch.compiler' has no attribute 'set\_stance' · Issue \#3025, [https\://github.com/unslothai/unsloth/issues/3025](https://github.com/unslothai/unsloth/issues/3025)  
> 43. Installation Guide for unsloth on Windows · Issue \#402 \- GitHub, [https\://github.com/unslothai/unsloth/issues/402](https://github.com/unslothai/unsloth/issues/402)  
> 44. Run reticulate::py\_require() once on package installation, [https\://forum.posit.co/t/run-reticulate-py-require-once-on-package-installation/202463](https://forum.posit.co/t/run-reticulate-py-require-once-on-package-installation/202463)  
> 45. 使用Unsloth微调DeepSeek-R1蒸馏模型：低显存高效训练实践, [https\://juejin.cn/post/7501147702668623912](https://juejin.cn/post/7501147702668623912)  
> 46. Using the CLI \- Llama.cpp, [https\://llama.app/docs/cli](https://llama.app/docs/cli)  
> 47. Issue with finetuning Gemma 3 with "train\_on\_responses\_only", [https\://www\.reddit.com/r/unsloth/comments/1l8beoa/issue\_with\_finetuning\_gemma\_3\_with\_train\_on/](https://www.reddit.com/r/unsloth/comments/1l8beoa/issue_with_finetuning_gemma_3_with_train_on/)  
> 48. Supervised Fine-tuning Trainer \- Hugging Face, [https\://huggingface.co/docs/trl/v0.12.1/sft\_trainer](https://huggingface.co/docs/trl/v0.12.1/sft_trainer)  
> 49. Supervised Fine-tuning Trainer \- Hugging Face, [https\://huggingface.co/docs/trl/v0.9.4/sft\_trainer](https://huggingface.co/docs/trl/v0.9.4/sft_trainer)  
> 50. Supervised Fine-tuning Trainer \- Hugging Face, [https\://huggingface.co/docs/trl/v0.13.0/sft\_trainer](https://huggingface.co/docs/trl/v0.13.0/sft_trainer)  
> 51. Kaggle Mistral Nemo 12b Unsloth notebook, [https\://www\.kaggle.com/code/danielhanchen/kaggle-mistral-nemo-12b-unsloth-notebook](https://www.kaggle.com/code/danielhanchen/kaggle-mistral-nemo-12b-unsloth-notebook)  
> 52. Trainer Chưng cất Logit Trực tuyến Chung (GOLD) \- Hugging Face, [https\://huggingface.co/docs/trl/vi/gold\_trainer](https://huggingface.co/docs/trl/vi/gold_trainer)  
> 53. unsloth/Llama-3.2-90B-Vision-bnb-4bit · How to setup this model, [https\://huggingface.co/unsloth/Llama-3.2-90B-Vision-bnb-4bit/discussions/1](https://huggingface.co/unsloth/Llama-3.2-90B-Vision-bnb-4bit/discussions/1)  
> 54. Unsloth Inference \| Unsloth Documentation, [https\://unsloth.ai/docs/basics/inference-and-deployment/unsloth-inference](https://unsloth.ai/docs/basics/inference-and-deployment/unsloth-inference)  
> 55. llama-server Command Line Overview \- YouTube \- YouTube, [https\://www\.youtube.com/watch?v=N-Mc7\_3z3uU](https://www.youtube.com/watch?v=N-Mc7_3z3uU)  
> 56. llama-cli help reformatted, organized, fleshed out and examples, [https\://github.com/ggml-org/llama.cpp/discussions/15709](https://github.com/ggml-org/llama.cpp/discussions/15709)  
> 57. allow preloading conversation with \-p and add \-st / \--single-turn, [https\://app.semanticdiff.com/gh/ggml-org/llama.cpp/pull/12145/overview](https://app.semanticdiff.com/gh/ggml-org/llama.cpp/pull/12145/overview)