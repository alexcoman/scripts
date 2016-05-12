#! /usr/bin/env python
"""ArgusVM install script."""

try:
    from setuptools import setup
except ImportError:
    from distutils.core import setup


setup(
    name="argusvm",
    version="0.1",
    description="Various tools for the Arugs-CI framework.",
    long_description=open("README.md").read(),
    author="Cloudbase Solutions Srl",
    url="http://www.cloudbase.it/",
    packages=["argusvm"],
    scripts=["scripts/argusvm"],
    requires=["six"]
)
