
PROG=tex_nine
VERSION=1.2.1
RELEASE=$(PROG)-$(VERSION)
VIMFILES:=$(shell find -name *.vim) 

define VANILLA_SKELETON
% vim:tw=72 sw=2 ft=tex
%         File: $${_file}
% Date Created: $${_date_created}
%  Last Change: 
%       Author: $${_author}
\documentclass[12pt,a4paper]{article}
\usepackage{amsmath, amssymb}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage[english]{babel}

\begin{document}


\end{document}
endef
export VANILLA_SKELETON

all: help

help:
	@echo "\`make dist' to make a release."

dist: version skeleton ../$(RELEASE).tar.gz
	
../$(RELEASE).tar.gz: $(VIMFILES)
	tar czvf ../$(RELEASE).tar.gz ../$(RELEASE) \
	    --exclude=.*.swp \
	    --exclude=*.pyc
version:
	@echo "Updating $(PROG) to version number $(VERSION)..."
	@sed -r -i "s/\"( *Version:[ \t]*)[0-9].*/\"\1$(VERSION)/g" $(VIMFILES)

skeleton:
	if [ -n "$$(ls -A ftplugin/TeX_9/skeleton)" ]; then \
	    mv ftplugin/TeX_9/skeleton/* ~;\
	fi
	echo "$$VANILLA_SKELETON" > ftplugin/TeX_9/skeleton/tex_skeleton.tex

.PHONY: version dist skeleton help
