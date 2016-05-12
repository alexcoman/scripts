"""The commands used by the client actions."""

import os
import sys
import shutil
import platform

from argusvm.worker import base as worker_base


class SetupEnvironment(worker_base.Command):

    """Command used for installing the global requirements."""

    def __init__(self, executor):
        super(SetupEnvironment, self).__init__(executor=executor)
        self._routes = {
            "win32": {"default": None},
            "linux2": {"default": "_ubuntu_14_04"},
        }

    def _ubuntu_14_04(self):
        """Install dependences for Argus-Ci on Ubuntu 14.04."""
        self._execute(["sudo", "apt-get", "install", "-y", "build-essential",
                       "git", "python-dev", "libffi-dev", "libssl-dev"])
        self._execute(["sudo", "apt-get", "install", "-y", "python-pip"])
        self._execute(["sudo", "pip", "install", "virtualenv"])

    def _work(self):
        """Install dependences for Argus-Ci."""
        distributions = self._routes.get(sys.platform, {})
        method = getattr(self, distributions.get(platform.dist(), "default"),
                         None)
        if not method:
            self.logger.warning("SetupEnvironment not available on %r - %r",
                                sys.platform, platform.dist())
        else:
            method()


class CreateEnvironment(worker_base.Command):

    """Command used for creating virtual environment for Argus-CI."""

    def _work(self):
        """Create the virtual environment for Argus-Ci and Tempest."""
        if not self._setup_venv:
            return

        if os.path.isdir(self._venv):
            self.logger.warning("The virtual environment already exists. %s",
                                self._venv)
        else:
            self._execute(["sudo", "-u", self.args.user, "virtualenv",
                           self._venv, "--python", "/usr/bin/python2.7"])

    def _epilogue(self):
        """Executed once after the command running."""
        if self._setup_venv:
            self._execute(["sudo", "-u", self.args.user,
                           self._pip, "install", "pip", "--upgrade"])


class InstallTempest(worker_base.Command):

    """Command used for installing tempest and its requirements."""

    REPO = 'https://github.com/openstack/tempest.git'

    def __init__(self, executor):
        super(InstallTempest, self).__init__(executor=executor)
        self._clone_path = "/tmp/tempest"

    def _prologue(self):
        """Executed once before the command running."""
        super(InstallTempest, self)._prologue()
        branch = self._executor.config.get('tempest_branch')

        if os.path.isdir(self._clone_path):
            self.logger.info("Removing the directory %r", self._clone_path)
            shutil.rmtree(self._clone_path)

        self._execute(["sudo", "-u", self.args.user, "git", "clone",
                       self.REPO, os.path.basename(self._clone_path)],
                      cwd=os.path.dirname(self._clone_path))
        self._execute(["sudo", "-u", self.args.user, "git", "checkout",
                       branch],
                      cwd=self._clone_path)

    def _work(self):
        """Install the tempest package and its requirements."""
        self._execute(["sudo", "-u", self.args.user, self._pip, "install",
                       "-r", "requirements.txt"], cwd=self._clone_path)
        self._execute(["sudo", "-u", self.args.user, self._pip, "install",
                       "-r", "test-requirements.txt"], cwd=self._clone_path)
        self._execute(["sudo", "-u", self.args.user, self._python,
                       "setup.py", "install"], cwd=self._clone_path)

    def _epilogue(self):
        """Executed once after the command running."""
        self._execute(["sudo", "-u", self.args.user, self._python,
                       "-c", "import tempest"])
        # TODO(alexandrucoman): Create the config file


class InstallArgusCi(worker_base.Command):

    """Command used for installing argus-ci and its requirements."""

    REPO = 'https://github.com/cloudbase/cloudbase-init-ci'

    def __init__(self, executor):
        super(InstallArgusCi, self).__init__(executor=executor)
        self._clone_path = "/tmp/argus"

    def _prologue(self):
        """Executed once before the command running."""
        super(InstallArgusCi, self)._prologue()
        branch = self._executor.config.get('argus_branch')

        if os.path.isdir(self._clone_path):
            self.logger.info("Removing the directory %r", self._clone_path)
            shutil.rmtree(self._clone_path)

        self._execute(["sudo", "-u", self.args.user, "git", "clone",
                       self.REPO, self._clone_path])
        self._execute(["sudo", "-u", self.args.user, "git", "checkout",
                       branch], cwd=self._clone_path)

    def _work(self):
        """Install the argus-ci framework and its requirements."""
        self._execute(["sudo", "-u", self.args.user, self._pip, "install",
                       "-r", "requirements.txt"], cwd=self._clone_path)
        self._execute(["sudo", "-u", self.args.user, self._python, "setup.py",
                       "install"], cwd=self._clone_path)

    def _epilogue(self):
        """Executed once after the command running."""
        self._execute(["sudo", "-u", self.args.user, self._python,
                       "-c", "import argus"])
        # TODO(alexandrucoman): Create the config file
        super(InstallArgusCi, self)._epilogue()
