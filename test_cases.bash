#!/bin/bash
test_cases=(
  "1.0 1.0 0"
  "1.0.0 1.0 -1"
  "1.0.1 1.0 -1"
  "2.0 1.0 -1"
  "1.2-3 1.2-4 1"
  "1.0-1 1.0-2 1"
  "1.0-1 1.0-1ubuntu1 1"
  "5.1-6ubuntu1 5.1-6ubuntu1.1 1"
  "2.0-0ubuntu1 2.0-0ubuntu2 1"
  "0.37.1-2ubuntu0.22.04.1 0.37.1-2ubuntu0.22.04.2 1"
  "1.0-1 1.0+1 1"
  "1.0.1+1 1.0.1 -1"
  "1.1~b-1 1.1-1 1"
  "8.6.11+1build2 8.6.11+1build1 -1"
  "2:1.2 1.2 -1"
  "2:2.0 2:1.9 -1"
  "1:1.3.1-1 2:1.3.1-1 1"
  "2.4.8-1ubuntu3.16+esm6 2.4.18-2ubuntu3.16+esm6 1"
  "2.4.18-1ubuntu3.16+xxx60+esm6 2.4.18-2ubuntu3.16+xxx9+esm6 1"
  "2.4.18-1ubuntu3.16+esm6 2.4.18-2ubuntu3.16+esm6 1"
  "2.4.18-2ubuntu3.16+esm6 2.4.18-2ubuntu3.17+esm3 1"
  "2.4.18-2ubuntu3.17+esm3 2.4.18-2ubuntu3.17+esm10 1"
  "8.8.0+dfsg-1 8.8.0+dfsg-2 1"
  "2.40.2-2build4 2.40.2-2build3 -1"
  "2.4.18-2ubuntu3.17+esm3 2.4.18-2ubuntu3.17 -1"
  "2.4.18-2ubuntu3.17+esm10 2.4.18-2ubuntu3.17+esm3 -1"
)
