
all:
	$(CC) -Wall -g -O3 -ObjC \
		-framework Foundation -framework AppKit \
		-o pbpaste_unified \
		pbpaste_unified.m
install: all
	cp pbpaste_unified /usr/local/bin/
clean:
	find . \( -name '*~' -or -name '#*#' -or -name '*.o' \
		  -or -name 'pbpaste_unified' -or -name 'pbpaste_unified.dSYM' \) \
		-exec rm -rfv {} \;
	rm -rfv *.dSYM/ pbpaste_unified;
