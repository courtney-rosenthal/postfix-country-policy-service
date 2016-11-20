DIR_LIB = /usr/lib/postfix

ALL = pcps.pl

INSTALL = $(DIR_LIB)/pcps.pl

all : $(ALL)

install : $(INSTALL)

$(DIR_LIB)/pcps.pl : pcps.pl
	install -m 555 $< $@

