#!/usr/bin/env python
"""Install the Argus-CI project on the current machine."""

import abc
import argparse
import os
import subprocess
import time
import threading

import six


@six.add_metaclass(abc.ABCMeta)
class Worker(object):

    """Contract class for all the commands and clients."""

    def _prologue(self):
        """Executed once before the command running."""
        pass

    @abc.abstractmethod
    def _work(self):
        """Override this with your desired procedures."""
        pass

    def _epilogue(self):
        """Executed once after the command running."""
        pass

    def run(self):
        """Run the command."""
        result = None
        self._prologue()
        result = self._work()
        self._epilogue()
        return result


@six.add_metaclass(abc.ABCMeta)
class Task(Worker):

    """Contract class for all the commands and clients."""

    def __init__(self, executor=None):
        super(Task, self).__init__()
        self._executor = executor

    def task_done(self, result):
        """What to execute after successfully finished processing a task."""
        callback = getattr(self._executor, "on_task_done")
        if callback:
            callback(self, result)

    def task_fail(self, exc):
        """What to do when the program fails processing a task."""
        callback = getattr(self._executor, "on_task_fail")
        if callback:
            callback(self, exc)

    def run(self):
        """Run the command."""
        result = None
        self._prologue()
        try:
            result = self._work()
        except Exception as exc:
            self.task_fail(exc)
        else:
            self.task_done(result)
        self._epilogue()
        return result


@six.add_metaclass(abc.ABCMeta)
class Executor(Worker):

    """Contract class for all the executors."""

    def __init__(self, delay, loop):
        super(Executor, self).__init__()
        self._queue = []
        self._delay = delay
        self._loop = loop
        self._stop_event = threading.Event()

    @abc.abstractmethod
    def on_task_done(self, task, result):
        """What to execute after successfully finished processing a task."""
        pass

    @abc.abstractmethod
    def on_task_fail(self, task, exc):
        """What to do when the program fails processing a task."""
        pass

    @abc.abstractmethod
    def on_interrupted(self):
        """What to execute when keyboard interrupts arrive."""
        pass

    def _get_task(self):
        """Retrieves a task from the queue."""
        if self._queue:
            return self._queue.pop(0)

    def _work(self):
        """Run the received task and process the result."""
        # pylint: disable=broad-except
        task = self._get_task()
        if task and isinstance(task, Task):
            try:
                task.run()
            except Exception as exc:
                self.on_task_fail(task, exc)

    def put_task(self, task):
        """Adds a task to the tasks queue."""
        if not isinstance(task, Task):
            raise ValueError("Invalid type of task provided.")
        self._queue.append(task)

    def run(self):
        """Processes incoming tasks."""
        self._prologue()
        while not self._stop_event.is_set():
            try:
                self._work()
                if not self._loop:
                    break
            except KeyboardInterrupt:
                self.on_interrupted()
                break
        self._epilogue()


@six.add_metaclass(abc.ABCMeta)
class Command(Task):

    def __init__(self, executor):
        super(Command, self).__init__(executor)
        self._attemts, self._retry_interval = None, None
        self._venv, self._setup_venv = None, None
        self._python, self._pip = None, None

    def _prologue(self):
        """Executed once before the command running."""
        self._attemts = self._executor.config.get('attempts', 1)
        self._retry_interval = self._executor.config.get('retry_interval', 0)
        self._setup_venv = self._executor.config.get("setup_venv")
        self._venv = self._executor.config.get("venv")

        if self._setup_venv:
            self._python = os.path.join(self._venv, "bin", "python")
            self._pip = os.path.join(self._venv, "bin", "pip")
        else:
            self._python = "/usr/bin/python"
            self._pip = "/usr/local/bin/pip"

    def _execute(self, command, **kwargs):
        """Helper method to shell out and execute a command through subprocess.

        :param attempts:        How many times to retry running the command.
        :param binary:          On Python 3, return stdout and stderr as bytes
                                if binary is True, as Unicode otherwise.
        :param check_exit_code: Single bool, int, or list of allowed exit
                                codes.  Defaults to [0].  Raise
                                :class:`CalledProcessError` unless
                                program exits with one of these code.
        :param command:         The command passed to the subprocess.Popen.
        :param cwd:             Set the current working directory
        :param env_variables:   Environment variables and their values that
                                will be set for the process.
        :param retry_interval:  Interval between execute attempts, in seconds
        :param shell:           whether or not there should be a shell used to
                                execute this command.

        :raises:                :class:`subprocess.CalledProcessError`
        """
        # pylint: disable=too-many-locals

        attempts = kwargs.pop("attempts", self._attemts)
        binary = kwargs.pop('binary', False)
        check_exit_code = kwargs.pop('check_exit_code', [0])
        cwd = kwargs.pop('cwd', None)
        env_variables = kwargs.pop("env_variables", None)
        retry_interval = kwargs.pop("retry_interval", self._retry_interval)
        shell = kwargs.pop("shell", False)

        if cwd and not os.path.isdir(cwd):
            print("[w] Invalid value for cwd: {cwd}".format(cwd=cwd))
            cwd = None

        command = [str(argument) for argument in command]
        ignore_exit_code = False

        if isinstance(check_exit_code, bool):
            ignore_exit_code = not check_exit_code
            check_exit_code = [0]
        elif isinstance(check_exit_code, int):
            check_exit_code = [check_exit_code]

        while attempts > 0:
            attempts = attempts - 1
            try:
                process = subprocess.Popen(command,
                                           stdin=subprocess.PIPE,
                                           stdout=subprocess.PIPE,
                                           stderr=subprocess.PIPE, shell=shell,
                                           cwd=cwd, env=env_variables)
                result = process.communicate()
                return_code = process.returncode

                if six.PY3 and not binary and result is not None:
                    # pylint: disable=no-member

                    # Decode from the locale using using the surrogate escape
                    # error handler (decoding cannot fail)
                    (stdout, stderr) = result
                    stdout = os.fsdecode(stdout)
                    stderr = os.fsdecode(stderr)
                else:
                    stdout, stderr = result

                if not ignore_exit_code and return_code not in check_exit_code:
                    raise subprocess.CalledProcessError(
                        returncode=return_code, cmd=command,
                        output=(stdout, stderr))
                else:
                    return (stdout, stderr)
            except subprocess.CalledProcessError:
                if attempts:
                    time.sleep(retry_interval)
                else:
                    raise


class Application(Executor):

    def __init__(self):
        super(Application, self).__init__(delay=0, loop=False)
        self._config = {}

    @property
    def config(self):
        """Expose the arguments received from the client."""
        return self._config

    def _prologue(self):
        """Process the information received from the client."""
        parser = argparse.ArgumentParser(
            description="Install the Argus-CI on the current machine.")

        parser.add_argument(
            "--attempts", dest="attempts", type=int, default=3,
            help="Interval between execute attempts, in seconds. "
                 "(Default: 3)")
        parser.add_argument(
            "--retry_interval", dest="retry_interval", type=float, default=0.1,
            help="How many times to retry running the command. "
                 "(Default: 0.1)")

        group = parser.add_mutually_exclusive_group()
        group.add_argument(
            "--no-venv", dest="setup_venv", action="store_false",
            help="Install the requirements on the global environment")
        group.add_argument(
            "--venv", dest="venv", type=str, default="/var/lib/argus-env",
            help="The path for the virtual environment. "
                 "(Default: /var/lib/argus-env)"
        )

        parser.add_argument(
            "--argus-branch", dest="argus_branch", default="master",
            help="the required branch / revision of argus repository "
                 "(Default: master)")
        parser.add_argument(
            "--tempest-branch", dest="tempest_branch", default="tags/7",
            help="the required branch / revision of argus repository "
                 "(Default: tags/7)")

        group = parser.add_mutually_exclusive_group()
        group.add_argument("-v", "--verbose", action="store_true",
                           default=False)
        group.add_argument("-q", "--quiet", action="store_true",
                           default=False)

        self._config = parser.parse_args()


class CreateEnvironment(Command):

    """Command used for creating virtual environment for Argus-CI."""

    def _work(self):
        """Create the virtual environment for Argus-Ci and Tempest."""
        if self._setup_venv:
            # TODO(alexandrucoman): Check if th recieved path is available
            self._execute(["virtualenv", self._venv, "--python",
                           "/usr/bin/python2.7"])

    def _epilogue(self):
        """Executed once after the command running."""
        if self._setup_venv:
            self._execute([self._pip, "install", "pip", "--upgrade"])


class InstallTempest(Command):

    """Command used for installing tempest and its requirements."""

    REPO = 'https://github.com/openstack/tempest.git'

    def __init__(self, executor):
        super(InstallTempest, self).__init__(executor=executor)
        self._clone_path = "/tmp/tempest"

    def _prologue(self):
        """Executed once before the command running."""
        super(InstallTempest, self)._prologue()
        branch = self._executor.get('tempest_branch')

        # TODO(alexandrucoman): Check if the clone path is available
        self._execute(["git", "clone", self.REPO, self._clone_path])
        self._execute(["git", "checkout", branch], cwd=self._clone_path)

    def _work(self):
        """Install the tempest package and its requirements."""
        self._execute([self._pip, "install", "-r", "requirements.txt"],
                      cwd=self._clone_path)
        self._execute([self._pip, "install", "-r", "test-requirements.txt"],
                      cwd=self._clone_path)
        self._execute([self._python, "setup.py", "install"],
                      cwd=self._clone_path)

    def _epilogue(self):
        """Executed once after the command running."""
        self._execute([self._python, "-c", "import tempest"])
        # TODO(alexandrucoman): Create the config file


class InstallArgusCi(Command):

    """Command used for installing argus-ci and its requirements."""

    REPO = 'https://github.com/cloudbase/cloudbase-init-ci'

    def __init__(self, executor):
        super(InstallArgusCi, self).__init__(executor=executor)
        self._clone_path = "/tmp/argus"

    def _prologue(self):
        """Executed once before the command running."""
        super(InstallArgusCi, self)._prologue()
        branch = self._executor.get('argus_branch')

        # TODO(alexandrucoman): Check if the clone path is available
        self._execute(["git", "clone", self.REPO, self._clone_path])
        self._execute(["git", "checkout", branch], cwd=self._clone_path)

    def _work(self):
        """Install the argus-ci framework and its requirements."""
        self._execute([self._pip, "install", "-r", "requirements.txt"],
                      cwd=self._clone_path)
        self._execute([self._python, "setup.py", "install"],
                      cwd=self._clone_path)

    def _epilogue(self):
        """Executed once after the command running."""
        self._execute([self._python, "-c", "import argus"])
        # TODO(alexandrucoman): Create the config file


def main():
    """Run the command line application."""
    application = Application()
    # Create the virtual environment for Argus-Ci
    application.put_task(task=CreateEnvironment(application))
    # Install Tempest and its requirements
    application.put_task(task=InstallTempest(application))
    # Install Arugs-Ci and its requirements
    application.put_task(task=InstallArgusCi(application))
    # Run the application
    application.run()


if __name__ == "__main__":
    main()
