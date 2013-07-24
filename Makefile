
VERSION=`git describe`
PROGRAM=tex_nine
NAME=$(PROGRAM)-$(VERSION).tar.gz

all:
	git archive -o $(NAME) -9 $(VERSION)

