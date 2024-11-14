import logging
import random
import collections
from pathlib import Path

import cocotb
from cocotb.queue import Queue as CocoQueue
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ReadOnly, Combine, First, Event
from cocotb.triggers import ClockCycles, with_timeout, Join
from cocotb.result import SimTimeoutError
from cocotb.log import SimLog
from cocotb.utils import get_sim_time
import scapy

from scapy.layers.l2 import Ether, ARP
from scapy.layers.inet import IP, UDP, TCP
from scapy.packet import Raw

import sys
import os
sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common/")

from tcp_driver import TCPFourTuple
from generic_val_rdy import GenericValRdyBus, GenericValRdySource, GenericValRdySink
from tcp_slow_test_structs import PayloadBufStruct
from tcp_slow_test_utils import reset
from circ_buf_helpers import payloadPtrBitfield
from tcp_open_bw_log_read import TCPOpenBwLogRead

import tcp_closed_loop_client
from tcp_closed_loop_client import TCPClosedLoopTB

import tcp_open_loop_client
from tcp_open_loop_client import TCPOpenLoopTB

from open_loop_generator import ClientDir

@cocotb.test()
async def run_tcp_test_closed_loop(dut):
    tb = TCPClosedLoopTB(dut, 1)
    cocotb.start_soon(Clock(dut.clk, tb.CLOCK_CYCLE_TIME, units='ns').start())

    await reset(dut)
    # start up all the hw mimic tasks
    app_flow_notif = cocotb.start_soon(tb.app_mimic.flow_notif())
    app_loop = cocotb.start_soon(tb.app_mimic.app_loop())
    buf_copy = cocotb.start_soon(tb.buf_cpy_obj.req_loop())

    # start the request generator
    req_gen_loop = tb.TCP_driver.run_req_gens()

    # start up the app tasks
    timers = CocoQueue()
    send_task = cocotb.start_soon(tcp_closed_loop_client.run_send_loop(dut, tb, timers))
    recv_task = cocotb.start_soon(tcp_closed_loop_client.run_recv_loop(dut, tb))
    timer_task = cocotb.start_soon(tcp_closed_loop_client.timer_tasks(tb, timers))

    await Combine(app_flow_notif, app_loop, buf_copy, send_task, recv_task,
            timer_task, req_gen_loop)

#@cocotb.test()
async def run_tcp_test_open_loop(dut):
    DIRECTION = ClientDir.SEND
    NUM_REQS = 100
    BUF_SIZE = 128
    NUM_CONNS = 1
    tb = TCPOpenLoopTB(dut, NUM_CONNS, DIRECTION, NUM_REQS, BUF_SIZE)
    cocotb.start_soon(Clock(dut.clk, tb.CLOCK_CYCLE_TIME, units='ns').start())
    await reset(dut)

    measures = await run_one_bw_test(tb, NUM_CONNS, DIRECTION, NUM_REQS,
            BUF_SIZE)

    ref_intervals = log_reader.calculate_bws(measures, tb.CLOCK_CYCLE_TIME)
    return ref_intervals
    cocotb.log.info(f"{measures}")

#@cocotb.test()
async def run_bw_tests(dut):
    DIRECTION = ClientDir.SEND
    NUM_REQS = 100
    BUF_SIZE = 8192
    NUM_CONNS = 1

    tb = TCPOpenLoopTB(dut, NUM_CONNS, DIRECTION, NUM_REQS, BUF_SIZE)
    cocotb.start_soon(Clock(dut.clk, tb.CLOCK_CYCLE_TIME, units='ns').start())
    await reset(dut)

    res_dir = Path(f"./bw_benchmark/{DIRECTION.name.lower()}/reqs_{NUM_REQS}/"
                   f"conns_{NUM_CONNS}/buf_{BUF_SIZE}")
    res_dir.mkdir(parents=True, exist_ok=True)

    measures = await run_one_bw_test(tb, NUM_CONNS, DIRECTION, NUM_REQS,
            BUF_SIZE)

    log_four_tuple = TCPFourTuple(our_ip = "198.0.0.5",
                                our_port = 55000,
                                their_ip = "198.0.0.7",
                                their_port = 60000)
    log_reader = TCPOpenBwLogRead(8, 2, tb, log_four_tuple)
    log_reader.entries_to_csv(f"{str(res_dir)}/bw_log.csv", measures)


async def run_one_bw_test(tb, num_conns, direction, num_reqs, buf_size):
    hw_app_recv_stats = CocoQueue()
    # start up all the hw mimic tasks
    app_flow_notif = cocotb.start_soon(tb.app_mimic.flow_notif())
    app_loop = cocotb.start_soon(tb.app_mimic.app_loop(hw_app_recv_stats))
    buf_copy = cocotb.start_soon(tb.buf_cpy_obj.req_loop())

    # start up the app tasks
    sw_app_recv_stats = CocoQueue()
    send_task = cocotb.start_soon(tcp_open_loop_client.run_send_loop(tb))
    recv_task = cocotb.start_soon(tcp_open_loop_client.run_recv_loop(tb,
        sw_app_recv_stats))
    timer_task = cocotb.start_soon(tcp_open_loop_client.timer_tasks(tb))

    await Combine(app_flow_notif, app_loop, buf_copy, send_task, recv_task,
            timer_task)

    pkt_times = []
    if direction == ClientDir.SEND:
        pkt_times = hw_app_recv_stats.get_nowait()
    else:
        pkt_times = sw_app_recv_stats.get_nowait()
    return pkt_times

