#!/usr/bin/env bash

uv run gdformat addons/leadr/**/*.gd
uv run gdlint addons/leadr/**/*.gd
