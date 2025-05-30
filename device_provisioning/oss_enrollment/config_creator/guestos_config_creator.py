# -*- coding: utf-8 -*-
#
# This file is part of GyroidOS
# Copyright(c) 2013 - 2017 Fraunhofer AISEC
# Fraunhofer-Gesellschaft zur Förderung der angewandten Forschung e.V.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2 (GPL 2), as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GPL 2 license for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses/>
#
# The full GNU General Public License is included in this distribution in
# the file called "COPYING".
#
# Contact Information:
# Fraunhofer AISEC <gyroidos@aisec.fraunhofer.de>
#

import argparse
import hashlib
import os
import sys
from time import strftime
from google.protobuf import text_format

import guestos_pb2

IMAGE_PATH_PREFIX = "./"
IMAGE_PATH_SUFFIX = ".img"
SHARED = 1
EMPTY = 4
FLASH = 6
OVERLAY_RO = 7
SHARED_RW = 8
OVERLAY_RW = 9

parser = argparse.ArgumentParser(description='Generate a guestos config file '
                                             'using a basic config.')
parser.add_argument('-b', '--path_to_basic_config',
                   dest="path_to_basic_config", default="a0os.conf",
                   help='Path to the basic config')
parser.add_argument('-c', '--path_to_new_config', dest='path_to_new_config',
                   default="new_config.conf",
                   help='Path where the generated config is saved')
parser.add_argument('-n', '--name', dest='name', default="a0os",
                   help='Name of the os')
parser.add_argument('-i', '--path_to_images', dest='path_to_images',
                   default=IMAGE_PATH_PREFIX,
                   help='Path to mount images')
parser.add_argument('-v', '--version', dest='version', default="debug",
                   help='Version of the os')
parser.add_argument('-s', '--def_size', dest='def_size', default="512",
                   help='Default size of userdata partition of a container')
parser.add_argument('-d', '--digest', dest='root_hash', default="",
                   help="dm-verity device root hash for readonly guestos rootfs")
parser.add_argument('-u', '--upstream_version', dest='upstream_version', default="",
                   help="Upstream version for os")

args = parser.parse_args()
guestos = guestos_pb2.GuestOSConfig()

try:
    with open(args.path_to_basic_config, "rb") as f:
        text_format.Merge(f.read(), guestos)
except IOError:
    print(sys.argv[1] + ": Could not open config file. Aborting.")
    sys.exit()

guestos.build_date = strftime("%Y-%m-%dT%H:%M:%S%Z")
guestos.name = args.name
guestos.version = int(args.version)
guestos.upstream_version = args.upstream_version

def set_mounts_hashes( mounts ):
    for mount in mounts:
        if mount.mount_type == SHARED or mount.mount_type == FLASH or mount.mount_type == OVERLAY_RO or mount.mount_type == SHARED_RW:
            mount_image_path = args.path_to_images + mount.image_file + \
                               IMAGE_PATH_SUFFIX
            image_size = os.path.getsize(mount_image_path)
            mount.image_size = image_size
            with open(mount_image_path, 'rb') as f:
                sha1 = hashlib.sha1()
                sha256 = hashlib.sha256()
                while True:
                    data = f.read(1<<20)
                    if not data:
                        break
                    sha1.update(data)
                    sha256.update(data)
                mount.image_sha1 = sha1.hexdigest()
                mount.image_sha2_256 = sha256.hexdigest()
                if args.root_hash != "":
                    mount.image_verity_sha256 = args.root_hash
        elif mount.mount_type == EMPTY:
            if mount.image_file == "data":
                #print "Set default size for userdata of container to: " + args.def_size + "(Mb)"
                mount.def_size = int(args.def_size)
    return

set_mounts_hashes( guestos.mounts )
if hasattr(guestos, 'mounts_setup'):
    set_mounts_hashes( guestos.mounts_setup )

try:
    with open(args.path_to_new_config, "w") as f:
        f.write(text_format.MessageToString(guestos))
except IOError:
    print(sys.argv[1] + ": Could not open new config file for writing. Aborting.")
    sys.exit()
