import os
import sys

# Add the project root to the path for autodoc
sys.path.insert(0, os.path.abspath('../..'))

# -- Project information -----------------------------------------------------
project = 'Tensorplane AI Foundry'
copyright = '2026, Ping Long'
author = 'Ping Long'

# -- General configuration ---------------------------------------------------
extensions = [
    'sphinx.ext.autodoc',     # Pull documentation from docstrings
    'sphinx.ext.napoleon',    # Support for NumPy and Google style docstrings
    'sphinx_rtd_theme',       # Read the Docs theme
]

templates_path = ['_templates']
exclude_patterns = []

# -- Options for HTML output -------------------------------------------------
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']

# Set master doc (useful for some ReadTheDocs environments)
master_doc = 'index'
