#!/bin/bash -eu
# imports
LIB_COMMON=`dirname $0`/common
. $LIB_COMMON/helpers.sh

# vars
opts=(
--internal-template openstack.yaml.template
--internal-generator-path $0
)
msgs=()
f_rel_info=`mktemp`

cleanup () { rm -f $f_rel_info; }
trap cleanup EXIT

# Series & Release Info
cat << 'EOF' > $f_rel_info
EOF
cat $LIB_COMMON/openstack_release_info.sh >> $f_rel_info

# defaults
parameters[__NUM_COMPUTE_UNITS__]=1
parameters[__NUM_CEPH_MON_UNITS__]=1
parameters[__NEUTRON_FW_DRIVER__]=openvswitch  # legacy is iptables_hybrid


while (($# > 0))
do
    case "$1" in
        --num-compute)  #type:<int>
            parameters[__NUM_COMPUTE_UNITS__]=$2
            shift
            ;;
        --barbican)
            assert_min_release queens "barbican" $@
            overlays+=( "barbican.yaml" )
            ;;
        --bgp)
            assert_min_release queens "dynamic routing" $@
            overlays+=( "neutron-bgp.yaml" )
            ;;
        --ceph)
            overlays+=( "ceph.yaml" )
            overlays+=( "openstack-ceph.yaml" )
            ;;
        --num-ceph-mons)  #type:<int>
            parameters[__NUM_CEPH_MON_UNITS__]=$2
            shift
            ;;
        --ceph-rgw)
            overlays+=( "ceph-rgw.yaml" )
            ;;
        --ceph-rgw-multisite)
            overlays+=( "ceph-rgw-multisite.yaml" )
            ;;
        --designate)
            assert_min_release ocata "designate" $@
            overlays+=( "neutron-ml2dns.yaml" )
            overlays+=( "memcached.yaml" )
            overlays+=( "designate.yaml" )
            ;;
        --dvr)
            overlays+=( "neutron-dvr.yaml" )
            get_param __DVR_DATA_PORT__ 'Please provide DVR data-port (space-separated list of interface names or mac addresses): '
            ;;
        --graylog)
            overlays+=( "graylog.yaml ")
            msgs+=( "NOTE: you will need to manually relate graylog (filebeat) to any services you want to monitor" )
            ;;
        --grafana)
            overlays+=( "grafana.yaml ")
            msgs+=( "NOTE: you will need to manually relate grafana (telegraf) to any services you want to monitor" )
            ;;
        --heat)
            overlays+=( "heat.yaml ")
            ;;
        --ldap)
            overlays+=( "ldap.yaml" )
            ;;
        --lma)
            # Logging Monitoring and Analysis
            overlays+=( "graylog.yaml ")
            msgs+=( "NOTE: you will need to manually relate graylog (filebeat) to any services you want to monitor" )
            overlays+=( "grafana.yaml ")
            msgs+=( "NOTE: you will need to manually relate grafana (telegraf) to any services you want to monitor" )
            ;;
        --neutron-fw-driver)  #type:[openvswitch|iptables_hybrid] (default=openvswitch)
            assert_min_release newton "openvswitch driver" $@
            parameters[__NEUTRON_FW_DRIVER__]=$2
            shift
            ;;
        --vrrp*)
            get_units $1 __NUM_NEUTRON_GATEWAY_UNITS__ 3
            overlays+=( "neutron-vrrp.yaml" )
            ;;
        --keystone-v3)
            # useful for <= pike since queens is v3 only
            overlays+=( "keystone-v3.yaml" )
            ;;
        --mysql-ha*)
            get_units $1 __NUM_MYSQL_UNITS__ 3
            overlays+=( "mysql-ha.yaml" )
            ;;
        --ml2dns)
            # this is internal dns integration, for external use --designate
            overlays+=( "neutron-ml2dns.yaml" )
            ;;
        --nova-cells)
            assert_min_release rocky "nova cells" $@
            overlays+=( "nova-cells.yaml" )
            ;;
        --octavia)
            # >= Rocky
            assert_min_release rocky "octavia" $@
            overlays+=( "barbican.yaml" )
            overlays+=( "vault.yaml" )
            overlays+=( "vault-openstack.yaml" )
            overlays+=( "octavia.yaml" )
            ;;
        --rabbitmq-server-ha*)
            get_units $1 __NUM_RABBIT_UNITS__ 3
            overlays+=( "rabbitmq-server-ha.yaml" )
            ;;
        --rsyslog)
            overlays+=( "rsyslog.yaml" )
            ;;
        --nova-network)
            # NOTE(hopem) yes this is a hack and we'll get rid of it hwen nova-network is finally no more
            opts+=( "--internal-template openstack-nova-network.yaml.template" )
            ;;
        --cinder-ha*)
            get_units $1 __NUM_CINDER_UNITS__ 3
            overlays+=( "cinder-ha.yaml" )
            ;;
        --designate-ha*)
            get_units $1 __NUM_DESIGNATE_UNITS__ 3
            overlays+=( "memcached.yaml" )
            overlays+=( "neutron-ml2dns.yaml" )
            overlays+=( "designate.yaml" )
            overlays+=( "designate-ha.yaml" )
            ;;
        --glance-ha*)
            get_units $1 __NUM_GLANCE_UNITS__ 3
            overlays+=( "glance-ha.yaml" )
            ;;
        --heat-ha*)
            get_units $1 __NUM_HEAT_UNITS__ 3
            overlays+=( "heat.yaml ")
            overlays+=( "heat-ha.yaml ")
            ;;
        --keystone-ha*)
            get_units $1 __NUM_KEYSTONE_UNITS__ 3
            overlays+=( "keystone-ha.yaml" )
            ;;
        --neutron-api-ha*)
            get_units $1 __NUM_NEUTRON_API_UNITS__ 3
            overlays+=( "neutron-api-ha.yaml" )
            ;;
        --nova-cloud-controller-ha*)
            get_units $1 __NUM_NOVACC_UNITS__ 3
            overlays+=( "nova-cloud-controller-ha.yaml" )
            ;;
        --openstack-dashboard-ha*)
            get_units $1 __NUM_HORIZON_UNITS__ 3
            overlays+=( "openstack-dashboard-ha.yaml" )
            ;;
        --swift)
            overlays+=( "swift.yaml" )
            ;;
        --swift-ha*)
            get_units $1 __NUM_SWIFT_PROXY_UNITS__ 3
            overlays+=( "swift-ha.yaml" )
            ;;
        --telemetry|--telemetry-gnocchi)
            # ceilometer + aodh + gnocchi (>= pike)
            assert_min_release pike "gnocchi" $@ 
            overlays+=( "ceph.yaml" )
            overlays+=( "gnocchi.yaml" )
            overlays+=( "memcached.yaml" )
            overlays+=( "telemetry.yaml" )
            ;;
        --telemetry-legacy-aodh)
            # ceilometer + aodh + mongodb (<= pike)
            overlays+=( "telemetry-legacy-aodh.yaml" )
            ;;
        --telemetry-legacy)
            # ceilometer + mongodb (<= pike)
            overlays+=( "telemetry-legacy.yaml" )
            ;;
        --telemetry-ha*)
            get_units $1 __NUM_TELEMETRY_UNITS__ 3
            overlays+=( "telemetry.yaml" )
            overlays+=( "telemetry-ha.yaml" )
            ;;
        --vault)
            assert_min_release queens "vault" $@
            overlays+=( "ceph.yaml" )
            overlays+=( "openstack-ceph.yaml" )
            overlays+=( "vault.yaml" )
            overlays+=( "vault-ceph.yaml" )
            overlays+=( "vault-openstack.yaml" )
            ;;
        --ha)
            # This is HA for services in the base bundle only.
            overlays+=( "cinder-ha.yaml" )
            overlays+=( "glance-ha.yaml" )
            overlays+=( "keystone-ha.yaml" )
            overlays+=( "neutron-api-ha.yaml" )
            overlays+=( "nova-cloud-controller-ha.yaml" )
            overlays+=( "openstack-dashboard-ha.yaml" )
            overlays+=( "rabbitmq-server-ha.yaml" )
            overlays+=( "mysql-ha.yaml" )
            ;;
        --list-overlays)
            list_overlays
            exit
            ;;
        *)
            opts+=( $1 )
            ;;
    esac
    shift
done

if ((${#msgs[@]})); then
  for m in "${msgs[@]}"; do
    echo -e "$m"
  done
read -p "Hit [ENTER] to continue"
fi

generate $f_rel_info
