#!/usr/bin/env python
"""Install the Argus-CI project on the current machine."""

import abc
import threading

import six

ATTEMPTS = 3
RETRY_INTERVAL = 0.1


@six.add_metaclass(abc.ABCMeta)
class Worker(object):

    """Contract class for all the commands and clients."""

    def prologue(self):
        """Executed once before the command running."""
        pass

    @abc.abstractmethod
    def work(self):
        """Override this with your desired procedures."""
        pass

    def epilogue(self):
        """Executed once after the command running."""
        pass

    def run(self):
        """Run the command."""
        result = None
        self.prologue()
        result = self.work()
        self.epilogue()
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
        self.prologue()
        try:
            result = self.work()
        except Exception as exc:
            self.task_fail(exc)
        else:
            self.task_done(result)
        self.epilogue()
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
            return self._queue.pop()

    def _work(self, task):
        """Run the received task and process the result."""
        # pylint: disable=broad-except
        try:
            return task.run()
        except Exception as exc:
            self.on_task_fail(task, exc)

    def put_task(self, task):
        """Adds a task to the tasks queue."""
        if not isinstance(task, Task):
            raise ValueError("Invalid type of task provided.")
        self._queue.append(task)

    def run(self):
        """Processes incoming tasks."""
        self.prologue()
        while not self._stop_event.is_set():
            try:
                task = self._get_task()
                if task:
                    self._work(task)
                if not self._loop:
                    break
            except KeyboardInterrupt:
                self.on_interrupted()
                break
        self.epilogue()
