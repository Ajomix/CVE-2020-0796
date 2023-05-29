# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

$credential = ./CreatePSCredential.ps1
Invoke-Command -ComputerName $computerName {netsh branchcache flush} -Credential $credential
