.DEFAULT_GOAL := help

BUILD_DIR ?= /tmp/opencode/runsloth

.PHONY: help document test check build install

help: ## Show available development commands
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / { printf "  %-12s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

document: ## Generate NAMESPACE and help pages with roxygen2
	Rscript -e 'roxygen2::roxygenise()'

test: ## Run the complete testthat suite
	Rscript -e 'testthat::test_local()'

check: ## Run R CMD check, allowing unavailable optional Suggests
	_R_CHECK_FORCE_SUGGESTS_=false Rscript -e 'rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")'

build: ## Build a source tarball under BUILD_DIR
	mkdir -p "$(BUILD_DIR)"
	cd "$(BUILD_DIR)" && R CMD build --no-build-vignettes --no-manual "$(CURDIR)"

install: ## Install the package into the active R library
	R CMD INSTALL .
