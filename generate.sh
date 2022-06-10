#!/bin/bash

set -eu

(
    echo "# This file was generate. Please edit snapcraft.yaml.in instead"
    yq 'explode(.) | with_entries(select(.key | test("^[.]") | not))' snapcraft.yaml.in
)>snapcraft.yaml
