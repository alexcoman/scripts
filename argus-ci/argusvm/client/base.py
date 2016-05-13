"""
Client base-classes:
    (Beginning of) the contract that commands and parsers must follow.
"""

import abc
import sys
import logging

from argusvm.worker import base as base_worker


class Command(base_worker.Worker):

    """Contract class for all the commands."""

    def __init__(self, parent, parser):
        super(Command, self).__init__()
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

    @classmethod
    def task_fail(cls, exc):
        """What to do when the program fails processing a task."""
        raise exc

    @classmethod
    def interrupted(cls):
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
        if not issubclass(command, (Command, Group)):
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


class Application(Group, base_worker.Worker):

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
        super(Application, self).__init__(parent=None, parser=None)
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
        super(Application, self)._prologue()
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
