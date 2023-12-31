#!/bin/bash
# Bash Shell Script ini dibuat oleh I Putu Hariyadi (putu.hariyadi@universitasbumigora.ac.id)
# Untuk mendukung praktikum pada matakuliah Cloud Computing terkait
# otomatisasi manajemen sumber daya di OpenStack

# Mendeklarasikan variable untuk pembuatan project, user dan role
PROJECT_PREFIX="belajar"
USERNAME="0827068001"
PROJECT_NAME="$PROJECT_PREFIX-$USERNAME"
USER_PASSWORD="12345678"
USER_ROLE="_member_"

# Mendeklarasikan variable untuk pembuatan provider network, subnet dan floating IP
PROVIDER_NETWORK_NAME="provider-network-$PROJECT_PREFIX"
PROVIDER_SUBNET_ADDRESS="172.16.0.0/24"
PROVIDER_SUBNET_NAME="provider-subnet-$PROJECT_PREFIX"
FLOATING_IP=("172.16.0.123" "172.16.0.234")

# Mendeklarasikan variable untuk mengunduh cirros image dari Internet
IMAGE_URL="https://download.cirros-cloud.net/0.4.0/"
IMAGE_FILENAME="cirros-0.4.0-x86_64-disk.img"
IMAGE_DESCRIPTION="Cirros untuk pembelajaran"
IMAGE_NAME="cirros-$PROJECT_PREFIX"

# Mendeklarasikan variable untuk pembuatan dua internal network dan alokasi pengalamatan
# secara dinamis menggunakan DHCP serta mengatur DNS yang dialokasikan untuk client
NETWORK_NAME1="network1-belajar"
SUBNET_NAME1="subnet1-belajar"
SUBNET_RANGE1="192.168.123.0/24"
SUBNET_POOL_START1="192.168.123.50"
SUBNET_POOL_END1="192.168.123.75"
SUBNET_DNS1="8.8.8.8"

NETWORK_NAME2="network2-belajar"
SUBNET_NAME2="subnet2-belajar"
SUBNET_RANGE2="192.168.234.0/24"
SUBNET_POOL_START2="192.168.234.225"
SUBNET_POOL_END2="192.168.234.250"
SUBNET_DNS2="8.8.4.4"

# Mendeklarasikan variable untuk pembuatan router
ROUTER_NAME="router-belajar"

# Mendeklarasikan variable untuk pembuatan dua Security Group (SG) terkait ICMP dan SSH
SG_NAME1="allow-ping"
SG_RULE_PROTOCOL1="icmp"
SG_RULE_SRC_IP1="0.0.0.0/0"
SG_NAME2="allow-ssh"
SG_RULE_PROTOCOL2="tcp"
SG_RULE_SRC_IP2="0.0.0.0/0"
SG_RULE_DST_PORT2="22"

# Mendeklarasikan variable untuk pembuatan dua instance dimana setiap instance berada
# di internal network yang berbeda dan dialokasikan floating IP
INSTANCE_NAME1="instance123"
INSTANCE_FLAVOR1="m1.tiny"
INSTANCE_NETNAME1=$NETWORK_NAME1
INSTANCE_FLOATINGIP1="172.16.0.123"

INSTANCE_NAME2="instance234"
INSTANCE_FLAVOR2="m1.tiny"
INSTANCE_NETNAME2=$NETWORK_NAME2
INSTANCE_FLOATINGIP2="172.16.0.234"

echo "Mengexport environment variable untuk otentikasi ke OpenStack dari file openrc"
source openrc

echo "Membuat project baru"
openstack project create $PROJECT_NAME

echo "Memverifikasi hasil pembuatan project"
openstack project list

echo "Membuat user baru"
openstack user create --domain $OS_PROJECT_DOMAIN_NAME --project $PROJECT_NAME --password $USER_PASSWORD $USERNAME

echo "Memverifikasi hasil pembuatan user baru"
openstack user list

echo "Mengatur role untuk user baru"
openstack role add --user $USERNAME --project $PROJECT_NAME $USER_ROLE

echo "Mengatur agar user admin memiliki role admin pada project baru"
openstack role add --user admin --project $PROJECT_NAME admin

echo "Memverifikasi hasil pengaturan role untuk user admin"
openstack role assignment list --names --project $PROJECT_NAME

echo "Membuat provider network untuk koneksi ke eksternal"
openstack network create \
--provider-physical-network public-dashboard \
--provider-network-type flat \
--project $PROJECT_NAME \
$PROVIDER_NETWORK_NAME --external

echo "Memverifikasi hasil pembuatan provider network"
openstack network list --long

echo "Membuat subnet untuk provider network"
openstack subnet create \
--network $PROVIDER_NETWORK_NAME \
--project $PROJECT_NAME \
--subnet-range $PROVIDER_SUBNET_ADDRESS \
--no-dhcp $PROVIDER_SUBNET_NAME

echo "Memverifikasi hasil pembuatan provider subnet"
openstack subnet list --long

echo "Mengubah nilai dari OpenStack environment variable untuk OS_PROJECT_NAME & OS_TENANT_NAME"
export OS_PROJECT_NAME=$PROJECT_NAME
export OS_TENANT_NAME=$PROJECT_NAME

echo "Mengalokasikan floating IP"
for ip in ${FLOATING_IP[@]}
do
	openstack floating ip create \
	--floating-ip-address $ip $PROVIDER_NETWORK_NAME
done

echo "Memverifikasi hasil pengalokasian floating IP"
openstack floating ip list

echo "Mengexport environment variable untuk otentikasi ke OpenStack dari file openrc milik project baru"
source openrc-$PROJECT_NAME

echo "Mengunduh image"
wget $IMAGE_URL$IMAGE_FILENAME --no-check-certificate

echo "Membuat image"
openstack image create \
--file $IMAGE_FILENAME --disk-format qcow2 --min-disk 1 \
--min-ram 512 --property description="$IMAGE_DESCRIPTION" $IMAGE_NAME

echo "Memverifikasi hasil pembuatan image"
openstack image list
openstack image show $IMAGE_NAME

echo "Membuat internal network dan subnet"
for i in 1 2
do
	# Membuat network
	NETNAME=NETWORK_NAME${i}
	openstack network create ${!NETNAME}

	# Membuat subnet
	SUBNAME=SUBNET_NAME${i}
	SUBRANGE=SUBNET_RANGE${i}
	SUBPOOLSTART=SUBNET_POOL_START${i}
	SUBPOOLEND=SUBNET_POOL_END${i}
	SUBDNS=SUBNET_DNS${i}

	openstack subnet create --network ${!NETNAME} \
	--subnet-range=${!SUBRANGE} ${!SUBNAME} \
	--allocation-pool start=${!SUBPOOLSTART},end=${!SUBPOOLEND} \
	--dns-nameserver=${!SUBDNS}
done

echo "Memverifikasi hasil pembuatan internal network"
openstack network list --long

echo "Memverifikasi hasil pembuatan subnet di internal network"
openstack subnet list --long

echo "Membuat router dan menghubungkan internal network ke router tersebut"
openstack router create $ROUTER_NAME

echo "Memverifikasi hasil pembuatan router"
openstack router list

echo "Menghubungkan internal network ke router"
for i in 1 2
do
	SUBNAME=SUBNET_NAME${i}
	openstack router add subnet $ROUTER_NAME ${!SUBNAME}
done

echo "Menghubungkan external network ke router"
neutron router-gateway-set $ROUTER_NAME $PROVIDER_NETWORK_NAME

echo "Memverifikasi hasil menghubungkan internal dan eksternal network ke router"
openstack port list --router $ROUTER_NAME

echo "Membuat security group dan security group rule didalamnya"
for i in 1 2
do
	# Membuat security group
	SGNAME=SG_NAME${i}
	openstack security group create ${!SGNAME} 

	# Membuat security group rule
	SGRPROTO=SG_RULE_PROTOCOL${i}
	SGRDST=SG_RULE_DST_PORT${i}
	SGRSRC=SG_RULE_SRC_IP${i}
	if [ -z ${!SGRDST+x} ]
	then
	        openstack security group rule create --protocol ${!SGRPROTO} --ingress --src-ip ${!SGRSRC} ${!SGNAME}
	else
	        openstack security group rule create --protocol ${!SGRPROTO} --ingress --dst-port ${!SGRDST} --src-ip ${!SGRSRC} ${!SGNAME}
	fi
done

echo "Memverifikasi hasil pembuatan security group"
openstack security group list

echo "Memverifikasi hasil pembuatan security group rule"
for i in 1 2
do
	SGNAME=SG_NAME${i}
	openstack security group rule list ${!SGNAME} --long
done

echo "Mengambil nama security group selain default"
ARR_SG=( $(openstack security group list -c Name -f json | jq -rc '.[] | select(.Name !="default") | .Name') )
ARR_SG_PREFIX=("${ARR_SG[@]/#/--security-group }")

echo "Membuat instance"
for i in 1 2
do
	NETNAME=INSTANCE_NETNAME${i}
	INSTNAME=INSTANCE_NAME${i}

	INSTNETID=$(openstack network show ${!NETNAME} -f json | jq -r '.id')

	INSTFLAVOR=INSTANCE_FLAVOR${i}

	openstack server create --image $IMAGE_NAME --flavor ${!INSTFLAVOR} ${ARR_SG_PREFIX[@]} --nic net-id=$INSTNETID ${!INSTNAME}
done

echo "Memverifikasi hasil pembuatan instance"
openstack server list

sleep 10

echo "Mengasosiasikan floating ip ke setiap instance"
for i in 1 2
do
        INSTNAME=INSTANCE_NAME${i}
	INSTFLOATING=INSTANCE_FLOATINGIP${i}

	openstack server add floating ip ${!INSTNAME} ${!INSTFLOATING}
done

echo "Memverifikasi hasil pembuatan instance"
openstack server list
