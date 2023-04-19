from scapy.all import *

TYPE_IPV4  = 0x0800;
TYPE_REQUEST = 0x0829;
TYPE_GET  = 1;
TYPE_PUT  = 2;
TYPE_RANGE  = 3;
TYPE_SELECT  = 4;
TYPE_RETURNVAL = 0x0828;

class Request(Packet):
    fields_desc = [
    BitField("requestType", 0, 16),
    BitField("key", 0, 32),
    BitField("endKey", 0, 32),
    BitField("val", 0, 32),
    BitField("op", 0, 32),
    BitField("version", 0, 32),
    BitField("recordType", 0, 16),
    ByteField("is_first", 0),
    BitField("loadBalance", 0, 32),
    BitField("specialRequest", 0, 16)
    ]

class ReturnVal(Packet):
    fields_desc = [
    BitField("val", 0, 32),
    ByteField("is_first", 0)
    ]


bind_layers(Ether, Request, type=TYPE_REQUEST)
bind_layers(Request, IP, recordType=TYPE_IPV4)
bind_layers(Request, ReturnVal, recordType=TYPE_RETURNVAL)
bind_layers(ReturnVal, ReturnVal)

