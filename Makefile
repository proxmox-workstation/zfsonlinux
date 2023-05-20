include /usr/share/dpkg/default.mk
# source form https://github.com/zfsonlinux/

ZFSDIR=zfs-linux_$(DEB_VERSION_UPSTREAM)
ZFSSRC=upstream
ORIG_SRC_TAR=$(ZFSDIR).orig.tar.gz

ZFS_DEB1= libnvpair3linux_$(DEB_VERSION)_amd64.deb

ZFS_DEB_BINARY =				\
libpam-zfs_$(DEB_VERSION)_amd64.deb		\
libuutil3linux_$(DEB_VERSION)_amd64.deb		\
libzfs4linux_$(DEB_VERSION)_amd64.deb		\
libzfsbootenv1linux_$(DEB_VERSION)_amd64.deb	\
libzpool5linux_$(DEB_VERSION)_amd64.deb		\
zfs-test_$(DEB_VERSION)_amd64.deb			\
zfsutils-linux_$(DEB_VERSION)_amd64.deb		\
zfs-zed_$(DEB_VERSION)_amd64.deb

ZFS_DBG_DEBS = $(patsubst %_$(DEB_VERSION)_amd64.deb, %-dbgsym_$(DEB_VERSION)_amd64.deb, $(ZFS_DEB1) $(ZFS_DEB_BINARY))

ZFS_DEB2= $(ZFS_DEB_BINARY)			\
libzfslinux-dev_$(DEB_VERSION)_amd64.deb		\
python3-pyzfs_$(DEB_VERSION)_amd64.deb		\
pyzfs-doc_$(DEB_VERSION)_all.deb			\
spl_$(DEB_VERSION)_all.deb			\
zfs-initramfs_$(DEB_VERSION)_all.deb
DEBS= $(ZFS_DEB1) $(ZFS_DEB2) $(ZFS_DBG_DEBS)

ZFS_DSC = zfs-linux_$(DEB_VERSION).dsc

all: deb
.PHONY: deb
deb: $(DEBS)
.PHONY: dsc
dsc: $(ZFS_DSC)

# called from pve-kernel's Makefile to get patched sources
.PHONY: kernel
kernel: $(ZFS_DSC)
	dpkg-source -x $(ZFS_DSC) ../pkg-zfs
	$(MAKE) -C ../pkg-zfs -f debian/rules adapt_meta_file

.PHONY: dinstall
dinstall: $(DEBS)
	dpkg -i $(DEBS)

.PHONY: submodule
submodule:
	test -f "$(ZFSSRC)/README.md" || git submodule update --init
$(ZFSSRC)/README.md: submodule

.PHONY: zfs
zfs: $(DEBS)
$(ZFS_DEB2) $(ZFS_DBG_DEBS): $(ZFS_DEB1)
$(ZFS_DEB1): $(ZFSDIR)
	cd $(ZFSDIR); dpkg-buildpackage -b -uc -us
	lintian $(DEBS)

$(ORIG_SRC_TAR): $(ZFSDIR)
	tar czf $(ORIG_SRC_TAR) --exclude="$(ZFSDIR)/debian" $(ZFSDIR)

$(ZFS_DSC): $(ZFSDIR) $(ORIG_SRC_TAR)
	tar czf zfs-linux_$(ZFSVER).orig.tar.gz $(ZFSDIR)
	cd $(ZFSDIR); dpkg-buildpackage -S -uc -us -d
	lintian $@

$(ZFSDIR): $(ZFSSRC)/README.md $(ZFSSRC) debian
	rm -rf $(ZFSDIR) $(ZFSDIR).tmp
	cp -a $(ZFSSRC) $(ZFSDIR).tmp
	cp -a debian $(ZFSDIR).tmp/debian
	mv $(ZFSDIR).tmp $(ZFSDIR)


.PHONY: clean
clean: 	
	rm -rf *~ *.deb *.changes *.buildinfo *.build *.dsc *.orig.tar.* *.debian.tar.* $(ZFSDIR)

.PHONY: distclean
distclean: clean

.PHONY: upload
upload: UPLOAD_DIST ?= $(DEB_DISTRIBUTION)
upload: $(DEBS)
	tar -cf - $(DEBS) | ssh repoman@repo.proxmox.com -- upload --product pve,pmg,pbs --dist $(UPLOAD_DIST) --arch $(DEB_HOST_ARCH)
