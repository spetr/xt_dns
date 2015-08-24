#
#	xt_dns Makefile
#       Copyright (c) Stanislav Petr, 2015
#       based on libxt_dns (c) Ondrej Caletka, 2013
#	based on xt_dns Makefile (c) Bartlomiej Korupczynski, 2011
#
#	This is kernel module used to match DNS MX queries
# 
#	This file is distributed under the terms of the GNU General Public
#	License (GPL). Copies of the GPL can be obtained from gnu.org/gpl.
#

NAME = xt_dns
VERSION = 2.0.1
DISTFILES = *.[ch] Makefile ChangeLog

DKMS_ROOT_PATH=/usr/src/$(NAME)-$(VERSION)

ifndef KERNELRELEASE
KERNELRELEASE = $(shell uname -r)
endif
ifndef KDIR
KDIR = /lib/modules/$(KERNELRELEASE)/build
MDIR = /lib/modules/$(KERNELRELEASE)/local/
endif
XDIR = /lib/xtables/ /lib64/xtables/

obj-m = $(NAME).o

build: config.h module userspace
install: module-install userspace-install
module: $(NAME).ko
userspace: lib$(NAME).so


config.h: Makefile
	@echo "making config.h"
	@echo "/* generated by Makefile */" >config.h
	@echo "#define VERSION \"$(VERSION)\"" >>config.h
	@if grep -q 'xt_match_param' $(KDIR)/include/linux/netfilter/x_tables.h; then \
		echo "#define HAVE_XT_MATCH_PARAM" >>config.h ;\
	fi

xt_dns.ko: xt_dns.c xt_dns.h config.h
	$(MAKE) -C $(KDIR) M=$(PWD) modules
	strip -g xt_dns.ko

# in case of problems add path to iptables sources like:
# -I/usr/src/sources/iptables-1.4.2/include/
libxt_dns.so: libxt_dns.c xt_dns.h config.h
	$(CC) -fPIC -Wall -shared -o libxt_dns.so libxt_dns.c

module-install: xt_dns.ko
	mkdir -p $(MDIR) || :
	install *.ko $(MDIR)
	depmod -a

userspace-install: libxt_dns.so
	for xdir in $(XDIR); do \
		if [ -d $${xdir} ]; then \
			install -m 644 *.so $${xdir}; \
			break; \
		fi; \
	done

clean:
	rm -f libxt_dns.so config.h
	$(MAKE) -C $(KDIR) M=$(PWD) clean

dist:
	rm -f $(NAME)-$(VERSION).tar.gz
	mkdir -p tmp/$(NAME)-$(VERSION)
	cp -a $(DISTFILES) tmp/$(NAME)-$(VERSION)
	cd tmp && tar zcf ../$(NAME)-$(VERSION).tar.gz $(NAME)-$(VERSION)/
	rm -rf tmp/$(NAME)-$(VERSION)
	rmdir --ignore-fail-on-non-empty tmp
	@echo OK: dist

distcheck: dist
	mkdir -p tmp
	rm -rf tmp/$(NAME)-$(VERSION)
	cd tmp && tar zxf ../$(NAME)-$(VERSION).tar.gz
	cd tmp/$(NAME)-$(VERSION) && $(MAKE) build
	rm -rf tmp/$(NAME)-$(VERSION)
	rmdir --ignore-fail-on-non-empty tmp
	@echo OK: distcheck

dkms:
	@mkdir $(DKMS_ROOT_PATH)
	@cp `pwd`/dkms.conf $(DKMS_ROOT_PATH)
	@cp `pwd`/Makefile $(DKMS_ROOT_PATH)
	@cp `pwd`/libxt_dns.c $(DKMS_ROOT_PATH)
	@cp `pwd`/xt_dns.c $(DKMS_ROOT_PATH)
	@cp `pwd`/xt_dns.h $(DKMS_ROOT_PATH)
	@dkms add -m $(NAME) -v $(VERSION)
	@dkms build -m $(NAME) -v $(VERSION)
	@dkms install --force -m $(NAME) -v $(VERSION)

