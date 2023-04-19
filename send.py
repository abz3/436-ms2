#!/usr/bin/env python3
import sys
import time
import random

from new_headers import *

# TO TA: EDIT HERE. FORMAT IS
# ("PUT", key, val) e.g. ("PUT", 0, 10)
# ("GET", key, version) e.g. ("GET", 0, 1)
# ("RANGE", key, endKey, version) e.g ("RANGE", 2, 3, 1)
# ("SELECT", val, op, version) e.g. ("SELECT", 100, "<", 2)
packets_to_send = [("PUT", 0, 10), ("PUT", 0, 12), ("PUT", 2, 5), 
("GET", 0, 0), ("GET", 0, 1), ("GET", 0, 2), ("GET", 2, 0), 
("RANGE", 0, 0, 0), ("RANGE", 0, 0, 1), ("RANGE", 0,  2, 0), 
("SELECT", 5, "<", 0), ("SELECT", 0, "<=", 0), ("SELECT", 0, "==", 1)]

simple_packet = [("PUT", 0, 10), ("GET", 0, 0)]

# // 1 is >, 2 is >=, 3 is <, 4 is <=, 5 is ==
select_op_mapper = {">": 1, ">=": 2, "<": 3, "<=": 4, "==": 5}

def processor(packets_to_send):
    new = []
    for i in packets_to_send:
        if i[0] == "GET":
            if i[1] <= 512:
                pkt = Ether(dst='ff:ff:ff:ff:ff:ff', src=get_if_hwaddr('eth0')) / \
                    Request(requestType=TYPE_GET, key=i[1], endKey=0, val=0, op=0, version=i[2], is_first=1, loadBalance=2, specialRequest=0) / \
                    ReturnVal(val=0, is_first=1)
                new.append(pkt)
            else:
                pkt = Ether(dst='ff:ff:ff:ff:ff:ff', src=get_if_hwaddr('eth0')) / \
                    Request(requestType=TYPE_GET, key=i[1], endKey=0, val=0, op=0, version=i[2], is_first=1, loadBalance=3, specialRequest=0) / \
                    ReturnVal(val=0, is_first=1)
                new.append(pkt)
        elif i[0] == "PUT":
            if i[1] <= 512:
                pkt = Ether(dst='ff:ff:ff:ff:ff:ff', src=get_if_hwaddr('eth0')) / \
                    Request(requestType=TYPE_PUT, key=i[1], endKey=0, val=i[2], op=0, version=0, is_first=1, loadBalance=2, specialRequest=0)
                new.append(pkt)
            else:
                pkt = Ether(dst='ff:ff:ff:ff:ff:ff', src=get_if_hwaddr('eth0')) / \
                    Request(requestType=TYPE_PUT, key=i[1], endKey=0, val=i[2], op=0, version=0, is_first=1, loadBalance=3, specialRequest=0)
                new.append(pkt)
        elif i[0] == "RANGE":
            range_pkts = []
            # 10 is maximum.
            break_number = 10
            for j in range(int((i[2] - i[1]) / break_number) + 1):
                if i[1] <= 512:
                    pkt = Ether(dst='ff:ff:ff:ff:ff:ff', src=get_if_hwaddr('eth0')) / \
                        Request(requestType=TYPE_RANGE, key=i[1] + j * break_number, endKey=i[2], val=0, op=0, version=i[3], is_first=1, loadBalance=2, specialRequest=0) / \
                        ReturnVal(val=0, is_first=1) 
                    range_pkts.append(pkt)
                else:
                    pkt = Ether(dst='ff:ff:ff:ff:ff:ff', src=get_if_hwaddr('eth0')) / \
                        Request(requestType=TYPE_RANGE, key=i[1] + j * break_number, endKey=i[2], val=0, op=0, version=i[3], is_first=1, loadBalance=3, specialRequest=0) / \
                        ReturnVal(val=0, is_first=1) 
                    range_pkts.append(pkt)

            new = new + range_pkts
        elif i[0] == "SELECT":
            if i[1] <= 512:
                pkt = Ether(dst='ff:ff:ff:ff:ff:ff', src=get_if_hwaddr('eth0')) / \
                Request(requestType=TYPE_SELECT, key=i[1], endKey=3, val=0, op=select_op_mapper[i[2]], version=i[3], is_first=1, loadBalance=2, specialRequest=0) / \
                ReturnVal(val=0, is_first=1) 
                new.append(pkt)
            else:
                pkt = Ether(dst='ff:ff:ff:ff:ff:ff', src=get_if_hwaddr('eth0')) / \
                Request(requestType=TYPE_SELECT, key=i[1], endKey=3, val=0, op=select_op_mapper[i[2]], version=i[3], is_first=1, loadBalance=3, specialRequest=0) / \
                ReturnVal(val=0, is_first=1) 
                new.append(pkt)
    return new

packets_to_send = processor(packets_to_send)
simple_packet = processor(simple_packet)

def main():

    try:
        sendp(simple_packet, iface='eth0')
        time.sleep(10)
    except KeyboardInterrupt:
        sys.exit()

if __name__ == '__main__':
    main()
