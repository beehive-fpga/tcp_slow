import logging
import cocotb
from collections import deque

from cocotb.triggers import Event, RisingEdge, Combine, with_timeout
from cocotb.result import SimTimeoutError
from cocotb.binary import BinaryValue
from cocotb.log import SimLog

from scapy.layers.l2 import Ether, ARP
from scapy.layers.inet import IP, UDP, TCP
from scapy.packet import Raw

import sys
import os
sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common/")
from bitfields import bitfield, bitfieldManip

from generic_val_rdy import GenericValRdyBus, GenericValRdySource, GenericValRdySink
from beehive_bus import BeehiveBusSource, BeehiveBusSink
from bitfields import bitfield, bitfieldManip

from rx_store_buf_mimic import BufCopier
from tmp_buf_mimic import TmpBufMimic
from circ_buf_helpers import circBuf, payloadPtrBitfield
from tcp_slow_test_structs import PayloadBufStruct

async def reset(dut):
    dut.rst.setimmediatevalue(0)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

class AppIFMimic():
    def __init__(self, flow_notif_op, sched_update_op,
            rx_head_wr_op, rx_head_rd_req_op, rx_head_rd_resp_op,
            rx_commit_rd_req_op, rx_commit_rd_resp_op,
            tx_head_rd_req_op, tx_head_rd_resp_op,
            tx_tail_wr_op, tx_tail_rd_req_op, tx_tail_rd_resp_op):

        self.log = SimLog("cocotb.tb.hw_app")
        self.log.setLevel(logging.DEBUG)

        self.flow_notif_op = flow_notif_op
        self.sched_update_op = sched_update_op

        self.rx_head_wr_op = rx_head_wr_op
        self.rx_head_rd_req_op = rx_head_rd_req_op
        self.rx_head_rd_resp_op = rx_head_rd_resp_op

        self.rx_commit_rd_req_op = rx_commit_rd_req_op
        self.rx_commit_rd_resp_op = rx_commit_rd_resp_op

        self.tx_head_rd_req_op = tx_head_rd_req_op
        self.tx_head_rd_resp_op = tx_head_rd_resp_op

        self.tx_tail_wr_op = tx_tail_wr_op
        self.tx_tail_rd_req_op = tx_tail_rd_req_op
        self.tx_tail_rd_resp_op = tx_tail_rd_resp_op

class TCPSlowTB():
    def __init__(self, dut):
        # setup all the buses
        init_signals(dut)
        self.done_event = Event()
        self.CLOCK_CYCLE_TIME = 4
        self.MIN_PKT_SIZE=64
        self.MAX_NUM_FLOWS = 8
        self.CIRC_BUF_SIZE = 1 << 14
        self.CLIENT_LEN_BYTES = 2
        self.IP_TO_MAC = {
            "198.0.0.5": "b8:59:9f:b7:ba:44",
            "198.0.0.7": "00:0a:35:0d:4d:c6",
        }
        self.MAC_W = 512

        self.tmp_buf = TmpBufMimic(20)

        self.log = SimLog("cocotb.tb.sw_app")
        self.log.setLevel(logging.DEBUG)

        self.clk=dut.clk

        self.rx_pkt_in_bus = GenericValRdyBus(dut,
                {"val": "src_tcp_rx_hdr_val",
                 "rdy": "tcp_src_rx_hdr_rdy",
                 "src_ip": "src_tcp_rx_src_ip",
                 "dst_ip": "src_tcp_rx_dst_ip",
                 "tcp_hdr": "src_tcp_rx_tcp_hdr",
                 "payload": "src_tcp_rx_payload_entry"})
        self.rx_pkt_in_op = GenericValRdySource(self.rx_pkt_in_bus, dut.clk)

        self.tx_pkt_out_bus = GenericValRdyBus(dut,
                {"val": "tx_pkt_hdr_val",
                 "rdy": "tx_pkt_hdr_rdy",
                 "flowid": "tx_pkt_flowid",
                 "tcp_hdr": "tx_pkt_hdr",
                 "src_ip": "tx_pkt_src_ip_addr",
                 "dst_ip": "tx_pkt_dst_ip_addr",
                 "payload": "tx_pkt_payload"})
        self.tx_pkt_out_op = GenericValRdySink(self.tx_pkt_out_bus, dut.clk)

        self.buf_cpy_out_bus = GenericValRdyBus(dut,
                {"val": "tcp_rx_dst_hdr_val",
                 "flowid": "tcp_rx_dst_flowid",
                 "accept_payload": "tcp_rx_dst_pkt_accept",
                 "payload": "tcp_rx_dst_payload_entry",
                 "rdy": "dst_tcp_rx_hdr_rdy"})
        self.buf_cpy_out_op = GenericValRdySink(self.buf_cpy_out_bus, dut.clk)

        self.buf_cpy_commit_wr_bus = GenericValRdyBus(dut,
                {"val": "store_buf_commit_ptr_wr_req_val",
                 "addr": "store_buf_commit_ptr_wr_req_addr",
                 "data": "store_buf_commit_ptr_wr_req_data",
                 "rdy": "commit_ptr_store_buf_wr_req_rdy"})
        self.buf_cpy_commit_wr_op = GenericValRdySource(self.buf_cpy_commit_wr_bus, dut.clk)

        self.buf_cpy_commit_rd_req_bus = GenericValRdyBus(dut,
                {"val": "store_buf_commit_ptr_rd_req_val",
                 "addr": "store_buf_commit_ptr_rd_req_addr",
                 "rdy": "commit_ptr_store_buf_rd_req_rdy"})
        self.buf_cpy_commit_rd_req_op = GenericValRdySource(self.buf_cpy_commit_rd_req_bus, dut.clk)

        self.buf_cpy_commit_rd_resp_bus = GenericValRdyBus(dut,
                {"val": "commit_ptr_store_buf_rd_resp_val",
                 "data": "commit_ptr_store_buf_rd_resp_data",
                 "rdy": "store_buf_commit_ptr_rd_resp_rdy"})
        self.buf_cpy_commit_rd_resp_op = GenericValRdySink(self.buf_cpy_commit_rd_resp_bus, dut.clk)

        self.flow_notif_bus = GenericValRdyBus(dut,
                {"val": "app_new_flow_notif_val",
                 "flowid": "app_new_flow_flowid",
                 "flow_entry": "app_new_flow_entry",
                 "rdy": "app_new_flow_notif_rdy"})
        self.flow_notif_op = GenericValRdySink(self.flow_notif_bus, dut.clk)

        self.rx_head_wr_bus = GenericValRdyBus(dut,
                {"val": "app_rx_head_ptr_wr_req_val",
                 "addr": "app_rx_head_ptr_wr_req_addr",
                 "data": "app_rx_head_ptr_wr_req_data",
                 "rdy": "rx_head_ptr_app_wr_req_rdy"})
        self.rx_head_wr_op = GenericValRdySource(self.rx_head_wr_bus, dut.clk)
        self.rx_head_rd_req_bus = GenericValRdyBus(dut,
                {"val": "app_rx_head_ptr_rd_req_val",
                 "addr": "app_rx_head_ptr_rd_req_addr",
                 "rdy": "rx_head_ptr_app_rd_req_rdy"})
        self.rx_head_rd_req_op = GenericValRdySource(self.rx_head_rd_req_bus,
                dut.clk)
        self.rx_head_rd_resp_bus = GenericValRdyBus(dut,
                {"val": "rx_head_ptr_app_rd_resp_val",
                 "data": "rx_head_ptr_app_rd_resp_data",
                 "rdy": "app_rx_head_ptr_rd_resp_rdy"})
        self.rx_head_rd_resp_op = GenericValRdySink(self.rx_head_rd_resp_bus,
                dut.clk)

        self.rx_commit_rd_req_bus = GenericValRdyBus(dut,
                {"val": "app_rx_commit_ptr_rd_req_val",
                 "addr": "app_rx_commit_ptr_rd_req_addr",
                 "rdy": "rx_commit_ptr_app_rd_req_rdy"})
        self.rx_commit_rd_req_op = GenericValRdySource(self.rx_commit_rd_req_bus,
                dut.clk)
        self.rx_commit_rd_resp_bus = GenericValRdyBus(dut,
                {"val": "rx_commit_ptr_app_rd_resp_val",
                 "data": "rx_commit_ptr_app_rd_resp_data",
                 "rdy": "app_rx_commit_ptr_rd_resp_rdy"})
        self.rx_commit_rd_resp_op = GenericValRdySink(self.rx_commit_rd_resp_bus,
                dut.clk)

        self.tx_head_rd_req_bus = GenericValRdyBus(dut,
                {"val": "app_tx_head_ptr_rd_req_val",
                 "addr": "app_tx_head_ptr_rd_req_addr",
                 "rdy": "tx_head_ptr_app_rd_req_rdy"})
        self.tx_head_rd_req_op = GenericValRdySource(self.tx_head_rd_req_bus,
                dut.clk)
        self.tx_head_rd_resp_bus = GenericValRdyBus(dut,
                {"val": "tx_head_ptr_app_rd_resp_val",
                 "data": "tx_head_ptr_app_rd_resp_data",
                 "rdy": "app_tx_head_ptr_rd_resp_rdy"})
        self.tx_head_rd_resp_op = GenericValRdySink(self.tx_head_rd_resp_bus,
                dut.clk)

        self.tx_tail_rd_req_bus = GenericValRdyBus(dut,
                {"val": "app_tx_tail_ptr_rd_req_val",
                 "addr": "app_tx_tail_ptr_rd_req_addr",
                 "rdy": "tx_tail_ptr_app_rd_req_rdy"})
        self.tx_tail_rd_req_op = GenericValRdySource(self.tx_tail_rd_req_bus,
                dut.clk)
        self.tx_tail_rd_resp_bus = GenericValRdyBus(dut,
                {"val": "tx_tail_ptr_app_rd_resp_val",
                 "data": "tx_tail_ptr_app_rd_resp_data",
                 "rdy": "app_tx_tail_ptr_rd_resp_rdy"})
        self.tx_tail_rd_resp_op = GenericValRdySink(self.tx_tail_rd_resp_bus,
                dut.clk)
        self.tx_tail_wr_bus = GenericValRdyBus(dut,
                {"val": "app_tx_tail_ptr_wr_req_val",
                 "addr": "app_tx_tail_ptr_wr_req_addr",
                 "data": "app_tx_tail_ptr_wr_req_data",
                 "rdy": "tx_tail_ptr_app_wr_req_rdy"})
        self.tx_tail_wr_op = GenericValRdySource(self.tx_tail_wr_bus, dut.clk)

        self.sched_update_bus = GenericValRdyBus(dut,
                {"val": "app_sched_update_val",
                 "cmd": "app_sched_update_cmd",
                 "rdy": "sched_app_update_rdy"})
        self.sched_update_op = GenericValRdySource(self.sched_update_bus, dut.clk)

        self.rx_circ_bufs = []
        self.tx_circ_bufs = []

        for i in range(0, self.MAX_NUM_FLOWS):
            self.rx_circ_bufs.append(circBuf(self.CIRC_BUF_SIZE))
            self.tx_circ_bufs.append(circBuf(self.CIRC_BUF_SIZE))

        self.buf_cpy_obj = BufCopier(self.buf_cpy_out_op,
                self.buf_cpy_commit_wr_op, self.buf_cpy_commit_rd_req_op,
                self.buf_cpy_commit_rd_resp_op, self.done_event,
                self.rx_circ_bufs, self.tmp_buf)

        # These should be initialized by the app specific TB classes, because
        # they represent the client and FPGA sides of the application
        self.TCP_driver = None
        self.app_mimic = None

        self.input_op = SlowInputOp(self.rx_pkt_in_op, self.tmp_buf)
        self.output_op = SlowOutputOp(self.tx_pkt_out_op, self.tx_circ_bufs,
                self.IP_TO_MAC)



def init_signals(dut):
    # set initial values
    dut.src_tcp_rx_hdr_val.setimmediatevalue(0)
    dut.src_tcp_rx_src_ip.setimmediatevalue(0)
    dut.src_tcp_rx_dst_ip.setimmediatevalue(0)
    dut.src_tcp_rx_tcp_hdr.setimmediatevalue(0)
    dut.src_tcp_rx_payload_entry.setimmediatevalue(0)

    dut.tx_pkt_hdr_rdy.setimmediatevalue(0)

    dut.store_buf_commit_ptr_wr_req_val.setimmediatevalue(0)
    dut.store_buf_commit_ptr_wr_req_addr.setimmediatevalue(0)
    dut.store_buf_commit_ptr_wr_req_data.setimmediatevalue(0)

    dut.store_buf_commit_ptr_rd_req_val.setimmediatevalue(0)
    dut.store_buf_commit_ptr_rd_req_addr.setimmediatevalue(0)

    dut.store_buf_commit_ptr_rd_resp_rdy.setimmediatevalue(0)

    dut.app_new_flow_notif_rdy.setimmediatevalue(0)

    dut.app_rx_head_ptr_wr_req_val.setimmediatevalue(0)
    dut.app_rx_head_ptr_wr_req_addr.setimmediatevalue(0)
    dut.app_rx_head_ptr_wr_req_data.setimmediatevalue(0)

    dut.app_rx_head_ptr_rd_req_val.setimmediatevalue(0)
    dut.app_rx_head_ptr_rd_req_addr.setimmediatevalue(0)
    dut.app_rx_head_ptr_rd_resp_rdy.setimmediatevalue(0)
    dut.app_rx_commit_ptr_rd_req_val.setimmediatevalue(0)
    dut.app_rx_commit_ptr_rd_req_addr.setimmediatevalue(0)
    dut.app_rx_commit_ptr_rd_resp_rdy.setimmediatevalue(0)

    dut.app_tx_head_ptr_rd_req_val.setimmediatevalue(0)
    dut.app_tx_head_ptr_rd_req_addr.setimmediatevalue(0)
    dut.tx_head_ptr_app_rd_req_rdy.setimmediatevalue(0)

    dut.tx_head_ptr_app_rd_resp_val.setimmediatevalue(0)
    dut.tx_head_ptr_app_rd_resp_addr.setimmediatevalue(0)
    dut.tx_head_ptr_app_rd_resp_data.setimmediatevalue(0)
    dut.app_tx_head_ptr_rd_resp_rdy.setimmediatevalue(0)

    dut.app_tx_tail_ptr_wr_req_val.setimmediatevalue(0)
    dut.app_tx_tail_ptr_wr_req_addr.setimmediatevalue(0)
    dut.app_tx_tail_ptr_wr_req_data.setimmediatevalue(0)
    dut.tx_tail_ptr_app_wr_req_rdy.setimmediatevalue(0)

    dut.app_sched_update_val.setimmediatevalue(0)
    dut.app_sched_update_cmd.setimmediatevalue(0)
    dut.sched_app_update_rdy.setimmediatevalue(0)

    dut.app_tx_tail_ptr_rd_req_val.setimmediatevalue(0)
    dut.app_tx_tail_ptr_rd_req_addr.setimmediatevalue(0)
    dut.tx_tail_ptr_app_rd_req_rdy.setimmediatevalue(0)

    dut.tx_tail_ptr_app_rd_resp_val.setimmediatevalue(0)
    dut.tx_tail_ptr_app_rd_resp_flowid.setimmediatevalue(0)
    dut.tx_tail_ptr_app_rd_resp_data.setimmediatevalue(0)
    dut.app_tx_tail_ptr_rd_resp_rdy.setimmediatevalue(0)


class SlowInputOp(BeehiveBusSource):
    def __init__(self, input_op, rx_tmp_buf):
        self.input_op = input_op
        self.tmp_buf = rx_tmp_buf

    async def xmit_frame(self, input_buf):
            # get just the TCP portion
            input_pkt = Ether(input_buf)
            cocotb.log.info(f"Input packet is {input_pkt.show(dump=True)}")

            tcp_hdr = input_pkt["TCP"].copy()
            tcp_hdr.remove_payload()

            payload_struct = PayloadBufStruct(addr=0, size=0)
            if "Raw" in input_pkt:
                payload = input_pkt["Raw"].load
                # wait until we have somewhere to put the payload
                (avail, slab_index) = self.tmp_buf.get_slab()
                while not avail:
                    await RisingEdge(dut.clk)
                    (avail, slab_index) = self.tmp_buf.get_slab()

                self.tmp_buf.write_slab(slab_index, payload)
                payload_struct.setField("addr", slab_index)
                payload_struct.setField("size", len(payload))

            tcp_hdr_bytes = bytes(tcp_hdr.build())
            payload_struct_bytes = payload_struct.toBinaryValue()
            src_ip = socket.inet_aton(input_pkt["IP"].src)
            dst_ip = socket.inet_aton(input_pkt["IP"].dst)

            await self.input_op.send_req(
                    {"src_ip": BinaryValue(value=src_ip, n_bits=32),
                     "dst_ip": BinaryValue(value=dst_ip, n_bits=32),
                     "tcp_hdr": BinaryValue(value=tcp_hdr_bytes),
                     "payload": payload_struct_bytes})

class SlowOutputOp(BeehiveBusSink):
    def __init__(self, output_op, tx_circ_bufs, ip_to_mac):
        self.output_op = output_op
        self.circ_bufs = tx_circ_bufs
        self.ip_to_mac = ip_to_mac

    async def recv_resp(self, pause_len=0):
        tx_pkt_out = await self.output_op.recv_resp()

        tcp_pkt_bytes = bytearray(tx_pkt_out["tcp_hdr"].buff)
        src_ip = socket.inet_ntoa(tx_pkt_out["src_ip"].buff)
        dst_ip = socket.inet_ntoa(tx_pkt_out["dst_ip"].buff)
        # go and find the payload
        payload_des = PayloadBufStruct(init_bitstring=tx_pkt_out["payload"])
        cocotb.log.info(f"Received payload entry is {payload_des}")
        payload_addr = payload_des.getBitfield("addr")
        addr = payloadPtrBitfield("addr", init_bitfield=payload_addr).to_addr()
        size = payload_des.getField("size")
        flowid = tx_pkt_out["flowid"]
        recv_buf = self.circ_bufs[flowid].read_from(addr, size)
        cocotb.log.info(f"Received buffer is {recv_buf}")
        tcp_pkt_bytes.extend(recv_buf)

        pkt = self.reassemble_pkt(src_ip, dst_ip, tcp_pkt_bytes)

        return pkt.build()

    async def recv_frame(self, pause_len = 0):
        return await self.recv_resp(pause_len = pause_len)

    def reassemble_pkt(self, src_ip, dst_ip, tcp_pkt_bytes):
        eth_hdr = Ether()
        eth_hdr.src = self.ip_to_mac[src_ip]
        eth_hdr.dst = self.ip_to_mac[dst_ip]

        ip_pkt = IP()
        ip_pkt.src = src_ip
        ip_pkt.dst = dst_ip
        ip_pkt.flags = "DF"
        ip_pkt.proto = 6
        ip_pkt.add_payload(bytes(tcp_pkt_bytes))

        pkt = eth_hdr/ip_pkt
        return pkt


