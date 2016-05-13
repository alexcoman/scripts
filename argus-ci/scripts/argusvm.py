#! /usr/bin/env python
"""ArgusVM command line application."""

import argparse
import os
import sys

from argusvm.client import base as client_base
from argusvm.client import group


class ArgusClient(client_base.Application):

    """Command line application for deploying Argus-Ci."""

    commands = [
        (group.InstallArgusCi, "commands"),
    ]

    def setup(self):
        """Extend the parser configuration in order to expose all
        the received commands.
        """
        self._parser = argparse.ArgumentParser()
        self._parser.add_argument(
            "--attempts", dest="attempts", type=int,
            default=int(os.environ.get("ARGUS_ATTEMPTS", 3)),
            help="Interval between execute attempts, in seconds. "
                 "(Default: 3)")
        self._parser.add_argument(
            "--retry_interval", dest="retry_interval", type=float,
            default=float(os.environ.get("ARGUS_RETRY_INTERVAL", 0.1)),
            help="How many times to retry running the command. "
                 "(Default: 0.1)")

        group = self._parser.add_mutually_exclusive_group()
        group.add_argument("-v", "--verbose", action="store_true",
                           default=False)
        group.add_argument("-q", "--quiet", action="store_true",
                           default=False)

        commands = self._parser.add_subparsers(title="[commands]",
                                               dest="command")

        self._register_parser("commands", commands)


def main():
    """Run the Jarvis command line application."""
    if len(sys.argv) == 1:
        sys.argv.append("install")

    argusvm = ArgusClient(sys.argv[1:])
    argusvm.run()


if __name__ == "__main__":
    main()
