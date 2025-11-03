# 
# Custom termbox makefile without PIC
# termbox2.h v2.5.0
#
termbox_cflags:=-std=c99 -Wall -Wextra -pedantic -Wno-unused-result -g -O0 -D_XOPEN_SOURCE -D_DEFAULT_SOURCE $(CFLAGS)
termbox_h:=termbox2.h
termbox_o:=termbox2.o
termbox_a:=libtermbox2.a

all: $(termbox_a)

#$(CC) -DTB_IMPL -DTB_LIB_OPTS -fPIC -xc -c $(termbox_cflags) $(termbox_h) -o $@
$(termbox_o): $(termbox_h)
	$(CC) -DTB_IMPL -DTB_LIB_OPTS -xc -c $(termbox_cflags) $(termbox_h) -o $@

$(termbox_a): $(termbox_o)
	$(AR) rcs $@ $(termbox_o)

terminfo:
	@echo "terminfo codegen ..."
	awk -vg=0 'g==0{print} /BEGIN codegen h/{g=1; system("./codegen.sh h")} /END codegen h/{g=0; print} g==1{next}' termbox2.h >termbox2.h.tmp && mv -vf termbox2.h.tmp termbox2.h
	awk -vg=0 'g==0{print} /BEGIN codegen c/{g=1; system("./codegen.sh c")} /END codegen c/{g=0; print} g==1{next}' termbox2.h >termbox2.h.tmp && mv -vf termbox2.h.tmp termbox2.h

format:
	clang-format -i termbox2.h

lib:
	@echo "lib ..."
	$(MAKE) $(termbox_a)

clean:
	rm -f $(termbox_o) $(termbox_a) 

.PHONY: all lib terminfo clean
