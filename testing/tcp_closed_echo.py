import logging
import cocotb

from cocotb.result import SimTimeoutError
from cocotb.triggers import Event, RisingEdge, Combine, with_timeout
from cocotb.binary import BinaryValue

from tcp_slow_test_utils import AppIFMimic
from circ_buf_helpers import payloadPtrBitfield
from collections import deque
from tcp_slow_test_structs import SchedCmdStruct

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
        self.log.info("Started flow notif coroutine")
        while not self.done_event.is_set():
            flow_notif_data = None;
            try:
                resp_coro = cocotb.start_soon(self.flow_notif_op.recv_resp())
                flow_notif_data = await with_timeout(resp_coro,
                        2000, timeout_unit="ns")
            except SimTimeoutError:
                continue
            self.active_flows.append(flow_notif_data)
            self.log.info(f"Got new flow {flow_notif_data['flowid']}")
        self.log.info("Flow notif coroutine exiting")

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
                self.log.info(f"Beehive: app mimic scheduled flow {flowid}")

                space_used = 0
                while space_used < self.hdr_bytes:
                    space_used = await self.get_space_used(flowid)
                    self.log.info(f"Beehive: app RX space used: {space_used}")

                hdr_data = self.rx_circ_bufs[flowid].read_from(self.rx_head_ptr_bitfield.to_addr(),
                        self.hdr_bytes)
                self.log.info(f"hdr bytes from "
                        f"{self.rx_head_ptr_bitfield.to_addr()}: {hdr_data}")

                rd_len = int.from_bytes(hdr_data[0:self.client_len_bytes],
                        byteorder="big")
                resp_len = int.from_bytes(hdr_data[self.client_len_bytes:self.client_len_bytes*2],
                        byteorder="big")
                is_done = hdr_data[self.client_len_bytes*2]

                self.log.info(f"Got app header for flow {flowid}. req_len: {rd_len}, resp_len: "
                        f"{resp_len}")

                # alright now wait for the payload
                total_req_len = self.hdr_bytes + rd_len
                while space_used < total_req_len:
                    space_used = await self.get_space_used(flowid)
                self.log.info("Got whole req")

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
                    self.log.info(f"App mimic flow {flowid} finished")
            else:
                await RisingEdge(self.clk)

        self.log.info("App mimic exiting")

