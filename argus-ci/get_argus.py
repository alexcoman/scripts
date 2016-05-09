#!/usr/bin/env python
"""Install the Argus-CI project on the current machine."""

import abc
import argparse
import os
import logging
import platform
import sys
import shutil
import subprocess
import time

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


class Action(Worker):

    """Contract class for all the commands."""

    def __init__(self, parent, parser):
        super(Action, self).__init__()
        self._args = None
        self._command_line = None
        self._parent = parent
        self._parser = parser

        self.setup()

    @property
    def parent(self):
        """Return the object that contains the current command."""
        return self._parent

    @property
    def args(self):
        """The command line arguments parsed by the client."""
        if self._args is None:
            self._args = self._discover_attribute("args")
        return self._args

    @property
    def command_line(self):
        """Command line provided to parser."""
        if self._command_line is None:
            self._command_line = self._discover_attribute("command_line")

        return self._command_line

    def _discover_attribute(self, attribute):
        """Search for the received attribute in the command tree."""
        command_tree = [self.parent]
        while command_tree:
            parent = command_tree.pop()
            if hasattr(parent, attribute):
                return getattr(parent, attribute)
            elif parent.parent is not None:
                command_tree.append(parent.parent)

        raise ValueError("The %(attribute)s attribute is missing from the "
                         "client tree." % {"attribute": attribute})

    def task_done(self, result):
        """What to execute after successfully finished processing a task."""
        pass

    def task_fail(self, exc):
        """What to do when the program fails processing a task."""
        raise exc

    def interrupted(self):
        """What to execute when keyboard interrupts arrive."""
        raise KeyboardInterrupt()

    @abc.abstractmethod
    def setup(self):
        """Extend the parser configuration in order to expose this command."""
        pass

    @abc.abstractmethod
    def _work(self):
        """Override this with your desired procedures."""
        pass


class Group(object):

    """Contract class for all the command groups.

    :ivar: commands: A list which contains (command, parser_name) tuples.

    ::
    Example:
    ::
        class Example(Group):

            commands = [
                (ExampleOne, "main_parser"),
                (ExampleTwo, "main_parser),
                (ExampleThree, "second_parser")
            ]

            # ...
    """

    commands = None

    def __init__(self, parent, parser):
        super(Group, self).__init__()
        self._parent = parent
        self._parser = parser
        self._parsers = {}
        self._childs = []

        self.setup()            # Setup the current command group
        self._bind_commands()   # Bind all the received commands

    @property
    def parent(self):
        """Return the object that contains the current command group."""
        return self._parent

    def _bind_commands(self):
        """Bind the received commands to the current command group."""
        for command, parser in self.commands or ():
            if not self.check_command(command):
                continue
            self.bind(command, parser)

    def _register_parser(self, name, parser):
        """Register a new parser in this command."""
        self._parsers[name] = parser

    def _get_parser(self, name):
        """Get an parser from the current command group."""
        try:
            return self._parsers[name]
        except KeyError:
            raise ValueError("Invalid parser name %(name)s" %
                             {"name": name})

    @classmethod
    def check_command(cls, command):
        """Check if the received command is valid and can be
        property used.
        """
        if not issubclass(command, (Action, Group)):
            return False

        return True

    def bind(self, command, parser_name):
        """Bind the received command to the current one."""
        parser = self._get_parser(parser_name)
        self._childs.append(command(self, parser))

    @abc.abstractmethod
    def setup(self):
        """Extend the parser configuration in order to expose this command."""
        pass


class CliApplication(Group, Worker):

    """Contract class for all the command line applications.

    :ivar: commands: A list which contains (command, parser_name) tuples

    ::
    Example:
    ::
        class Example(CommandGroup):

            commands = [
                (ExampleOne, "main_parser"),
                (ExampleTwo, "main_parser),
                (ExampleThree, "second_parser")
            ]

            # ...
    """

    def __init__(self, command_line):
        super(CliApplication, self).__init__(parent=None, parser=None)
        self._args = None
        self._command_line = command_line
        self._logger = None

    @property
    def args(self):
        """The arguments after the command line was parsed."""
        return self._args

    @property
    def command_line(self):
        """Command line provided to parser."""
        return self._command_line

    @property
    def logger(self):
        """Expose the logger object."""
        if not self._logger:
            level = (logging.DEBUG if self.args.verbose
                     else logging.ERROR)
            self._logger = self._get_logger(__name__, level)
        return self._logger

    @staticmethod
    def _get_logger(name, level):
        """Obtain a new logger object."""
        logger = logging.getLogger(name)
        formatter = logging.Formatter("%(asctime)s - %(name)s - "
                                      "%(levelname)s - %(message)s")

        if not logger.handlers:
            # If the logger wasn't obtained another time,
            # then it shouldn't have any loggers

            stdout_handler = logging.StreamHandler(sys.stdout)
            stdout_handler.setFormatter(formatter)
            logger.addHandler(stdout_handler)

        logger.setLevel(level)
        return logger

    def task_done(self, result):
        """What to execute after successfully finished processing a task."""
        pass

    def task_fail(self, exc):
        """What to do when the program fails processing a task."""
        pass

    def interrupted(self):
        """What to execute when keyboard interrupts arrive."""
        pass

    @abc.abstractmethod
    def setup(self):
        """Extend the parser configuration in order to expose all
        the received commands.

        Exemple:
        ::
            # ...
            self._parser = argparse.ArgumentParser(
                description=description)
            self._main_parser.add_argument(
                "--example", help="just an example")
            subcommands = self._parser.add_subparsers(
                title="[sub-commands]")
            self._register_parser("subcommands", subcommands)
            # ...
        """
        pass

    def _prologue(self):
        """Executed once before the command running."""
        super(CliApplication, self)._prologue()
        self._args = self._parser.parse_args(self.command_line)

    def _work(self):
        """Parse the command line."""
        if not self.args:
            self.logger.error("No command line arguments was provided.")
            return

        work_function = getattr(self.args, "work", None)
        if not work_function:
            self.logger.error("No handle was provided for the "
                              "required action. (%s)", self.args)
            return

        return work_function()


@six.add_metaclass(abc.ABCMeta)
class Task(Worker):

    """Contract class for all the commands and clients."""

    def __init__(self, executor=None):
        super(Task, self).__init__()
        self._executor = executor
        self._name = self.__class__.__name__

    @property
    def name(self):
        """Return the name of the task."""
        return self._name

    @abc.abstractmethod
    def _work(self):
        """Override this with your desired procedures."""
        pass

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
class Command(Task):

    def __init__(self, executor):
        super(Command, self).__init__(executor)
        self._attemts, self._retry_interval = None, None
        self._venv, self._setup_venv = None, None
        self._python, self._pip = None, None

    @property
    def args(self):
        """Expose the args object."""
        return self._executor.args

    @property
    def logger(self):
        """Expose the logger object."""
        return self._executor.logger

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

        :param admin:           run command as superuser

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
        command = [str(argument) for argument in command]

        if cwd and not os.path.isdir(cwd):
            print("[w] Invalid value for cwd: {cwd}".format(cwd=cwd))
            cwd = None

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


class _SetupEnvironment(Command):

    """Command used for installing the global requirements."""

    def __init__(self, executor):
        super(_SetupEnvironment, self).__init__(executor=executor)
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


class _CreateEnvironment(Command):

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


class _InstallTempest(Command):

    """Command used for installing tempest and its requirements."""

    REPO = 'https://github.com/openstack/tempest.git'

    def __init__(self, executor):
        super(_InstallTempest, self).__init__(executor=executor)
        self._clone_path = "/tmp/tempest"

    def _prologue(self):
        """Executed once before the command running."""
        super(_InstallTempest, self)._prologue()
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


class _InstallArgusCi(Command):

    """Command used for installing argus-ci and its requirements."""

    REPO = 'https://github.com/cloudbase/cloudbase-init-ci'

    def __init__(self, executor):
        super(_InstallArgusCi, self).__init__(executor=executor)
        self._clone_path = "/tmp/argus"

    def _prologue(self):
        """Executed once before the command running."""
        super(_InstallArgusCi, self)._prologue()
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
        super(_InstallArgusCi, self)._epilogue()


class InstallArgusCi(Action):

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
            _SetupEnvironment,   # Install all the requirements for Argus-Ci
            _CreateEnvironment,  # Create the virtual environment for Argus-Ci
            _InstallTempest,     # Install Tempest and its requirements
            _InstallArgusCi      # Install Arugs-Ci and its requirements
        )

        for task in tasks:
            task(self).run()


class ArgusClient(CliApplication):

    """Command line application for deploying Argus-Ci."""

    commands = [
        (InstallArgusCi, "commands"),
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

    jarvis = ArgusClient(sys.argv[1:])
    jarvis.run()


if __name__ == "__main__":
    main()
