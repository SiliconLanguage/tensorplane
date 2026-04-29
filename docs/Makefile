# Minimal makefile for Sphinx documentation
#

# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
SOURCEDIR     = source
BUILDDIR      = build

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

.PHONY: help whitepaper Makefile

# --- Whitepaper PDF Generation ---
WHITEPAPER_DIR := whitepapers/Supercomputing_0_Kernel_Storage_Virtualization
WHITEPAPER_MD  := $(WHITEPAPER_DIR)/README.md
WHITEPAPER_PDF := $(WHITEPAPER_DIR)/Ping_Long_AI_Supercomputing_0_Kernel_Storage_Architecture.pdf

whitepaper:
	@echo "Building Whitepaper PDF..."
	pandoc $(WHITEPAPER_MD) -o $(WHITEPAPER_PDF) --pdf-engine=xelatex -V geometry:margin=1in
	@echo "Whitepaper PDF generated successfully."
# ----------------------------------

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
