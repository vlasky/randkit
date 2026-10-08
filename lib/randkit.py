"""Shared runtime for randkit's Python tools.

Tools load this with

    sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "lib"))
    from randkit import uniform, cli_setup

so the one correctness-critical uniform construction lives in exactly one
place.
"""
import os
import signal
import struct


def _unit(u):
    """Map a 64-bit random integer to a float strictly inside (0, 1).

    (top 52 bits + 0.5) / 2^52 is exact in double arithmetic: the 52 integer
    bits plus the half fit in the 53-bit significand, so no rounding happens
    and the result can never be 0.0 or 1.0. (A 53-bit variant is NOT safe:
    (2^53 - 1) + 0.5 rounds up to 2^53, producing exactly 1.0.)
    """
    return ((u >> 12) + 0.5) * 2.0**-52


def uniform():
    """Uniform random float strictly inside (0, 1) from /dev/urandom."""
    return _unit(struct.unpack("Q", os.urandom(8))[0])


def uniforms(n, chunk=4096):
    """Yield n uniforms, reading entropy in chunks to amortise the syscall.

    Each value is constructed exactly as uniform() constructs it; only the
    read is batched. Samplers that burn one uniform per trial (binomial) are
    dominated by the per-call cost of os.urandom otherwise.
    """
    while n > 0:
        k = min(n, chunk)
        for u in struct.unpack(f"{k}Q", os.urandom(8 * k)):
            yield _unit(u)
        n -= k


def cli_setup():
    """Process-level setup shared by every tool; call first thing in main().

    Python ignores SIGPIPE at startup and surfaces a closed stdout as a
    BrokenPipeError traceback. The tools are pipeline filters (`uuid -c
    1000000 | head`), so restore the default disposition and die quietly like
    every other Unix filter. This is also correct in environments that ignore
    SIGPIPE for all processes (CI runners): SIG_DFL re-enables it for us.
    """
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
