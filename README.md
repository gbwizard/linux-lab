# A set of linux-specific scripts, configs, etc

* net/pppoe_server_ns.sh - Start PPPoE server in a separate namespace for PPPoE test purposes. A pair of VETH interfaces are used to communicate it. Now you can run pon/poff command in default namespace to connect to this PPPoE server.