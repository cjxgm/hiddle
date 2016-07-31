.PHONY: all clean cleanall rebuild test install uninstall

all:
	test $$EUID -ne 0 && nimble build || echo skipped building because you are root
clean:
	nimble clean
cleanall: clean
rebuild: cleanall all
test: all
	./build/hiddle -v
install: all
	install -svm 755 ./build/hiddle /usr/local/bin/
uninstall:
	rm -f /usr/local/bin/hiddle

