ifdef B_BASE
include $(B_BASE)/common.mk
include $(B_BASE)/rpmbuild.mk
REPO=$(call git_loc,xen-api)
else
MY_OUTPUT_DIR ?= $(CURDIR)/output
MY_OBJ_DIR ?= $(CURDIR)/obj
REPO ?= $(CURDIR)

RPM_SPECSDIR?=$(shell rpm --eval='%_specdir')
RPM_SRPMSDIR?=$(shell rpm --eval='%_srcrpmdir')
RPM_SOURCESDIR?=$(shell rpm --eval='%_sourcedir')
RPMBUILD?=rpmbuild
XEN_RELEASE?=unknown
endif

BASE_PATH=$(shell scripts/base-path scripts/xapi.conf)

JQUERY=$(CARBON_DISTFILES)/javascript/jquery/jquery-1.1.3.1.pack.js
JQUERY_TREEVIEW=$(CARBON_DISTFILES)/javascript/jquery/treeview/jquery.treeview.zip

COMPILE_NATIVE ?= yes
COMPILE_BYTE ?= no
export COMPILE_NATIVE COMPILE_BYTE

include config.mk

OCAMLPATH=
EXTRA_INSTALL_PATH=

export ETCDIR OPTDIR PLUGINDIR HOOKSDIR INVENTORY VARPATCHDIR LIBEXECDIR XAPICONF SCRIPTSDIR SHAREDIR WEBDIR XHADIR BINDIR SBINDIR UDEVDIR OCAMLPATH EXTRA_INSTALL_PATH
export DISABLE_WARN_ERROR

.PHONY: all
all: version
	omake -j 8 phase1
	omake -j 8 phase2
	omake -j 8 phase3
ifeq ($(DISABLE_TESTS),false)
	@make test
endif

.PHONY: phase1 phase2 phase3
phase1:
	omake phase1
phase2:
	omake phase2
phase3:
	omake phase3

.PHONY: test
test:
	omake test
	@echo @
	@echo @ Running unit tests
	@echo @
#	Pipe ugly bash output to /dev/null
	@echo @ xapi unit test suite
	@./ocaml/test/suite -verbose true -shards 1
	@echo
	@echo @ HA binpack test
	@./ocaml/xapi/binpack
#	The following test no longer runs:
#	./ocaml/database/database_test
#	The following test no longer compiles:
#	./ocaml/xenops/device_number_test
#	The following test must be run in dom0:
#	./ocaml/xenops/cancel_utils_test

.PHONY: install
install:
	omake install
	omake lib-uninstall
	omake lib-install

.PHONY: lib-install
lib-install:
	omake DESTDIR=$(DESTDIR) lib-install

.PHONY: lib-uninstall
lib-uninstall:
	omake DESTDIR=$(DESTDIR) lib-uninstall

.PHONY: sdk-install
sdk-install: doc
	omake sdk-install

.PHONY: noarch-install
noarch-install: doc
	omake noarch-install

.PHONY: clean
clean:
	omake clean
	omake lib-uninstall
	rm -rf dist/staging
	rm -f .omakedb .omakedb.lock xapi.spec version.ml
	find -name '*.omc' -delete

.PHONY: otags
otags:
	otags -vi -r . -o tags

.PHONY: doc
doc: api-doc api-libs-doc

.PHONY: api-doc
api-doc: version
	omake phase1 phase2 # autogenerated files might be required
	omake doc

.PHONY: api-libs-doc
api-libs-doc:
	@(cd ../xen-api-libs 2> /dev/null && $(MAKE) doc) || \
	 (echo ">>> If you have a myclone of xen-api-libs, its documentation will be included. <<<")

PLATFORM_VERSION ?= 0.0.0

.PHONY: version
version:
	@printf "(* This file is autogenerated.  Grep for e17512ce-ba7c-11df-887b-0026b9799147 (random uuid) to see where it comes from. ;o) *) \n \
	let git_id = \"$(shell git show-ref --head | grep -E ' HEAD$$' | cut -f 1 -d ' ')\" \n \
	let hostname = \"$(shell hostname)\" \n \
	let date = \"$(shell date -u +%Y-%m-%d)\" \n \
	let product_version () = Inventory.lookup ~default:\"\" \"PRODUCT_VERSION\" \n \
	let product_version_text () = Inventory.lookup ~default:\"\" \"PRODUCT_VERSION_TEXT\" \n \
	let product_version_text_short () = Inventory.lookup ~default:\"\" \"PRODUCT_VERSION_TEXT_SHORT\" \n \
	let platform_name = \"$(PLATFORM_NAME)\" \n \
	let platform_version = \"$(PLATFORM_VERSION)\" \n \
	let product_brand () = Inventory.lookup ~default:\"\" \"PRODUCT_BRAND\" \n \
	let build_number () = Inventory.lookup ~default:\"$(BUILD_NUMBER)\" \"BUILD_NUMBER\" \n \
	let xapi_version_major = $(shell cut -d. -f1 VERSION) \n \
	let xapi_version_minor = $(shell cut -d. -f2 VERSION) \n" \
	> ocaml/util/version.ml

.PHONY: clean
 clean:

xapi.spec: xapi.spec.in
	sed -e 's/@RPM_RELEASE@/$(shell git rev-list HEAD | wc -l)/g' < $< > $@
	sed -i "s!@OPTDIR@!${OPTDIR}!g" $@

.PHONY: srpm
srpm: xapi.spec
	mkdir -p $(RPM_SOURCESDIR) $(RPM_SPECSDIR) $(RPM_SRPMSDIR)
	while ! [ -d .git ]; do cd ..; done; \
	git archive --prefix=xapi-0.2/ --format=tar HEAD | bzip2 -z > $(RPM_SOURCESDIR)/xapi-0.2.tar.bz2 # xen-api/Makefile
	cp $(JQUERY) $(JQUERY_TREEVIEW) $(RPM_SOURCESDIR)
	make -C $(REPO) version
	rm -f $(RPM_SOURCESDIR)/xapi-version.patch
	(cd $(REPO); diff -u /dev/null ocaml/util/version.ml > $(RPM_SOURCESDIR)/xapi-version.patch) || true
	cp -f xapi.spec $(RPM_SPECSDIR)/
	chown root.root $(RPM_SPECSDIR)/xapi.spec || true
	$(RPMBUILD) -bs --nodeps $(RPM_SPECSDIR)/xapi.spec


.PHONY: build
build: all

