#  Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
#  See https://llvm.org/LICENSE.txt for license information.
#  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

from setuptools import find_namespace_packages, setup, Distribution

packages = find_namespace_packages(
    include=[
        "mlir",
        "mlir.*",
    ],
)

class BinaryDistribution(Distribution):
    """Distribution which always forces a binary package with platform name"""

    def has_ext_modules(foo):
        return True

setup(
    name="mlir-python-bindings",
    include_package_data=True,
    packages=packages,
    zip_safe=False,
    distclass=BinaryDistribution
)
