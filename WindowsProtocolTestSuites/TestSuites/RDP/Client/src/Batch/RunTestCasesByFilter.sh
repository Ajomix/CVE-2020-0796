#!/bin/bash
#
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.
#
# Argument 1: Expression used to filter test cases. For example, "TestCategory=BVT" will filter out test cases which have test category BVT. 
# Argument 2: If set, just list all filtered test cases instead of running tests actually.

InvocationPath=$(dirname "$0")

Binaries="RDP_ClientTestSuite.dll"

Filter=$1

DryRun=$2

Cmd="$InvocationPath/RunTestCasesByBinariesAndFilter.sh \"$Binaries\" \"$Filter\" \"$DryRun\""

eval $Cmd
