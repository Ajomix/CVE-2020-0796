# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

$credential = ./CreatePSCredential.ps1
$status = Invoke-Command -ComputerName $computerName {netsh branchcache show publicationcache} -Credential $credential

if ($status -match "Active Current Cache Size\s*\= 0 Bytes")
{
	return $false
}
else
{
	return $true
}
