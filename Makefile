
.SILENT:

# General rule is that CAPITAL variables are constants and can be used
# via $(VARNAME), while lowercase variables are dynamic and need to be
# used via $(call varname,$@) (note no space between comma and $@)

REL     := $(if $(REL),$(REL),2.5.0)
SUBREL  := $(if $(SUBREL),$(SUBREL),testing)
ARDUINO := $(if $(ARDUINO),$(ARDUINO),$(shell pwd)/arduino)
GCC     := $(if $(GCC),$(GCC),4.8)

# General constants
PWD      := $(shell pwd)
REPODIR  := $(PWD)/repo
PATCHDIR := $(PWD)/patches

# For uploading, the GH user and password
GHUSER := $(if $(GHUSER),$(GHUSER),$(shell cat .ghuser))
GHPASS := $(if $(GHPASS),$(GHPASS),$(shell cat .ghpass))
ifeq ($(GHUSER),)
    $(error Need to specify GH username on the command line "GHUSER=xxxx" or in .ghuser)
else ifeq ($(GHPASS),)
    $(error Need to specify GH password on the command line "GHPASS=xxxx" or in .gphass)
endif

# Depending on the GCC version get proper branch and support libs
ifeq ($(GCC),4.8)
    ISL        := 0.12.2
    GCC_BRANCH := call0-4.8.2
else ifeq ($(GCC),4.9)
    ISL        := 0.12.2
    GCC_BRANCH := call0-4.9.2
else ifeq ($(GCC),5.2)
    ISL        := 0.12.2
    GCC_BRANCH := xtensa-ctng-esp-5.2.0
else ifeq ($(GCC),7.2)
    ISL        := 0.16.1
    GCC_BRANCH := xtensa-ctng-7.2.0
else
    $(error Need to specify a supported GCC version "GCC={4.8, 4.9, 5.2, 7.2}")
endif

# MKSPIFFS must stay at 0.2.0 until Arduino boards.txt.py fixes non-page-aligned sizes
MKSPIFFS_BRANCH := 0.2.0

# LTO doesn't work on 4.8, may not be useful later
LTO := $(if $(lto),$(lto),false)

# Define the build and output naming, don't use directly (see below)
LINUX_HOST   := x86_64-linux-gnu
LINUX_AHOST  := x86_64-pc-linux-gnu
LINUX_EXT    := .x86_64
LINUX_EXE    := 
LINUX_MKTGT  := linux
LINUX_BFLGS  := LDFLAGS=-static
LINUX_TARCMD := tar
LINUX_TAROPT := zcf
LINUX_TAREXT := tar.gz

LINUX32_HOST   := i686-linux-gnu
LINUX32_AHOST  := i686-pc-linux-gnu
LINUX32_EXT    := .i686
LINUX32_EXE    := 
LINUX32_MKTGT  := linux
LINUX32_BFLGS  := LDFLAGS=-static
LINUX32_TARCMD := tar
LINUX32_TAROPT := zcf
LINUX32_TAREXT := tar.gz

WIN32_HOST   := i686-w64-mingw32
WIN32_AHOST  := i686-mingw32
WIN32_EXT    := .win32
WIN32_EXE    := .exe
WIN32_MKTGT  := windows
WIN32_BFLGS  := LDFLAGS=-static
WIN32_TARCMD := zip
WIN32_TAROPT := -rq
WIN32_TAREXT := zip

WIN64_HOST   := x86_64-w64-mingw32
WIN64_AHOST  := x86_64-mingw32
WIN64_EXT    := .win64
WIN64_EXE    := .exe
WIN64_MKTGT  := windows
WIN64_BFLGS  := LDFLAGS=-static
WIN64_TARCMD := zip
WIN64_TAROPT := -rq
WIN64_TAREXT := zip

OSX_HOST   := x86_64-apple-darwin14
OSX_AHOST  := x86_64-apple-darwin
OSX_EXT    := .osx
OSX_EXE    := 
OSX_MKTGT  := osx
OSX_BFLGS  :=
OSX_TARCMD := tar
OSX_TAROPT := zcf
OSX_TAREXT := tar.gz

ARM64_HOST   := aarch64-linux-gnu
ARM64_AHOST  := aarch64-linux-gnu
ARM64_EXT    := .arm64
ARM64_EXE    := 
ARM64_MKTGT  := linux
ARM64_BFLGS  := LDFLAGS=-static
ARM64_TARCMD := tar
ARM64_TAROPT := zcf
ARM64_TAREXT := tar.gz

RPI_HOST   := arm-linux-gnueabihf
RPI_AHOST  := arm-linux-gnueabihf
RPI_EXT    := .rpi
RPI_EXE    := 
RPI_MKTGT  := linux
RPI_BFLGS  := LDFLAGS=-static
RPI_TARCMD := tar
RPI_TAROPT := zcf
RPI_TAREXT := tar.gz

# Call with $@ to get the appropriate variable for this architecture
host   = $($(call arch,$(1))_HOST)
ahost  = $($(call arch,$(1))_AHOST)
ext    = $($(call arch,$(1))_EXT)
exe    = $($(call arch,$(1))_EXE)
mktgt  = $($(call arch,$(1))_MKTGT)
bflgs  = $($(call arch,$(1))_BFLGS)
tarcmd = $($(call arch,$(1))_TARCMD)
taropt = $($(call arch,$(1))_TAROPT)
tarext = $($(call arch,$(1))_TAREXT)
log    = log$(1)

# The build directory per architecture
arena = $(PWD)/arena$(call ext,$(1))
# The architecture for this recipe
arch = $(subst .,,$(suffix $(basename $(1))))
# This installation directory for this architecture
install = $(PWD)/xtensa-lx106-elf$($(call arch,$(1))_EXT)

# GCC et. al configure options
configure  = --prefix=$(call install,$(1))
configure += --build=$(shell gcc -dumpmachine)
configure += --host=$(call host,$(1))
configure += --target=xtensa-lx106-elf
configure += --disable-shared
configure += --with-newlib
configure += --enable-threads=no
configure += --disable-__cxa_atexit
configure += --disable-libgomp
configure += --disable-libmudflap
configure += --disable-nls
configure += --disable-multilib
configure += --disable-bootstrap
configure += --enable-languages=c,c++
configure += --enable-lto
configure += --enable-static=yes
configure += --disable-libstdcxx-verbose

# Newlib configuration common
CONFIGURENEWLIBCOM  = --with-newlib
CONFIGURENEWLIBCOM += --enable-multilib
CONFIGURENEWLIBCOM += --disable-newlib-io-c99-formats
CONFIGURENEWLIBCOM += --disable-newlib-supplied-syscalls
CONFIGURENEWLIBCOM += --enable-newlib-nano-formatted-io
CONFIGURENEWLIBCOM += --enable-newlib-reent-small
CONFIGURENEWLIBCOM += --enable-target-optspace
CONFIGURENEWLIBCOM += --disable-option-checking
CONFIGURENEWLIBCOM += --target=xtensa-lx106-elf
CONFIGURENEWLIBCOM += --disable-shared

# Configuration for newlib normal build
configurenewlib  = --prefix=$(call install,$(1))
configurenewlib += $(CONFIGURENEWLIBCOM)

# Configuration for newlib install-to-arduino target
CONFIGURENEWLIBINSTALL  = --prefix=$(ARDUINO)/tools/sdk/libc
CONFIGURENEWLIBINSTALL += --with-target-subdir=xtensa-lx106-elf
CONFIGURENEWLIBINSTALL += $(CONFIGURENEWLIBCOM)

# Environment variables for configure and building targets.  Only use $(call setenv,$@)
ifeq ($(LTO),true)
    CFFT := "-mlongcalls -flto -Wl,-flto -Os -g"
else ifeq ($(LTO),false)
    CFFT := "-mlongcalls -Os -g"
else
    $(error Need to specify LTO={true,false} on the command line)
endif
# Sets the environment variables for a subshell while building
setenv = export CFLAGS_FOR_TARGET=$(CFFT); \
         export CXXFLAGS_FOR_TARGET=$(CFFT); \
         export CFLAGS="-I$(call install,$(1))/include -pipe"; \
         export LDFLAGS="-L$(call install,$(1))/lib"; \
         export PATH="$(call install,.stage.LINUX.stage)/bin:$${PATH}"; \
         export LD_LIBRARY_PATH="$(call install,.stage.LINUX.stage)/lib:$${LD_LIBRARY_PATH}"

# Generates a JSON fragment for an uploaded release artifact
makejson = tarballsize=$$(stat -c%s $${tarball}); \
	   tarballsha256=$$(sha256sum $${tarball} | cut -f1 -d" "); \
	   ( echo '{' && \
	     echo ' "host": "'$(call ahost,$(1))'",' && \
	     echo ' "url": "https://github.com/$(GHUSER)/esp-quick-toolchain/releases/download/'$(REL)-$(SUBREL)'/'$${tarball}'",' && \
	     echo ' "archiveFileName": "'$${tarball}'",' && \
	     echo ' "checksum": "SHA-256:'$${tarballsha256}'",' && \
	     echo ' "size": "'$${tarballsize}'"' && \
	     echo '}') > $${tarball}.json

# The recpies begin here.

linux default: .stage.LINUX.done

.PRECIOUS: .stage.% .stage.%.%

# Build all toolchain versions
all: .stage.LINUX.done .stage.LINUX32.done .stage.WIN32.done .stage.WIN64.done .stage.OSX.done .stage.ARM64.done .stage.RPI.done
	echo STAGE: $@
	echo All complete

# Other cross-compile cannot start until Linux is built
.stage.LINUX32.gcc1-make .stage.WIN32.gcc1-make .stage.WIN64.gcc1-make .stage.OSX.gcc1-make .stage.ARM64.gcc1-make .stage.RPI.gcc1-make: .stage.LINUX.done


# Clean all temporary outputs
clean: .cleaninst.LINUX.clean .cleaninst.LINUX32.clean .cleaninst.WIN32.clean .cleaninst.WIN64.clean .cleaninst.OSX.clean .cleaninst.ARM64.clean .cleaninst.RPI.clean
	echo STAGE: $@
	rm -rf .stage* *.json *.tar.gz *.zip venv $(ARDUINO) pkg.* log.* > /dev/null 2>&1

# Clean an individual architecture and arena dir
.cleaninst.%.clean:
	echo STAGE: $@
	rm -rf $(call install,$@) > /dev/null 2>&1
	rm -rf $(call arena,$@) > /dev/null 2>&1

# Download the needed GIT and tarballs
GNUHTTP := https://gcc.gnu.org/pub/gcc/infrastructure
.stage.download:
	echo STAGE: $@
	mkdir -p $(REPODIR) > $(call log,$@) 2>&1
	(test -d $(REPODIR)/binutils-gdb || git clone https://github.com/$(GHUSER)/binutils-gdb-xtensa.git $(REPODIR)/binutils-gdb) >> $(call log,$@) 2>&1
	(test -d $(REPODIR)/gcc          || git clone https://github.com/$(GHUSER)/gcc-xtensa.git          $(REPODIR)/gcc         ) >> $(call log,$@) 2>&1
	(test -d $(REPODIR)/newlib       || git clone https://github.com/$(GHUSER)/newlib-xtensa.git       $(REPODIR)/newlib      ) >> $(call log,$@) 2>&1
	(test -d $(REPODIR)/lx106-hal    || git clone https://github.com/$(GHUSER)/lx106-hal.git           $(REPODIR)/lx106-hal   ) >> $(call log,$@) 2>&1
	(test -d $(REPODIR)/mkspiffs     || git clone https://github.com/$(GHUSER)/mkspiffs.git            $(REPODIR)/mkspiffs    ) >> $(call log,$@) 2>&1
	(test -d $(REPODIR)/esptool      || git clone https://github.com/$(GHUSER)/esptool-ck.git          $(REPODIR)/esptool     ) >> $(call log,$@) 2>&1
	touch $@

# Completely clean out a git directory, removing any untracked files
.clean.%.git:
	echo STAGE: $@
	cd $(REPODIR)/$(call arch,$@) && git reset --hard HEAD && git clean -f -d

.clean.gits: .clean.binutils-gdb.git .clean.gcc.git .clean.newlib.git .clean.newlib.git .clean.lx106-hal.git .clean.mkspiffs.git .clean.esptool.git

# Prep the git repos with no patches and any required libraries for gcc
.stage.prepgit: .stage.download
	echo STAGE: $@
	for i in binutils-gdb gcc newlib lx106-hal mkspiffs esptool; do cd $(REPODIR)/$$i && git reset --hard HEAD && git clean -f -d; done   > $(call log,$@) 2>&1
	for url in $(GNUHTTP)/gmp-6.1.0.tar.bz2 $(GNUHTTP)/mpfr-3.1.4.tar.bz2 $(GNUHTTP)/mpc-1.0.3.tar.gz \
	           $(GNUHTTP)/isl-$(ISL).tar.bz2 $(GNUHTTP)/cloog-0.18.1.tar.gz http://www.mr511.de/software/libelf-0.8.13.tar.gz ; do \
	    archive=$${url##*/}; name=$${archive%.t*}; base=$${name%-*}; ext=$${archive##*.} ; \
	    echo "-------- getting $${name}" ; \
	    cd $(REPODIR) && ( test -r $${archive} || wget $${url} ) ; \
	    case "$${ext}" in \
	        gz)  (cd $(REPODIR)/gcc; tar xfz ../$${archive});; \
	        bz2) (cd $(REPODIR)/gcc; tar xfj ../$${archive});; \
	    esac ; \
	    (cd $(REPODIR)/gcc; rm -f $${base}; ln -s $${name} $${base}) \
	done >> $(call log,$@) 2>&1
	touch $@

# Checkout any required branches
.stage.checkout: .stage.prepgit
	echo STAGE: $@
	(cd $(REPODIR)/gcc && git reset --hard && git checkout $(GCC_BRANCH)) > $(call log,$@) 2>&1
	(cd $(REPODIR)/mkspiffs && git reset --hard && git checkout $(MKSPIFFS_BRANCH) && git submodule update) >> $(call log,$@) 2>&1
	touch $@

# Apply our patches
.stage.patch: .stage.checkout
	echo STAGE: $@
	for p in $(PATCHDIR)/gcc-*.patch $(PATCHDIR)/gcc$(GCC)/gcc-*.patch; do \
	    test -r "$$p" || continue ; \
	    (cd $(REPODIR)/gcc; echo "---- $$p:"; patch -s -p1 < $$p) ; \
	done > $(call log,$@) 2>&1
	for p in $(PATCHDIR)/bin-*.patch; do \
	    test -r "$$p" || continue ; \
	    (cd $(REPODIR)/binutils-gdb; echo "---- $$p:"; patch -s -p1 < $$p) ; \
	done >> $(call log,$@) 2>&1
	for p in $(PATCHDIR)/lib-*.patch; do \
	    test -r "$$p" || continue ; \
	    (cd $(REPODIR)/newlib; echo "---- $$p: "; patch -s -p1 < $$p) ; \
	done >> $(call log,$@) 2>&1
	for p in $(PATCHDIR)/mkspiffs/$(MKSPIFFS_BRANCH)*.patch; do \
	    test -r "$$p" || continue ; \
	    (cd $(REPODIR)/mkspiffs; echo "---- $$p: "; patch -s -p1 < $$p) ; \
	done >> $(call log,$@) 2>&1
	# Dirty-force HAL definition to binutils and gcc
	for ow in $(REPODIR)/gcc/include/xtensa-config.h $(REPODIR)/binutils-gdb/include/xtensa-config.h; do \
	    ( cat $(REPODIR)/lx106-hal/include/xtensa/config/core-isa.h; \
	      cat $(REPODIR)/lx106-hal/include/xtensa/config/system.h ; \
	      echo '#define XCHAL_HAVE_FP_DIV   0' ; \
              echo '#define XCHAL_HAVE_FP_RECIP 0' ; \
              echo '#define XCHAL_HAVE_FP_SQRT  0' ; \
              echo '#define XCHAL_HAVE_FP_RSQRT 0' ) > $${ow} ; \
        done >> $(call log,$@) 2>&1
	cd $(REPODIR)/lx106-hal && autoreconf -i >> $(call log,$@) 2>&1
	touch $@

.stage.%.start: .stage.patch
	echo STAGE: $@
	mkdir -p $(call arena,$@) > $(call log,$@) 2>&1

# Build binutils
.stage.%.binutils-config: .stage.%.start
	echo STAGE: $@
	rm -rf $(call arena,$@)/binutils-gdb > $(call log,$@) 2>&1
	mkdir -p $(call arena,$@)/binutils-gdb >> $(call log,$@) 2>&1
	(cd $(call arena,$@)/binutils-gdb; $(call setenv,$@); $(REPODIR)/binutils-gdb/configure $(call configure,$@)) >> $(call log,$@) 2>&1
	touch $@

.stage.%.binutils-make: .stage.%.binutils-config
	echo STAGE: $@
	# Need LDFLAGS override to guarantee gdb is made static
	(cd $(call arena,$@)/binutils-gdb; $(call setenv,$@); $(MAKE) $(call bflgs,$@)) > $(call log,$@) 2>&1
	(cd $(call arena,$@)/binutils-gdb; $(call setenv,$@); $(MAKE) install) >> $(call log,$@) 2>&1
	(cd $(call install,$@)/bin; ln -sf xtensa-lx106-elf-gcc$(call exe,$@) xtensa-lx106-elf-cc$(call exe,$@)) >> $(call log,$@) 2>&1
	touch $@

.stage.%.gcc1-config: .stage.%.binutils-make
	echo STAGE: $@
	rm -rf $(call arena,$@)/gcc > $(call log,$@) 2>&1
	mkdir -p $(call arena,$@)/gcc >> $(call log,$@) 2>&1
	(cd $(call arena,$@)/gcc; $(call setenv,$@); $(REPODIR)/gcc/configure $(call configure,$@)) >> $(call log,$@) 2>&1
	touch $@

.stage.%.gcc1-make: .stage.%.gcc1-config
	echo STAGE: $@
	(cd $(call arena,$@)/gcc; $(call setenv,$@); $(MAKE) all-gcc; $(MAKE) install-gcc) > $(call log,$@) 2>&1
	touch $@

.stage.%.newlib-config: .stage.%.gcc1-make
	echo STAGE: $@
	rm -rf $(call arena,$@)/newlib > $(call log,$@) 2>&1
	mkdir -p $(call arena,$@)/newlib >> $(call log,$@) 2>&1
	(cd $(call arena,$@)/newlib; $(call setenv,$@); $(REPODIR)/newlib/configure $(call configurenewlib,$@)) >> $(call log,$@) 2>&1
	touch $@

.stage.%.newlib-make: .stage.%.newlib-config
	echo STAGE: $@
	(cd $(call arena,$@)/newlib; $(call setenv,$@); $(MAKE)) > $(call log,$@) 2>&1
	(cd $(call arena,$@)/newlib; $(call setenv,$@); $(MAKE) install) >> $(call log,$@) 2>&1
	touch $@

.stage.%.libstdcpp: .stage.%.newlib-make
	echo STAGE: $@
	# stage 2 (build libstdc++)
	(cd $(call arena,$@)/gcc; $(call setenv,$@); $(MAKE)) > $(call log,$@) 2>&1
	(cd $(call arena,$@)/gcc; $(call setenv,$@); $(MAKE) install) >> $(call log,$@) 2>&1
	touch $@

.stage.%.libsdtcpp-nox: .stage.%.libstdcpp
	echo STAGE: $@
	# We copy existing stdc, adjust the makefile, and build a single .a to save much time
	rm -rf $(call arena,$@)/gcc/xtensa-lx106-elf/libstdc++-v3-nox > $(call log,$@) 2>&1
	cp -a $(call arena,$@)/gcc/xtensa-lx106-elf/libstdc++-v3 $(call arena,$@)/gcc/xtensa-lx106-elf/libstdc++-v3-nox >> $(call log,$@) 2>&1
	(cd $(call arena,$@)/gcc/xtensa-lx106-elf/libstdc++-v3-nox; $(call setenv,$@); $(MAKE) clean; find . -name Makefile -exec sed -i 's/mlongcalls/mlongcalls -fno-exceptions/' \{\} \; ; $(MAKE)) >> $(call log,$@) 2>&1
	cp xtensa-lx106-elf$(call ext,$@)/xtensa-lx106-elf/lib/libstdc++.a xtensa-lx106-elf$(call ext,$@)/xtensa-lx106-elf/lib/libstdc++-exc.a >> $(call log,$@) 2>&1
	cp $(call arena,$@)/gcc/xtensa-lx106-elf/libstdc++-v3-nox/src/.libs/libstdc++.a xtensa-lx106-elf$(call ext,$@)/xtensa-lx106-elf/lib/libstdc++.a >> $(call log,$@) 2>&1
	touch $@

.stage.%.hal-config: .stage.%.libsdtcpp-nox
	echo STAGE: $@
	rm -rf $(call arena,$@)/hal > $(call log,$@) 2>&1
	mkdir -p $(call arena,$@)/hal >> $(call log,$@) 2>&1
	(cd $(call arena,$@)/hal; $(call setenv,$@); $(REPODIR)/lx106-hal/configure --host=xtensa-lx106-elf $$(echo $(call configure,$@) | sed 's/--host=[a-zA-Z0-9_-]*//')) >> $(call log,$@) 2>&1
	touch $@

.stage.%.hal-make: .stage.%.hal-config
	echo STAGE: $@
	(cd $(call arena,$@)/hal; $(call setenv,$@); $(MAKE)) > $(call log,$@) 2>&1
	(cd $(call arena,$@)/hal; $(call setenv,$@); $(MAKE) install) >> $(call log,$@) 2>&1
	touch $@

.stage.%.strip: .stage.%.hal-make
	echo STAGE: $@
	($(call setenv,$@); $(call host,$@)-strip $(call install,$@)/bin/*$(call exe,$@) $(call install,$@)/libexec/gcc/xtensa-lx106-elf/*/c*$(call exe,$@) $(call install,$@)/libexec/gcc/xtensa-lx106-elf/*/lto1$(call exe,$@) || true ) > $(call log,$@) 2>&1
	touch $@

.stage.%.post: .stage.%.strip
	echo STAGE: $@
	for sh in post/$(GCC)*.sh; do \
	    [ -x "$${sh}" ] && $${sh} $(call ext,$@) ; \
	done > $(call log,$@) 2>&1
	touch $@

.stage.%.package: .stage.%.post
	echo STAGE: $@
	rm -rf pkg.$(call arch,$@) > $(call log,$@) 2>&1
	mkdir -p pkg.$(call arch,$@) >> $(call log,$@) 2>&1
	cp -a $(call install,$@) pkg.$(call arch,$@)/xtensa-lx106-elf >> $(call log,$@) 2>&1
	(tarball=$(call host,$@).xtensa-lx106-elf-$$(git rev-parse --short HEAD).$(call tarext,$@) ; \
	    cd pkg.$(call arch,$@) && $(call tarcmd,$@) $(call taropt,$@) ../$${tarball} xtensa-lx106-elf/ ; cd ..; $(call makejson,$@)) >> $(call log,$@) 2>&1
	rm -rf pkg.$(call arch,$@) >> $(call log,$@) 2>&1
	touch $@

.stage.%.mkspiffs: .stage.%.start
	echo STAGE: $@
	rm -rf $(call arena,$@)/mkspiffs > $(call log,$@) 2>&1
	cp -a $(REPODIR)/mkspiffs $(call arena,$@)/mkspiffs >> $(call log,$@) 2>&1
	# Dependencies borked in mkspiffs makefile, so don't use parallel make
	(cd $(call arena,$@)/mkspiffs;\
	    $(call setenv,$@); \
	    TARGET_OS=$(call mktgt,$@) CC=$(call host,$@)-gcc CXX=$(call host,$@)-g++ STRIP=$(call host,$@)-strip \
            make -j1 clean mkspiffs$(call exe,$@) BUILD_CONFIG_NAME="-arduino-esp8266" CPPFLAGS="-DSPIFFS_USE_MAGIC_LENGTH=0 -DSPIFFS_ALIGNED_OBJECT_INDEX_TABLES=1") >> $(call log,$@) 2>&1
	rm -rf pkg.mkspiffs.$(call arch,$@) >> $(call log,$@) 2>&1
	mkdir -p pkg.mkspiffs.$(call arch,$@)/mkspiffs >> $(call log,$@) 2>&1
	cp $(call arena,$@)/mkspiffs/mkspiffs$(call exe,$@) pkg.mkspiffs.$(call arch,$@)/mkspiffs/. >> $(call log,$@) 2>&1
	(tarball=$(call host,$@).mkspiffs-$$(cd $(REPODIR)/mkspiffs && git rev-parse --short HEAD).$(call tarext,$@) ; \
	    cd pkg.mkspiffs.$(call arch,$@) && $(call tarcmd,$@) $(call taropt,$@) ../$${tarball} mkspiffs; cd ..; $(call makejson,$@)) >> $(call log,$@) 2>&1
	rm -rf pkg.mkspiffs.$(call arch,$@) >> $(call log,$@) 2>&1
	touch $@

.stage.%.esptool: .stage.%.start
	echo STAGE: $@
	rm -rf $(call arena,$@)/esptool > $(call log,$@) 2>&1
	cp -a $(REPODIR)/esptool $(call arena,$@)/esptool >> $(call log,$@) 2>&1
	# Dependencies borked in esptool makefile, so don't use parallel make
	(cd $(call arena,$@)/esptool;\
	    $(call setenv,$@); \
	    TARGET_OS=$(call mktgt,$@) CC=$(call host,$@)-gcc CXX=$(call host,$@)-g++ STRIP=$(call host,$@)-strip \
            make -j1 clean esptool$(call exe,$@) BUILD_CONFIG_NAME="-arduino-esp8266") >> $(call log,$@) 2>&1
	rm -rf pkg.esptool.$(call arch,$@) >> $(call log,$@) 2>&1
	mkdir -p pkg.esptool.$(call arch,$@)/esptool >> $(call log,$@) 2>&1
	cp $(call arena,$@)/esptool/esptool$(call exe,$@) pkg.esptool.$(call arch,$@)/esptool/. >> $(call log,$@) 2>&1
	(tarball=$(call host,$@).esptool-$$(cd $(REPODIR)/esptool && git rev-parse --short HEAD).$(call tarext,$@) ; \
	    cd pkg.esptool.$(call arch,$@) && $(call tarcmd,$@) $(call taropt,$@) ../$${tarball} esptool; cd ..; $(call makejson,$@)) >> $(call log,$@) 2>&1
	rm -rf pkg.esptool.$(call arch,$@) >> $(call log,$@) 2>&1
	touch $@

.stage.%.done: .stage.%.package .stage.%.mkspiffs .stage.%.esptool
	echo STAGE: $@
	echo Done building $(call arch,$@)

# Only the native version has to be done to install libs to GIT
install: .stage.LINUX.install
.stage.LINUX.install:
	echo STAGE: $@
	rm -rf $(ARDUINO)
	git clone https://github.com/$(GHUSER)/Arduino $(ARDUINO)
	echo "-------- Building installable newlib"
	rm -rf arena/newlib-install; mkdir -p arena/newlib-install
	cd arena/newlib-install; $(call setenv,$@); $(REPODIR)/newlib/configure $(CONFIGURENEWLIBINSTALL); $(MAKE); $(MAKE) install
	echo "-------- Building installable hal"
	rm -rf arena/hal-install; mkdir -p arena/hal-install
	cd arena/hal-install; $(call setenv,$@); $(REPODIR)/lx106-hal/configure --prefix=$(ARDUINO)/tools/sdk/libc --libdir=$(ARDUINO)/tools/sdk/lib --host=xtensa-lx106-elf $$(echo $(call configure,$@) | sed 's/--host=[a-zA-Z0-9_-]*//' | sed 's/--prefix=[a-zA-Z0-9_-\\]*//')
	cd arena/hal-install; $(call setenv,$@); $(MAKE) ; $(MAKE) install
	echo "-------- Copying GCC libs"
	cp $(call install,$@)/lib/gcc/xtensa-lx106-elf/*/libgcc.a  $(ARDUINO)/tools/sdk/lib/.
	cp $(call install,$@)/xtensa-lx106-elf/lib/libstdc++.a     $(ARDUINO)/tools/sdk/lib/.
	cp $(call install,$@)/xtensa-lx106-elf/lib/libstdc++-nox.a $(ARDUINO)/tools/sdk/lib/.
	echo "-------- Copying toolchain directory"
	rm -rf $(ARDUINO)/tools/sdk/xtensa-lx106-elf
	cp -a $(call install,$@)/xtensa-lx106-elf $(ARDUINO)/tools/sdk/xtensa-lx106-elf
	echo "-------- Updating package.json"
	ver=$(REL)-$(SUBREL)-$(shell git rev-parse --short HEAD); pkgfile=$(ARDUINO)/package/package_esp8266com_index.template.json; \
	./patch_json.py --pkgfile "$${pkgfile}" --tool xtensa-lx106-elf-gcc --ver "$${ver}" --glob '*xtensa-lx106-elf*.json' ; \
	./patch_json.py --pkgfile "$${pkgfile}" --tool esptool --ver "$${ver}" --glob '*esptool*json' ; \
	./patch_json.py --pkgfile "$${pkgfile}" --tool mkspiffs --ver "$${ver}" --glob '*mkspiffs*json'
	echo "Install done"

# Upload a draft toolchain release
upload: .stage.LINUX.upload
.stage.LINUX.upload:
	echo STAGE: $@
	rm -rf ./venv; mkdir ./venv
	virtualenv --no-site-packages venv
	cd ./venv; . bin/activate; \
	    pip install -q pygithub ; \
	    python ../upload_release.py --user "$(GHUSER)" --pw "$(GHPASS)" --tag $(REL)-$(SUBREL) --msg 'See https://github.com/esp8266/Arduino for more info'  --name "ESP8266 Quick Toolchain for $(REL)-$(SUBREL)" ../*.tar.gz ../*.zip ;
	rm -rf ./venv

dumpvars:
	echo SETENV:    '$(call setenv,.stage.LINUX.stage)'
	echo CONFIGURE: '$(call configure,.stage.LINUX.stage)'
	echo NEWLIBCFG: '$(call configurenewlib,.stage.LINUX.stage)'
