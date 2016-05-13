"""The commands used by the command line parser."""

import os

from argusvm.client import base as client_base
from argusvm.worker import command


class InstallArgusCi(client_base.Command):

    """Install the Argus-CI on the current machine."""

    def setup(self):
        """Extend the parser configuration in order to expose all
        the received commands.
        """
        parser = self._parser.add_parser(
            "install",
            help="Install the Argus-CI on the current machine.")

        parser.add_argument("--user", dest="user", default="root",
                            help="Run the commands as specified user.")

        parser.add_argument(
            "--argus-branch", dest="argus_branch",
            default=os.environ.get("ARGUS_BRANCH", "master"),
            help="the required branch / revision of argus repository "
                 "(Default: master)")
        parser.add_argument(
            "--tempest-branch", dest="tempest_branch",
            default=os.environ.get("TEMPEST_BRANCH", "tags/7"),
            help="the required branch / revision of argus repository "
                 "(Default: tags/7)")

        group = parser.add_mutually_exclusive_group()
        group.add_argument(
            "--no-venv", dest="setup_venv", action="store_false",
            help="Install the requirements on the global environment")
        group.add_argument(
            "--venv", dest="venv", type=str,
            default=os.path.expanduser("~/argus-env"),
            help="The path for the virtual environment. "
                 "(Default: ~/argus-env)"
        )

        parser.set_defaults(work=self.run)

    def _work(self):
        """Install the Argus-CI on the current machine."""
        tasks = (
            # Install all the requirements for Argus-Ci
            command.SetupEnvironment,
            # Create the virtual environment for Argus-Ci
            command.CreateEnvironment,
            # Install Tempest and its requirements
            command.InstallTempest,
            # Install Arugs-Ci and its requirements
            command.InstallArgusCi
        )

        for task in tasks:
            task(self).run()
