#!/bin/bash

# Provided under the terms of the Apache License, Version 2.0
# http://apache.org/licenses/LICENSE-2.0

# THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED.  IN NO EVENT SHALL THE APACHE SOFTWARE FOUNDATION OR
# ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.


iso_in=$1

if [ -z $iso_in ]; then
	echo 'USAGE: make.sh <path to ubuntu-10.04.iso>'
	exit 1
fi

if [ ! -f $iso_in ]; then
	echo File not found: $iso_in
	exit 1
fi

set -x

work=work
mnt=$work/mnt
ubuntu=$work/ubuntu.d
out=out
iso_out=$out/`basename $iso_in .iso`-unattended.iso

# prepare work directory
rm -r $work
mkdir $work
[ -d $out ] || mkdir $out
[ -d $mnt ] || mkdir $mnt

# extract iso image into file system
fuseiso $iso_in $mnt
cp -a $mnt/ $ubuntu
fusermount -u $mnt
chmod -R u+w $ubuntu

# boot without waiting for user input
sed -i -r 's/timeout\s+[0-9]+/timeout 1/g' $ubuntu/isolinux/isolinux.cfg

# Add boot entry for unattended install
[ -f $ubuntu/isolinux/text.cfg ] && isolinux_cfg=$ubuntu/isolinux/text.cfg
[ -f $ubuntu/isolinux/txt.cfg ] && isolinux_cfg=$ubuntu/isolinux/txt.cfg
if [ -z $isolinux_cfg ]; then echo File not found: isolinux/text.cfg ; exit 3 ; fi
cat -  > $isolinux_cfg.tmp << EOF
default unattended
label unattended
  menu label ^Unattended Install of a Minimal Ubuntu Server VM - ERASES HARD DISK -
  kernel /install/vmlinuz
  append  file=/cdrom/preseed/unattended.seed debian-installer/locale=en_US console-setup/layoutcode=us initrd=/install/initrd.gz quiet --
EOF
grep -v 'default install' $isolinux_cfg >> $isolinux_cfg.tmp
mv $isolinux_cfg.tmp $isolinux_cfg

# Copy the preseed configuration into /preseed/unattended.seed
cp preseed/unattended.seed $ubuntu/preseed/unattended.seed

# Repackage the ISO image
mkisofs -r -V "Unattended Ubuntu Install CD" \
            -cache-inodes \
            -J -l -b isolinux/isolinux.bin \
            -c isolinux/boot.cat -no-emul-boot \
            -boot-load-size 4 -boot-info-table \
            -o $iso_out $ubuntu

