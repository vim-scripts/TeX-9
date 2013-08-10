
VERSION=`git describe`
PROGRAM=tex_nine
NAME=$(PROGRAM)-$(VERSION)

all:
	git archive --prefix=$(NAME)/ -o $(NAME).tar.gz -9 $(VERSION)

