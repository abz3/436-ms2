/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4  = 0x800;
// const bit<16> TYPE_RECORD  = 0x801;
const bit<16> TYPE_REQUEST = 0x829;
const bit<16> TYPE_RETURNVAL = 0x828;
const bit<16> TYPE_PROBE = 0x812;

const bit<16> TYPE_GET  = 1;
const bit<16> TYPE_PUT  = 2;
const bit<16> TYPE_RANGE  = 3;
const bit<16> TYPE_SELECT  = 4;

const bit<16> TYPE_PING = 5;
const bit<16> TYPE_PONG = 6;

#define MAX_REQUESTS 1025

#define MAX_HOPS 10
#define MAX_PORTS 8

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

typedef bit<48> time_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}


header returnval_t {
    bit<32> val;
    bit<8> is_first;
}

header request_t {
    bit<16> requestType;
    bit<32> key;
    bit<32> endKey;
    bit<32> val;
    bit<32> op;
    bit<32> version;
    bit<16> recordType;
    bit<8> is_first;
    bit<32> loadBalance;
    bit<16> specialRequest;
}

// Indicates the egress port the switch should send this probe
// packet out of. There is one of these headers for each hop.
header probe_fwd_t {
    bit<8>   egress_spec;
}

header record_t {
    bit<16> loadBalancingMethod;
    bit<16> uniqueId;
    bit<16> recordType;
}

struct parser_metadata_t {
    bit<8>  remaining;
}

struct metadata {
    bit<8> egress_spec;
    parser_metadata_t parser_metadata;
    bit<16> recordType;
    bit<16> loadBalancingMethod;
    bit<14> ecmp;
    bit<16> total_cnt;
    bit<16> flowlet_count;
    bit<32> flowlet_key;
    bit<32> key;
    bit<32> endKey;
    bit<16> requestType;
    bit<32> pointer;
}

struct headers {
    ethernet_t              ethernet;
    request_t                request;
    returnval_t[MAX_REQUESTS] returnval;
    ipv4_t                  ipv4;
    tcp_t                   tcp;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_REQUEST: parse_request;
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_request {
        packet.extract(hdr.request);
        transition select(hdr.request.recordType) {
            TYPE_IPV4: parse_ipv4;
            TYPE_RETURNVAL: parse_returnval;
            default: accept;
        }
    }

    state parse_returnval {
        packet.extract(hdr.returnval.next);
        transition select(hdr.returnval.last.is_first) {
            1: accept;
            default: parse_returnval;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            6: parse_tcp;
            default: accept;
        }
    }

    state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }


}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    register<bit<32>>(1025 * 6) db;
    register<bit<32>>(1025) latest_version; /* Keeps track of the highest version count of each key */
    
    register<bit<32>>(2) packet_num;
    register<bit<32>>(2) pings;
    register<bit<32>>(2) pongs;

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action get_handler() {
        bit<32> val;
        db.read(val, (bit<32>) ((hdr.request.key * 6) + hdr.request.version));

        hdr.returnval[0].val = val;
        standard_metadata.egress_spec = 2;
    }

    action put_handler() {
        bit<32> vers;
        bit<32> newVers;

        latest_version.read(vers, (bit<32>) hdr.request.key);

        db.write((bit<32>) ((hdr.request.key * 6) + vers), hdr.request.val);

        newVers = vers + 1;
        latest_version.write((bit<32>) hdr.request.key, newVers);
        standard_metadata.egress_spec = 2;
    }

    action range_handler() {
        bit<32> val;
        db.read(val, (bit<32>) ((hdr.request.key * 6) + hdr.request.version));

        hdr.returnval[0].val = val;

        hdr.request.key = hdr.request.key + 1;
        standard_metadata.egress_spec = 2;
    }

    action load_balance_put() {
        bit<32> val;
        packet_num.read(val, (bit<32>) (hdr.request.loadBalance - 2));
        packet_num.write((bit<32>) (hdr.request.loadBalance - 2), val + 1);

        bit<32> ping;
        pings.read(ping, (bit<32>) (hdr.request.loadBalance - 2));

        bit<32> pong;
        pongs.read(pong, (bit<32>) (hdr.request.loadBalance - 2));

        hdr.request.specialRequest = 1;
        const bit<32> STANDBY = 3;
        clone(CloneType.I2E, STANDBY);

        // ARBITRARY FAULT TOLERANCE
        if (ping - pong > 3) {
            standard_metadata.egress_spec = 4;
        }
        else {
            standard_metadata.egress_spec = (bit<9>) hdr.request.loadBalance;
        }

    }

    action load_balance_other() {
        bit<32> val;
        packet_num.read(val, (bit<32>) (hdr.request.loadBalance - 2));
        packet_num.write((bit<32>) (hdr.request.loadBalance - 2), val + 1);

        bit<32> ping;
        pings.read(ping, (bit<32>) (hdr.request.loadBalance - 2));

        bit<32> pong;
        pongs.read(pong, (bit<32>) (hdr.request.loadBalance - 2));

        hdr.request.specialRequest = 1;

        // ARBITRARY FAULT TOLERANCE
        if (ping - pong > 3) {
            standard_metadata.egress_spec = 4;
        }
        else {
            standard_metadata.egress_spec = (bit<9>) hdr.request.loadBalance;
        }
    }

    action ping_handler() {
        // send pong to port 1
        standard_metadata.egress_spec = 1;
        hdr.request.requestType = TYPE_PONG;
    }
    
    action pong_handler() {
        bit<32> pong;
        pongs.read(pong, (bit<32>) (hdr.request.loadBalance - 2));
        pongs.write((bit<32>) (hdr.request.loadBalance - 2), pong + 1);
    }

    table request_exact {
        key = {
            hdr.request.requestType: exact;
        }
        actions = {
            get_handler;
            put_handler;
            range_handler;
            // select_handler;
            load_balance_put;
            load_balance_other;
            ping_handler;
            pong_handler;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }


    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    apply {

        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
        }
        else if (hdr.request.isValid()) {
            if (hdr.request.specialRequest == 0) {
                bit<32> val;
                packet_num.read(val, (bit<32>) (hdr.request.loadBalance - 2));
                if (val == 10) {
                    bit<32> PING;
                    if (hdr.request.loadBalance == 2) {
                        PING = 1;
                    }
                    else {
                        PING = 2;
                    }
                    bit<16> oldType;
                    oldType = hdr.request.requestType;
                    hdr.request.requestType = TYPE_PING;
                    clone(CloneType.I2E, PING);
                    packet_num.write((bit<32>) (hdr.request.loadBalance - 2), 0);
                    hdr.request.requestType = oldType;

                }
            }
            if (hdr.request.specialRequest == 1) {
            if (hdr.request.requestType == TYPE_SELECT) {
                hdr.request.requestType = TYPE_RANGE;

                // 1 is >, 2 is >=, 3 is <, 4 is <=, 5 is ==
                if (hdr.request.op == 1) {
                    hdr.request.key = hdr.request.key + 1;
                    hdr.request.endKey = 1024;
                } else if (hdr.request.op == 2) {
                    hdr.request.endKey = 1024;
                } else if (hdr.request.op == 3) {
                    hdr.request.endKey = hdr.request.key - 1;
                    hdr.request.key = 0;
                } else if (hdr.request.op == 4) {
                    hdr.request.endKey = hdr.request.key;
                    hdr.request.key = 0;
                } else if (hdr.request.op == 5) {
                    hdr.request.endKey = hdr.request.key;
                }
            }
            
            if (hdr.request.requestType == TYPE_RANGE) {
                // In this case, turn request[1] into request[0]
                if (hdr.request.key >= hdr.request.endKey) {
                    hdr.request.requestType = TYPE_GET;
                }
            }
            if (hdr.request.is_first != 0) {
                hdr.request.is_first = 0;
                hdr.returnval[0].is_first = 1;
            } else {
                hdr.returnval.push_front(1);
                hdr.returnval[0].setValid();
            }

            }

            request_exact.apply();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   ********************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    apply {
        if (hdr.request.specialRequest == 1) {
            if ((hdr.request.requestType == TYPE_RANGE) || (hdr.request.requestType == TYPE_SELECT)) {
            recirculate_preserving_field_list(0);
            }
        }
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   ***************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
     apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.request);
        packet.emit(hdr.returnval);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
        
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
