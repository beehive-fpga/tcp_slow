import logging
import cocotb
from cocotb.triggers import Event, RisingEdge, Combine, with_timeout
from cocotb.result import SimTimeoutError
from cocotb.binary import BinaryValue
from cocotb.log import SimLog
from collections import deque

import sys
import os
sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common/")
from tcp_automaton_driver import TCPAutomatonDriver, EchoGenerator
from bitfields import bitfield, bitfieldManip

from generic_val_rdy import GenericValRdyBus, GenericValRdySource, GenericValRdySink
from bitfields import bitfield, bitfieldManip

class BufCopier():
    def __init__(self, hdr_op, commit_wr_op, commit_rd_req_op,
            commit_rd_resp_op, done_event, rx_circ_bufs, tmp_buf):
        self.hdr_op = hdr_op
        self.commit_wr_op = commit_wr_op
        self.commit_rd_req_op = commit_rd_req_op
        self.commit_rd_resp_op = commit_rd_resp_op
        self.ptr_w = self.commit_wr_op._bus.data.value.n_bits
        self.trunc_ptr = bitfield("commit_ptr", self.ptr_w, trunc_value = True)
        self.done_event = done_event
        self.rx_circ_bufs = rx_circ_bufs
        self.tmp_buf = tmp_buf

    async def req_loop(self):
        while not self.done_event.is_set():
            copy_req = None
            # try to wait for a response
            try:
                resp_coro = cocotb.start_soon(self.hdr_op.recv_resp())
                copy_req = await with_timeout(resp_coro,
                        2000, timeout_unit="ns")
            # if we don't get a response, continue, so we check done_event
            except SimTimeoutError:
                continue
            payload_entry = PayloadBufStruct(init_bitstring=copy_req["payload"])
            payload_size = payload_entry.getField("size")
            if payload_size != 0:
                if copy_req["accept_payload"]:

                    # figure out what the commit pointer is
                    await self.commit_rd_req_op.send_req(
                            {"addr": copy_req["flowid"]})
                    commit_ptr_dict = await self.commit_rd_resp_op.recv_resp()
                    commit_ptr_binval = commit_ptr_dict["data"]
                    commit_ptr = payloadPtrBitfield("commit_ptr",
                            size=commit_ptr_binval.n_bits,
                            value=commit_ptr_binval.integer)

                    # get the data from the tmp buf and write the data in
                    data = self.tmp_buf.read_slab(payload_entry.getField("addr"))
                    self.rx_circ_bufs[copy_req["flowid"]].write_from(commit_ptr.to_addr(), data)
                    #cocotb.log.info(f"Writing to addr {commit_ptr.to_addr()}: {data}")

                    new_ptr = commit_ptr.value + payload_entry.getField("size")

                    # truncate the new_ptr to the correct width
                    self.trunc_ptr.set_value(new_ptr)
                    ptr_bitstr = self.trunc_ptr.bitfield_format()
                    await self.commit_wr_op.send_req(
                            {"addr": copy_req["flowid"],
                             "data": BinaryValue(n_bits = self.ptr_w, value=ptr_bitstr)})

                    # free the buffer
                    self.tmp_buf.free_slab(payload_entry.getField("addr"))

        cocotb.log.info("Copier loop exiting")

class TmpBufMimic():
    def __init__(self, size):
        self.max_size = size
        self.data = [None] * self.max_size
        self.free_slabs = deque()
        self.free_index = 0
        self.use_queue = False

    def get_slab(self):
        if self.use_queue:
            if len(self.free_slabs) != 0:
                return (True, self.free_slabs.popleft())
            else:
                return (False, -1)
        else:
            index = self.free_index
            self.free_index += 1
            if self.free_index == self.max_size:
                self.use_queue = True
            return (True, index)

    def free_slab(self, index):
        self.free_slabs.append(index)

    def write_slab(self, index, data_buf):
        self.data[index] = data_buf

    def read_slab(self, index):
        return self.data[index]

class AppIFMimic():
    def __init__(self, flow_notif_op, sched_update_op,
            rx_head_wr_op, rx_head_rd_req_op, rx_head_rd_resp_op,
            rx_commit_rd_req_op, rx_commit_rd_resp_op,
            tx_head_rd_req_op, tx_head_rd_resp_op,
            tx_tail_wr_op, tx_tail_rd_req_op, tx_tail_rd_resp_op):

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

class HWEchoMimic(AppIFMimic):
    def __init__(self, clk, done_event, rx_circ_bufs, tx_circ_bufs,
            client_len_bytes, hdr_bytes,
            flow_notif_op, sched_update_op,
            rx_head_wr_op, rx_head_rd_req_op, rx_head_rd_resp_op,
            rx_commit_rd_req_op, rx_commit_rd_resp_op,
            tx_head_rd_req_op, tx_head_rd_resp_op,
            tx_tail_wr_op, tx_tail_rd_req_op, tx_tail_rd_resp_op):
        # order matters here, we need the parent class to set up the instance
        # variables
        super().__init__(flow_notif_op, sched_update_op,
            rx_head_wr_op, rx_head_rd_req_op, rx_head_rd_resp_op,
            rx_commit_rd_req_op, rx_commit_rd_resp_op,
            tx_head_rd_req_op, tx_head_rd_resp_op,
            tx_tail_wr_op, tx_tail_rd_req_op, tx_tail_rd_resp_op)

        self.done_event = done_event
        self.clk = clk
        self.active_flows = deque()
        self.client_len_bytes = client_len_bytes
        self.hdr_bytes = hdr_bytes
        self.rx_circ_bufs = rx_circ_bufs
        self.tx_circ_bufs = tx_circ_bufs

        self.rx_head_ptr_bitfield = payloadPtrBitfield("rx_head_ptr",
                size=self.rx_head_rd_resp_op._bus.data.value.n_bits)
        self.rx_commit_ptr_bitfield = payloadPtrBitfield("rx_commit_ptr",
                size=self.rx_commit_rd_resp_op._bus.data.value.n_bits)
        self.tx_head_ptr_bitfield = payloadPtrBitfield("tx_head_ptr",
                size=self.tx_head_rd_resp_op._bus.data.value.n_bits)
        self.tx_tail_ptr_bitfield = payloadPtrBitfield("tx_tail_ptr",
                size=self.tx_tail_rd_resp_op._bus.data.value.n_bits)


    async def flow_notif(self):
        cocotb.log.info("Started flow notif coroutine")
        while not self.done_event.is_set():
            flow_notif_data = None;
            try:
                resp_coro = cocotb.start_soon(self.flow_notif_op.recv_resp())
                flow_notif_data = await with_timeout(resp_coro,
                        2000, timeout_unit="ns")
            except SimTimeoutError:
                continue
            self.active_flows.append(flow_notif_data)
            cocotb.log.info("Got new flow")
        cocotb.log.info("Flow notif coroutine exiting")

    async def parallel_rd_resp(self, op, value_event):
        data = await op.recv_resp()
        value_event.set(data)

    async def get_space_used(self, flowid):
        # go read the head and commit pointers at the same time
        hd_rd_req = cocotb.start_soon(self.rx_head_rd_req_op.send_req(
            {"addr": flowid}))
        commit_rd_req = cocotb.start_soon(self.rx_commit_rd_req_op.send_req(
            {"addr": flowid}))
        await Combine(hd_rd_req, commit_rd_req)

        hd_event = Event()
        commit_event = Event()
        hd_rd_resp = cocotb.start_soon(self.parallel_rd_resp(self.rx_head_rd_resp_op,
            hd_event))
        commit_rd_resp = cocotb.start_soon(self.parallel_rd_resp(self.rx_commit_rd_resp_op,
            commit_event))
        await Combine(hd_rd_resp, commit_rd_resp)

        self.rx_head_ptr_bitfield.set_value(hd_event.data["data"].integer)
        self.rx_commit_ptr_bitfield.set_value(commit_event.data["data"].integer)
        space_used = self.rx_commit_ptr_bitfield.sub(self.rx_head_ptr_bitfield)

        return space_used

    async def get_space_avail(self, flowid):
        hd_rd_req = cocotb.start_soon(self.tx_head_rd_req_op.send_req(
            {"addr": flowid}))
        tail_rd_req = cocotb.start_soon(self.tx_tail_rd_req_op.send_req(
            {"addr": flowid}))

        await Combine(hd_rd_req, tail_rd_req)

        hd_event = Event()
        tail_event = Event()
        hd_rd_resp = cocotb.start_soon(self.parallel_rd_resp(self.tx_head_rd_resp_op,
            hd_event))
        tail_rd_resp = cocotb.start_soon(self.parallel_rd_resp(self.tx_tail_rd_resp_op,
            tail_event))
        await Combine(hd_rd_resp, tail_rd_resp)

        self.tx_head_ptr_bitfield.set_value(hd_event.data["data"].integer)
        self.tx_tail_ptr_bitfield.set_value(tail_event.data["data"].integer)

        space_used = self.tx_tail_ptr_bitfield.sub(self.tx_head_ptr_bitfield)

        max_val = 1 << self.tx_head_ptr_bitfield.num_ptr_w
        space_avail = max_val - space_used

        return space_avail

    async def app_loop(self):
        while not self.done_event.is_set():
            if len(self.active_flows) != 0:
                flow_data = self.active_flows.popleft()
                flowid = flow_data["flowid"]

                space_used = 0
                while space_used < self.hdr_bytes:
                    space_used = await self.get_space_used(flowid)

                hdr_data = self.rx_circ_bufs[flowid].read_from(self.rx_head_ptr_bitfield.to_addr(),
                        self.hdr_bytes)
                cocotb.log.info(f"hdr bytes from "
                        f"{self.rx_head_ptr_bitfield.to_addr()}: {hdr_data}")

                rd_len = int.from_bytes(hdr_data[0:self.client_len_bytes],
                        byteorder="big")
                resp_len = int.from_bytes(hdr_data[self.client_len_bytes:self.client_len_bytes*2],
                        byteorder="big")
                is_done = hdr_data[self.client_len_bytes*2]

                cocotb.log.info(f"Got app header. req_len: {rd_len}, resp_len: "
                        f"{resp_len}")

                # alright now wait for the payload
                total_req_len = self.hdr_bytes + rd_len
                while space_used < total_req_len:
                    space_used = await self.get_space_used(flowid)
                cocotb.log.info("Got whole req")

                # everything is here! time to send the response
                # check if there's space available in the tx buffers
                space_avail = 0
                while space_avail < resp_len:
                    space_avail = await self.get_space_avail(flowid)

                buf = bytearray([(i % 32) + 65 for i in range(0, resp_len)])
                # okay there is, so copy in
                self.tx_circ_bufs[flowid].write_from(self.tx_tail_ptr_bitfield.to_addr(),
                        buf)
                # kick the tail pointer. we need to use value rather than
                # to_addr, because we need all the bits
                new_tail_ptr = self.tx_tail_ptr_bitfield.value + resp_len
                self.tx_tail_ptr_bitfield.set_value(new_tail_ptr)
                new_tail_binval = BinaryValue(value=self.tx_tail_ptr_bitfield.bitfield_format(),
                        n_bits = self.tx_tail_ptr_bitfield.size)
                await self.tx_tail_wr_op.send_req(
                        {"addr": flowid,
                         "data": new_tail_binval})

                # kick the head pointer to consume the request too
                new_head_ptr = self.rx_head_ptr_bitfield.value + total_req_len
                self.rx_head_ptr_bitfield.set_value(new_head_ptr)
                new_head_binval = BinaryValue(value=self.rx_head_ptr_bitfield.bitfield_format(),
                        n_bits=self.rx_head_ptr_bitfield.size)
                await self.rx_head_wr_op.send_req(
                        {"addr": flowid,
                         "data": new_head_binval})

                # kick the scheduler
                sched_cmd = SchedCmdStruct(flowid=flowid.integer,
                                            rt_cmd=SchedCmdStruct.NOP,
                                            ack_cmd=SchedCmdStruct.NOP,
                                            data_cmd=SchedCmdStruct.SET)
                await self.sched_update_op.send_req({"cmd": sched_cmd.toBinaryValue()})

                # should we reenqueue the flow?
                if is_done == 0:
                    self.active_flows.append(flow_data)
                else:
                    cocotb.log.info("App mimic flow finished")
            else:
                await RisingEdge(self.clk)

        cocotb.log.info("App mimic exiting")


class circBuf():
    def __init__(self, size_bytes):
        self.size_bytes = size_bytes
        self.data = bytearray([0] * self.size_bytes)

    def write_from(self, addr, buf):
        if addr >= self.size_bytes:
            raise ValueError("Start address outside possible range")
        if len(buf) > self.size_bytes:
            raise ValueError("data larger than possible size of the buffer")
        for i in range(0, len(buf)):
            self.data[(addr + i) % self.size_bytes] = buf[i]

    def read_from(self, addr, length):
        if addr >= self.size_bytes:
            raise ValueError("Start address outside possible range")
        if length > self.size_bytes:
            raise ValueError("requested data larger than possible size of the buffer")
        ret_buf = bytearray([0] * length)

        for i in range(0, length):
            ret_buf[i] = self.data[(addr + i) % self.size_bytes]

        return ret_buf

class payloadPtrBitfield(bitfield):
    def __init__(self, name, size=None, value=0, init_bitfield=None):
        init_size = size
        init_name = name
        init_value = value

        if init_bitfield is not None:
            init_size = init_bitfield.size
            init_name = init_bitfield.name
            init_value = init_bitfield.value

        self.num_ptr_w = init_size - 1
        super().__init__(init_name, init_size, value=init_value,
                trunc_value=True)

    """
    Subtraction that mimics the Verilog semantics w.r.t.
    wrapping/overflow
    """
    def sub(self, other):
        if other.value > self.value:
            max_val = 1 << self.num_ptr_w
            diff = other.value - self.value
            return max_val - diff
        else:
            return self.value - other.value

    def to_addr(self):
        formatted = self.bitfield_format()
        num_val = formatted[-self.num_ptr_w:]
        return int(num_val, 2)


class TCPSlowTB():
    def __init__(self, dut):
        # setup all the buses
        init_signals(dut)
        self.done_event = Event()
        self.CLOCK_CYCLE_TIME = 4
        self.MAX_NUM_FLOWS = 8
        self.CIRC_BUF_SIZE = 1 << 12
        self.CLIENT_LEN_BYTES = 2
        self.IP_TO_MAC = {
            "198.0.0.5": "b8:59:9f:b7:ba:44",
            "198.0.0.7": "00:0a:35:0d:4d:c6",
            "198.0.0.9": "b8:59:9f:b7:ba:44"
        }
        self.MAC_W = 512

        self.TCP_driver = TCPAutomatonDriver(1, EchoGenerator, (self.MAC_W,
            1024, 64, 2),
                dut.clk)

        self.log = SimLog("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        self.tmp_buf = TmpBufMimic(20)

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

        self.app_mimic = HWEchoMimic(dut.clk, self.done_event, self.rx_circ_bufs,
                self.tx_circ_bufs, self.CLIENT_LEN_BYTES, int(self.MAC_W/8),
                self.flow_notif_op, self.sched_update_op,
                self.rx_head_wr_op, self.rx_head_rd_req_op, self.rx_head_rd_resp_op,
                self.rx_commit_rd_req_op, self.rx_commit_rd_resp_op,
                self.tx_head_rd_req_op, self.tx_head_rd_resp_op,
                self.tx_tail_wr_op, self.tx_tail_rd_req_op, self.tx_tail_rd_resp_op)

        self.buf_cpy_obj = BufCopier(self.buf_cpy_out_op,
                self.buf_cpy_commit_wr_op, self.buf_cpy_commit_rd_req_op,
                self.buf_cpy_commit_rd_resp_op, self.done_event,
                self.rx_circ_bufs, self.tmp_buf)


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

    FLOWID_W = 3
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

