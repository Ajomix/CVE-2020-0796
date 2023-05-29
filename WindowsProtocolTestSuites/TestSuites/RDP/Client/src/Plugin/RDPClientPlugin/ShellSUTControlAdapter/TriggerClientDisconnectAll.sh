﻿# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

# This script is used to trigger RDP client to close all RDP connection to server for clean up.

# The following example code kills all xfreerdp processes on the SUT machine through SSH.
#
ssh $PTFProp_SUTUserName@$PTFProp_SUTName "killall -9 xfreerdp"

# Print an integer at the end of script.
# This number will be parsed as the return value of function
# TriggerClientDisconnectAll(string caseName)
# Using a positive value to indicate success
echo 1
