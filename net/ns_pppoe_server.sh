#!/bin/bash

CMD_START=start
CMD_STOP=stop
CMD=$1
NETNS=$2
ID=$(id -u)
VETH1=veth1
VETH1_ADDR=10.10.10.1/24
VETH2=veth2
VETH2_ADDR=10.10.10.2/24
VETH_SUBNET=10.10.10.0/24

PPP_SRV_ADDR=192.168.6.1
PPP_CLIENT_ADDR=192.168.6.10

msg_ok() {
    echo "[  OK  ] $1"
}

msg_fail() {
    echo "[ FAIL ] $1"
}

if [[ $ID != 0 ]]; then
    msg_fail "Need root privileges to run. Bailout"
    exit 1
fi

if [ "$CMD" != "$CMD_START" ] && [ "$CMD" != "$CMD_STOP" ]; then
    msg_fail "Command needs to be '$CMD_START' or '$CMD_STOP'. Bailout"
    exit 1
fi

if [ -z "$NETNS" ]; then
    msg_ok "Set netns to ns_test"
    NETNS=ns_test
fi

if [ "$CMD" = "$CMD_START" ]; then
    ip netns add $NETNS
    [ "$?" == 0 ] || { msg_fail "Failed to create netns $NETNS. Bailout"; exit 1; }
    msg_ok "Netns '$NETNS' created successfully"

    ip link add $VETH1 type veth peer $VETH2 netns $NETNS
    [ "$?" == 0 ] || { msg_fail "Failed to create $VETH1/$VETH2 pair to default<->$NETNS namespaces. Bailout"; exit 1; }
    msg_ok "$VETH1/$VETH2 veth-pair created successfully" 

    ip addr add $VETH1_ADDR dev $VETH1
    [ "$?" == 0 ] || { msg_fail "Failed to add address $VETH1_ADDR to ::$VETH1. Bailout"; exit 1; }
    msg_ok "Added address $VETH1_ADDR to $VETH1 successfully"

    ip link set dev $VETH1 up
    [ "$?" == 0 ] || { msg_fail "Failed to turn ::$VETH1 ON. Bailout"; exit 1; }
    msg_ok "Turned $VETH1 ON successfully"

    ip route replace $VETH_SUBNET dev $VETH1
    [ "$?" == 0 ] || { msg_fail "Failed to add route $VETH2_ADDR -> ::$VETH1. Bailout"; exit 1; }
    msg_ok "Added route $VETH2_ADDR -> $VETH1 successfully"

    ip netns exec $NETNS ip addr add $VETH2_ADDR dev $VETH2
    [ "$?" == 0 ]  || { msg_fail "Failed to add address $VETH2_ADDR to $NETNS::$VETH2. Bailout"; exit 1; }
    msg_ok "Add address $VETH2_ADDR to $VETH2 successfully"

    ip netns exec $NETNS ip link set dev $VETH2 up
    [ "$?" == 0 ] || { msg_fail "Failed to turn $NETNS::$VETH2 ON. Bailout"; exit 1; }
    msg_ok "Turned $NETNS::$VETH1 ON successfully"

    ip netns exec $NETNS ip route replace $VETH_SUBNET dev $VETH2
    [ "$?" == 0 ] || { msg_fail "Failed to add route $VETH2_ADDR -> $NETNS::$VETH1. Bailout"; exit 1; }
    msg_ok "Added route $VETH1_ADDR -> $NETNS::$VETH2 successfully"

    ip netns exec $NETNS pppoe-server -I $VETH2 -L $PPP_SRV_ADDR -R $PPP_CLIENT_ADDR
    [ "$?" == 0 ] || { msg_fail "Failed to start pppoe-server. Bailout"; exit 1; }
    msg_ok "Started pppoe-server successfully"
elif [ "$CMD" = "$CMD_STOP" ]; then
    pkill pppoe-server
    [ "$?" == 0 ] || { msg_fail "Failed to kill pppoe-server. Bailout"; exit 1; }
    msg_ok "Stopped pppoe-server successfully"

    ip netns exec $NETNS ip route del $VETH_SUBNET dev $VETH2
    [ "$?" == 0 ] || { msg_fail "Failed to del route $NETNS::$VETH_SUBNET. Bailout"; exit 1; }
    msg_ok "Removed route $NETNS::$VETH_SUBNET successfully"

    ip route del $VETH_SUBNET dev $VETH1
    [ "$?" == 0 ] || { msg_fail "Failed to del route ::$VETH_SUBNET. Bailout"; exit 1; }
    msg_ok "Removed route ::$VETH_SUBNET successfully"

    ip netns exec $NETNS ip link del $VETH2
    [ "$?" == 0 ] || { msg_fail "Failed to del link $NETNS::$VETH2. Bailout"; exit 1; }
    msg_ok "Removed link $NETNS::$VETH2 successfully"

    ip netns del $NETNS
    [ "$?" == 0 ] || { msg_fail "Failed to del netns $NETNS. Bailout"; exit 1; }
    msg_ok "Removed netns $NETNS successfully"
fi

