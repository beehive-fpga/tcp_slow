import cocotb

from bitfields import bitfield, bitfieldManip
from cocotb.binary import BinaryValue

class AbstractStruct():
    def __init__(self, init_bitstring=None):
        if init_bitstring is not None:
            self.fromBinaryValue(init_bitstring)

    def setField(self, field_name, value):
        index = self.bitfield_indices[field_name]
        self.bitfields[index].set_value(value)

    def getField(self, field_name):
        index = self.bitfield_indices[field_name]
        return self.bitfields[index].value

    def getBitfield(self, field_name):
        index = self.bitfield_indices[field_name]
        return self.bitfields[index]

    def toBinaryValue(self):
        field_manip = bitfieldManip(self.bitfields)
        bitstr = field_manip.gen_bitstring()

        return BinaryValue(value=bitstr, n_bits=len(bitstr))

    def getWidth(self):
        total_w = 0
        for bitfield in self.bitfields:
            total_w += bitfield.size

        return total_w

    def fromBinaryValue(self, value):
        bitstr = value.binstr
        bitstring_index = 0
        for field in self.bitfields:
            value_bitstr = field.parse_bitstring(bitstr[bitstring_index:])
            value = field.value_fr_bitstring(value_bitstr)
            field.set_value(value)

            bitstring_index += len(value_bitstr)

    def __repr__(self):
        repr_str = ""
        for bitfield in self.bitfields:
            repr_str += f"{bitfield}\n"
        return repr_str

class SchedCmdStruct(AbstractStruct):
    SET = 0
    CLEAR = 1
    NOP = 2

    FLOWID_W = 4
    CMD_W = 2
    TIMESTAMP_W = 64

    def __init__(self, flowid=None, rt_cmd=None, ack_cmd=None, data_cmd=None, init_bitstring=None):
        self.bitfields = [
            bitfield("flowid", self.FLOWID_W, value=flowid),
            bitfield("rt_cmd", self.CMD_W, value=rt_cmd),
            bitfield("rt_cmd_time", self.TIMESTAMP_W, value=0),
            bitfield("ack_cmd", self.CMD_W, value=ack_cmd),
            bitfield("ack_cmd_time", self.TIMESTAMP_W, value=0),
            bitfield("data_cmd", self.CMD_W, value=data_cmd),
            bitfield("data_cmd_time", self.TIMESTAMP_W, value=0)
        ]
        self.bitfield_indices = {
            "flowid": 0,
            "rt_cmd": 1,
            "rt_cmd_time": 2,
            "ack_cmd": 3,
            "ack_cmd_time": 4,
            "data_cmd": 5,
            "data_cmd_time": 6
        }
        super().__init__(init_bitstring=init_bitstring)

class PayloadBufStruct(AbstractStruct):
    SIZE_W = 16
    ADDR_W = 32
    def __init__(self, addr=None, size=None, init_bitstring=None):
        val_addr = 0
        val_size = 0
        if addr is not None:
            val_addr = addr
        if size is not None:
            val_size = size
        self.bitfields = [
           bitfield("addr", self.ADDR_W, value=val_addr, trunc_value=True),
           bitfield("size", self.SIZE_W, value=val_size, trunc_value=True)
        ]

        self.bitfield_indices = {
            "addr": 0,
            "size": 1
        }
        super().__init__(init_bitstring=init_bitstring)

class FourTupleStruct(AbstractStruct):
    IP_ADDR_W = 32
    PORT_W = 16

    def __init__(self, host_ip=None, dest_ip=None, host_port=None,
            dest_port=None, init_bitstring=None):
        self.bitfields = [
            bitfield("host_ip", self.IP_ADDR_W, value=host_ip),
            bitfield("dest_ip", self.IP_ADDR_W, value=dest_ip),
            bitfield("host_port", self.PORT_W, value=host_port),
            bitfield("dest_port", self.PORT_W, value=dest_port)
        ]

        self.bitfield_indices = {
            "host_ip": 0,
            "dest_ip": 1,
            "host_port": 2,
            "dest_port": 3
        }

        super().__init__(init_bitstring=init_bitstring)
