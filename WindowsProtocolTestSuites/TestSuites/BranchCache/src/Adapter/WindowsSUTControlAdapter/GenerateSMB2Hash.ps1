# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

$credential = ./CreatePSCredential.ps1
Invoke-Command -ComputerName $computerName { param($path) hashgen $path } -Args $path -Credential $credential
