#!/usr/bin/env python3

from new_headers import *


def expand(x):
    yield x
    while x.payload:
        x = x.payload
        yield x

def handle_pkt(pkt):
    print()
    if Request in pkt:
        # for l in expand(pkt):
        #     print(l.name)
        data_layers = [l for l in expand(pkt) if l.name=='Request']
        for sw in data_layers:
            #print(sw.layers)
            print("request type", sw.requestType)
            print("key", sw.key)
            print("val", sw.val)
            print("is_first", sw.is_first)

        data_layers = [l for l in expand(pkt) if l.name=='ReturnVal']
        for sw in data_layers:
            #print(sw.layers)
            print("return val")
            print("val", sw.val)
    print()

def main():
    iface = 'eth0'
    print("sniffing on {}".format(iface))

    sniff(iface = iface, prn = lambda x: handle_pkt(x))

if __name__ == '__main__':
    main()
