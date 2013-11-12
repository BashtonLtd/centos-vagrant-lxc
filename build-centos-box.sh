#!/bin/bash

# Build a new CentOS6 install in a chroot
# Loosely based on http://wiki.1tux.org/wiki/Centos6/Installation/Minimal_installation_using_yum

releasever=6.4
arch=x86_64
ROOTFS=/rootfs
VAGRANT_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key"

### Basic CentOS Install
mkdir -p $ROOTFS
rpm --root=$ROOTFS --initdb
rpm --root=$ROOTFS -ivh \
  http://mirror.centos.org/centos/6.4/os/x86_64/Packages/centos-release-6-4.el6.centos.10.x86_64.rpm
# Install necessary packages
yum --installroot=$ROOTFS --nogpgcheck -y groupinstall base

cp -a /etc/skel/.bash* ${ROOTFS}/root
cat > ${ROOTFS}/etc/hosts << END
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

127.0.1.1   centos6
END
cat > ${ROOTFS}/etc/sysconfig/network << END
NETWORKING=yes
HOSTNAME=centos6
END
cat > ${ROOTFS}/etc/sysconfig/network-scripts/ifcfg-eth0  << END
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=dhcp
END
cp /usr/share/zoneinfo/UTC ${ROOTFS}/etc/localtime
### End basic CentOS Install

### Vagrant modifications
yum --installroot=$ROOTFS --nogpgcheck -y install dhclient sudo openssh-server
for dir in proc sys dev; do
  mount --bind /${dir} ${ROOTFS}/${dir}
done

# Add vagrant user
chroot $ROOTFS useradd --create-home -s /bin/bash vagrant
echo -n 'vagrant:vagrant' | chroot $ROOTFS chpasswd
echo 'vagrant ALL = NOPASSWD: ALL' > ${ROOTFS}/etc/sudoers.d/vagrant
chmod 440 ${ROOTFS}/etc/sudoers.d/vagrant
mkdir -p ${ROOTFS}/home/vagrant/.ssh
chmod 700 ${ROOTFS}/home/vagrant/.ssh
echo $VAGRANT_KEY > ${ROOTFS}/home/vagrant/.ssh/authorized_keys
chmod 600 ${ROOTFS}/home/vagrant/.ssh/authorized_keys
chroot ${ROOTFS} chown -R vagrant:vagrant /home/vagrant/.ssh
# Allow sudo without a tty
sed -i -e 's/Defaults.*requiretty/#&/' ${ROOTFS}/etc/sudoers

# Install Puppet
yum --installroot=$ROOTFS --nogpgcheck -y install http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-7.noarch.rpm
yum --installroot=$ROOTFS --nogpgcheck -y install puppet

# disable loginuid.so
sed -i '/session\(.*loginuid.so\)$/d' ${ROOTFS}/etc/pam.d/*

# set gettys right
sed -i 's|ACTIVE_CONSOLES=/dev/tty\[1-6\]|ACTIVE_CONSOLES=/dev/lxc/tty\[1-4\]|' ${ROOTFS}/etc/sysconfig/init
# If you want chef or whatever support, submit a pull request
for dir in proc sys dev; do
  umount ${ROOTFS}/${dir}
done
### End Vagrant modifications

# Build a tarball, then a box file
mkdir -p /tmp/centos-vagrant-lxc
cp -R /vagrant/metadata/* /tmp/centos-vagrant-lxc
tar zcf /tmp/centos-vagrant-lxc/rootfs.tar.gz --numeric-owner -C / rootfs
now=$(date -u)
curdate=$(date -u +"%Y-%m-%d")
sed -i -e "s/_DATE_/${now}/" /tmp/centos-vagrant-lxc/metadata.json
tar zcf /vagrant/lxc-centos${releasever}-${curdate}.box -C /tmp/centos-vagrant-lxc .
