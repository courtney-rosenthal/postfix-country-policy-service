DIR_LIB = /usr/libexec/postfix

ALL = pcps.pl

INSTALL = $(DIR_LIB)/pcps.pl

all : $(ALL)

install : $(INSTALL)

$(DIR_LIB)/pcps.pl : pcps.pl
	install -m 555 $< $@
