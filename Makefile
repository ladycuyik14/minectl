install:
	./install.sh --install

uninstall:
	./install.sh --uninstall

purge: 
	./install.sh --purge

all: install
