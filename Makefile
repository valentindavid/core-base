DPKG_ARCH := $(shell dpkg --print-architecture)
LTS = jammy
BASE := $(LTS)-base-$(DPKG_ARCH).tar.gz
URL := http://cdimage.ubuntu.com/ubuntu-base/$(LTS)/daily/current/$(BASE)

# dir that contans the filesystem that must be checked
TESTDIR ?= "prime/"

.PHONY: all
all: check
	# nothing

$(BASE):
	wget $(URL)

.PHONY: pull
pull: $(BASE)


SPAWN_ARGS=--robind $(SNAPCRAFT_STAGE)/local-debs /install-data/local-debs

.PHONY: install
install: $(BASE)
	# install base
	set -ex; if [ -z "$(DESTDIR)" ]; then \
		echo "no DESTDIR set"; \
		exit 1; \
	fi
	rm -rf $(DESTDIR)
	mkdir -p $(DESTDIR)
	tar -x --xattrs-include=* -f $(BASE) -C $(DESTDIR)
	# copy static files verbatim
	/bin/cp -a static/* $(DESTDIR)
	# customize
	set -ex; for f in ./hooks/[0-9]*.chroot; do \
		if ! ./chroot-tool.sh spawn $(DESTDIR) $(SPAWN_ARGS) \
	             --robind $$f /install-data/script.sh -- /install-data/script.sh; then \
                    exit 1; \
                fi; \
	done;
	rm -rf $(DESTDIR)/install-data

	# only generate manifest and dpkg.yaml files for lp build
	if [ -e /build/core22 ]; then \
		echo $$f; \
		/bin/cp $(DESTDIR)/usr/share/snappy/dpkg.list /build/core22/core22-$$(date +%Y%m%d%H%M)_$(DPKG_ARCH).manifest; \
		/bin/cp $(DESTDIR)/usr/share/snappy/dpkg.yaml /build/core22/core22-$$(date +%Y%m%d%H%M)_$(DPKG_ARCH).dpkg.yaml; \
	fi;

.PHONY: check
check:
	# exclude "useless cat" from checks, while useless they also make
	# some code more readable
	shellcheck -e SC2002 hooks/*

.PHONY: test
test:
	# run tests - each hook should have a matching ".test" file
	set -ex; if [ ! -d $(TESTDIR) ]; then \
		echo "no $(TESTDIR) found, please build the tree first "; \
		exit 1; \
	fi
	set -ex; for f in $$(pwd)/hook-tests/[0-9]*.test; do \
			if !(cd $(TESTDIR) && $$f); then \
				exit 1; \
			fi; \
	    	done; \
	set -ex; for f in $$(pwd)/tests/test_*.sh; do \
		sh -e $$f; \
	done

# Display a report of files that are (still) present in /etc
.PHONY: etc-report
etc-report:
	cd stage && find etc/
	echo "Amount of cruft in /etc left: `find stage/etc/ | wc -l`"

