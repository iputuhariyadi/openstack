#!/bin/bash
# Bash Shell Script ini dibuat oleh I Putu Hariyadi (putu.hariyadi@universitasbumigora.ac.id)
# Untuk mendukung praktikum pada matakuliah Cloud Computing terkait 
# otomatisasi manajemen sumber daya di OpenStack

# Mendeklarasikan variable untuk penghapusan project dan user
PROJECT_PREFIX="belajar"
USERNAME="0827068001"
PROJECT_NAME="$PROJECT_PREFIX-$USERNAME"

# Mendeklarasikan variable untuk penghapusan image
IMAGE_NAME="cirros-$PROJECT_PREFIX"

# Mendeklarasikan variable untuk penghapusan router
ROUTER_NAME="router-belajar"

# Mengexport environment variable untuk otentikasi ke OpenStack dari file openrc milik project baru
source openrc-$PROJECT_NAME

echo "Menampilkan informasi daftar instance"
openstack server list

# Mengambil instance name
ARR_INSTANCES=( $(openstack server list -c Name -f json | jq -rc '.[] | .Name') )

echo "Menghentikan seluruh instance"
openstack server stop ${ARR_INSTANCES[@]}

echo "Menghapus seluruh instance"
openstack server delete ${ARR_INSTANCES[@]}

echo "Menampilkan informasi daftar instance"
openstack server list

echo "Menghapus image"
openstack image delete $IMAGE_NAME

echo "Menampilkan informasi daftar image"
openstack image list

# Mengambil nama security group selain default
ARR_SG=( $(openstack security group list -c Name -f json | jq -rc '.[] | select(.Name !="default") | .Name') )

echo "Menghapus security group"
openstack security group delete ${ARR_SG[@]}

echo "Menampilkan informasi daftar security group"
openstack security group list

# Mengambil Floating IP Address yang akan dihapus
ARR_FLOATING=( $(openstack floating ip list -c "Floating IP Address" -f json | jq -rc '.[] | ."Floating IP Address"') )

echo "Menghapus floating ip"
openstack floating ip delete ${ARR_FLOATING[@]}

echo "Menampilkan informasi daftar Floating IP"
openstack floating ip list

echo "Menghapus gateway dari router"
neutron router-gateway-clear $ROUTER_NAME 

# Mengambil nama dari seluruh subnet
ARR_SUBNET=( $(openstack subnet list -c Name -f json | jq -rc '.[] | .Name') )

echo "Menghapus seluruh subnet"
for SUBNAME in ${ARR_SUBNET[@]}
do
	openstack router remove subnet $ROUTER_NAME $SUBNAME
done

echo "Menghapus router"
openstack router delete $ROUTER_NAME

echo "Menampilkan daftar router"
openstack router list

# Mengambil nama dari seluruh network
ARR_NETWORK=( $(openstack network list -c Name -f json | jq -rc '.[] | .Name') )

echo "Menghapus seluruh network"
openstack network delete ${ARR_NETWORK[@]}

echo "Menampilkan daftar network"
openstack network list

# Mengexport environment variable untuk otentikasi ke OpenStack dari file openrc agar login sebagai admin
source openrc

echo "Menghapus user"
openstack user delete $USERNAME

echo "Menampilkan daftar user"
openstack user list

echo "Menghapus project"
openstack project delete $PROJECT_NAME

echo "Menampilkan daftar project"
openstack project list

