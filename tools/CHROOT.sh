#

# If variable not set, will only create the chroots."
# export BUILD_PKG=true

export DPIDIR=/usr/src/frasc/DPI
export CHROOTBASE=$DPIDIR/CHROOT
export PKGBASE=$DPIDIR/PKGS

export LIBRTADIR=$DPIDIR/LIBRTA
export RTAVER="1.1.3.1"
export RTADEB="-1"

os=debian
# os=raspbian
# os=ubuntu

case $os in
debian)
# DISTS="squeeze wheezy jessie sid"
DISTS="squeeze wheezy jessie"
;;
raspbian)
DISTS="wheezy jessie"
;;
ubuntu)
DISTS="precise trusty utopic vivid"
;;
*) echo "os: $os unknown."; exit 1 ;;
esac

for dist in $DISTS; do

case $dist in

sid)
# ARCH="amd64 armel armhf hurd-i386 i386 kfreebsd-amd64 kfreebsd-i386 mips mipsel powerpc s390x sparc"
ARCH="armel armhf"
;;

jessie)
if [ $os = debian ]; then
# ARCH="amd64 armel armhf i386 kfreebsd-amd64 kfreebsd-i386 mips mipsel powerpc s390x"
ARCH="armel armhf"
else
ARCH="armhf"
fi
;;

wheezy)
if [ $os = debian ]; then
# ARCH="amd64 armel armhf i386 ia64 kfreebsd-amd64 kfreebsd-i386 mips mipsel powerpc s390 s390x sparc"
ARCH="armel armhf mips mipsel"
else
ARCH="armhf"
fi
;;

squeeze)
# ARCH="amd64 armel i386 ia64 kfreebsd-amd64 kfreebsd-i386 mips mipsel powerpc s390 sparc"
ARCH="armel mips mipsel"
;;

precise|trusty|utopic|vivid)
# ARCH="arm64 armhf powerpc ppc64el"
ARCH="armhf"
;;
*) echo "dist: $dist unknown."; exit 1 ;;
esac

for arch in $ARCH; do

export CHROOTDIR=$CHROOTBASE/$os/$dist/$arch

export LANG=C

if [ -d $CHROOTDIR ]; then
  # mount the system filesystems.
  sudo mount -o bind /dev $CHROOTDIR/dev
  sudo mount -t devpts none $CHROOTDIR/dev/pts
  sudo mount -t proc none $CHROOTDIR/proc
  sudo mount -t sysfs none $CHROOTDIR/sys

  sudo chroot $CHROOTDIR apt-get update
  sudo chroot $CHROOTDIR apt-get -f -y --force-yes dist-upgrade
  sudo chroot $CHROOTDIR apt-get clean
else
  mkdir -p $CHROOTDIR

  if [ $dist = local_mirror ]; then
    export MIRROR=http://192.168.1.100/debian/debian
    export SECURITY=http://192.168.1.100/debian/security
  elif [ $os = ubuntu ]; then
    export MIRROR=http://ports.ubuntu.com/ubuntu-ports
  elif [ $os = raspbian ]; then
    export MIRROR=http://archive.raspbian.org/raspbian
  else
    export MIRROR=ftp://ftp.us.debian.org/debian
    export SECURITY=http://security.debian.org
  fi

  sudo debootstrap --no-check-gpg --foreign --arch $arch $dist $CHROOTDIR $MIRROR

  case $arch in
  amd64) sudo cp /usr/bin/qemu-x86_64-static $CHROOTDIR/usr/bin ;;
  arm*) sudo cp /usr/bin/qemu-arm-static $CHROOTDIR/usr/bin ;;
  i386) sudo cp /usr/bin/qemu-i386-static $CHROOTDIR/usr/bin ;;
  mips) sudo cp /usr/bin/qemu-mips-static $CHROOTDIR/usr/bin ;;
  mipsel) sudo cp /usr/bin/qemu-mipsel-static $CHROOTDIR/usr/bin ;;
  powerpc) sudo cp /usr/bin/qemu-ppc-static $CHROOTDIR/usr/bin ;;
  s390*) sudo cp /usr/bin/qemu-s390x-static $CHROOTDIR/usr/bin ;;
  sparc) sudo cp /usr/bin/qemu-sparc-static $CHROOTDIR/usr/bin ;;
  *) echo "arch: $arch unknown."; continue ;;
  esac

  sudo chroot $CHROOTDIR debootstrap/debootstrap --second-stage

  # Has to be done after second stage:

# don't start daemons.
sudo bash -c  "(
cat > $CHROOTDIR/usr/sbin/policy-rc.d <<EOF
#!/bin/sh
exit 101
EOF
chmod a+x $CHROOTDIR/usr/sbin/policy-rc.d
)"

# sources.list
if [ $os = debian ]; then
sudo bash -c  "(
cat > $CHROOTDIR/etc/apt/sources.list <<EOF
deb $MIRROR $dist main contrib non-free
deb-src $MIRROR $dist main contrib non-free
deb $MIRROR $dist-updates main contrib non-free
deb-src $MIRROR $dist-updates main contrib non-free
deb $SECURITY $dist/updates main contrib non-free
deb-src $SECURITY $dist/updates main contrib non-free
EOF
)"
elif [ $os = raspbian ]; then
sudo bash -c  "(
cat > $CHROOTDIR/etc/apt/sources.list <<EOF
deb http://archive.raspbian.org/raspbian $dist main contrib non-free
deb-src http://archive.raspbian.org/raspbian $dist main contrib non-free
EOF
)"
else
sudo bash -c  "(
cat > $CHROOTDIR/etc/apt/sources.list <<EOF
deb $MIRROR $dist main multiverse restricted universe
deb-src $MIRROR $dist main multiverse restricted universe
deb $MIRROR ${dist}-updates main multiverse restricted universe
deb-src $MIRROR ${dist}-updates main multiverse restricted universe
deb $MIRROR ${dist}-security main multiverse restricted universe
deb-src $MIRROR ${dist}-security main multiverse restricted universe
EOF
)"
fi

# don't bother acquiring languages.
sudo bash -c  "(
cat >> $CHROOTDIR/etc/apt/apt.conf.d/70debconf <<EOF
Acquire::Languages \"none\";
EOF
)"

  # mount the system filesystems.
  sudo mount -o bind /dev $CHROOTDIR/dev
  sudo mount -t devpts none $CHROOTDIR/dev/pts
  sudo mount -t proc none $CHROOTDIR/proc
  sudo mount -t sysfs none $CHROOTDIR/sys

  # If interactive chroot, then no hostname set.
  # sudo chroot $CHROOTDIR
  # I have no name!@x58:/# 

  sudo chroot $CHROOTDIR dpkg --print-architecture

  sudo chroot $CHROOTDIR apt-get update
  sudo chroot $CHROOTDIR apt-get install --assume-yes build-essential devscripts debhelper dpkg-dev flex bison libpq-dev
  sudo chroot $CHROOTDIR apt-get install --assume-yes deborphan rpm rpm2cpio

  sudo chroot $CHROOTDIR apt-get clean

fi

[ -z "$BUILD_PKG" ] || {
  sudo cp $LIBRTADIR/librta_${RTAVER}.orig.tar.gz $CHROOTDIR/usr/src
  sudo cp $LIBRTADIR/librta_${RTAVER}${RTADEB}.diff.gz $CHROOTDIR/usr/src
  sudo cp $LIBRTADIR/librta_${RTAVER}${RTADEB}.dsc $CHROOTDIR/usr/src

sudo bash -c "(
cat > $CHROOTDIR/usr/src/x.sh <<-EOF
#!/bin/bash
set -x
cd /usr/src
dpkg-source -x librta_${RTAVER}${RTADEB}.dsc
cd librta-${RTAVER}
dpkg-buildpackage -b -uc -us
cd ..
dpkg -i librta3*.deb
cd /usr/share/doc/librta3-examples/test
make
./app &
APP_PID=\\\`jobs -p\\\`
./librta_client
kill \\\$APP_PID
EOF
chmod +x $CHROOTDIR/usr/src/x.sh
)"

  # Check if the filesystems have already been mounted:
  mountpoint -q $CHROOTDIR/dev
  [ $? = 0 ] || {
    sudo mount -o bind /dev $CHROOTDIR/dev
    sudo mount -t devpts none $CHROOTDIR/dev/pts
    sudo mount -t proc none $CHROOTDIR/proc
    sudo mount -t sysfs none $CHROOTDIR/sys
  }

  sudo chroot $CHROOTDIR /usr/src/x.sh
  sudo chroot $CHROOTDIR dpkg --purge librta3 librta3-dev librta3-doc librta3-examples librta3-dbg
  sudo chroot $CHROOTDIR rm -fr /usr/share/doc/librta3-examples

  export PKGDIR=$PKGBASE/$os/$dist/$arch

  [ -d $PKGDIR ] || mkdir -p $PKGDIR

  sudo rm -fr $CHROOTDIR/usr/src/librta-${RTAVER}
  sudo mv $CHROOTDIR/usr/src/librta* $PKGDIR
  sudo mv $CHROOTDIR/usr/src/x.sh $PKGDIR

}

# unmount the system filesystems.
sudo umount $CHROOTDIR/dev/pts
sudo umount $CHROOTDIR/dev
sudo umount $CHROOTDIR/proc
sudo umount $CHROOTDIR/sys

done
done

