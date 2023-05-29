// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

using System;
using System.DirectoryServices.Protocols;
using Microsoft.Protocols.TestTools;
using Microsoft.Protocols.TestTools.StackSdk.Dtyp;
using Microsoft.Protocols.TestTools.StackSdk.Networking.Rpce;
using Microsoft.Protocols.TestTools.StackSdk.Security.Samr;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;

namespace Microsoft.Protocols.TestSuites.ActiveDirectory.Adts.Samr
{
    public partial class SAMR_TestSuite : TestClassBase
    {
        /// <summary>
        /// Test method of SamrOpenUser and SamrCloseHandle with different DesiredAccess
        /// </summary>
        [TestMethod]
        [TestCategory("MS-SAMR")]
        [TestCategory("DomainWin2008R2")]
        [TestCategory("ForestWin2008R2")]
        [TestCategory("PDC")]
        [TestCategory("SAMR-Group")]
        [Description("This is to test SamrOpenGroup and SamrCloseHandle with different DesiredAccess.")]
        public void SamrOpenCloseGroup()
        {
            ConnectAndOpenDomain(_samrProtocolAdapter.pdcFqdn, _samrProtocolAdapter.PrimaryDomainDnsName, out _serverHandle, out _domainHandle);

            Site.Log.Add(LogEntryKind.TestStep, "SamrLookupNamesInDomain: get rid for {0}.", _samrProtocolAdapter.DomainAdminGroup);
            List<string> groupNames = new List<string>();
            groupNames.Add(_samrProtocolAdapter.DomainAdminGroup);
            List<uint> groupRids = new List<uint>();
            HRESULT result = _samrProtocolAdapter.SamrLookupNamesInDomain(_domainHandle, groupNames, out groupRids);
            Site.Assert.AreEqual(HRESULT.STATUS_SUCCESS, result, "SamrLookupNamesInDomain returns:{0}.", result);
            Site.Assume.IsTrue(groupRids.Count == 1, "{0} group(s) with name {1} found.", groupRids.Count, _samrProtocolAdapter.DomainAdminGroup);

            foreach (Common_ACCESS_MASK acc in Enum.GetValues(typeof(Common_ACCESS_MASK)))
            {
                Site.Log.Add(LogEntryKind.TestStep, "SamrOpenGroup: obtain a handle to a group with DesiredAccess as {0}.", acc.ToString());
                result = _samrProtocolAdapter.SamrOpenGroup(_domainHandle, (uint)acc, groupRids[0], out _groupHandle);
                Site.Assert.AreEqual(HRESULT.STATUS_SUCCESS, result, "SamrOpenGroup returns:{0}.", result);
                Site.Assert.IsNotNull(_groupHandle, "The returned group handle is: {0}.", _groupHandle);

                Site.Log.Add(LogEntryKind.TestStep, "SamrCloseHandle: close the opened group handle.");
                result = _samrProtocolAdapter.SamrCloseHandle(ref _groupHandle);
                Site.Assert.AreEqual(HRESULT.STATUS_SUCCESS, result, "SamrCloseHandle returns:{0}.", result);
                Site.Assert.AreEqual(IntPtr.Zero, _groupHandle, "The opened group handle has been closed.");
            }
            foreach (Generic_ACCESS_MASK acc in Enum.GetValues(typeof(Generic_ACCESS_MASK)))
            {
                Site.Log.Add(LogEntryKind.TestStep, "SamrOpenGroup: obtain a handle to a group with DesiredAccess as {0}.", acc.ToString());
                result = _samrProtocolAdapter.SamrOpenGroup(_domainHandle, (uint)acc, groupRids[0], out _groupHandle);
                Site.Assert.AreEqual(HRESULT.STATUS_SUCCESS, result, "SamrOpenGroup returns:{0}.", result);
                Site.Assert.IsNotNull(_groupHandle, "The returned group handle is: {0}.", _groupHandle);

                Site.Log.Add(LogEntryKind.TestStep, "SamrCloseHandle: close the opened group handle.");
                result = _samrProtocolAdapter.SamrCloseHandle(ref _groupHandle);
                Site.Assert.AreEqual(HRESULT.STATUS_SUCCESS, result, "SamrCloseHandle returns:{0}.", result);
                Site.Assert.AreEqual(IntPtr.Zero, _groupHandle, "The opened group handle has been closed.");
            }
            foreach (Group_ACCESS_MASK acc in Enum.GetValues(typeof(Group_ACCESS_MASK)))
            {
                Site.Log.Add(LogEntryKind.TestStep, "SamrOpenGroup: obtain a handle to a group with DesiredAccess as {0}.", acc.ToString());
                result = _samrProtocolAdapter.SamrOpenGroup(_domainHandle, (uint)acc, groupRids[0], out _groupHandle);
                Site.Assert.AreEqual(HRESULT.STATUS_SUCCESS, result, "SamrOpengroup returns:{0}.", result);
                Site.Assert.IsNotNull(_groupHandle, "The returned group handle is: {0}.", _groupHandle);

                Site.Log.Add(LogEntryKind.TestStep, "SamrCloseHandle: close the opened group handle.");
                result = _samrProtocolAdapter.SamrCloseHandle(ref _groupHandle);
                Site.Assert.AreEqual(HRESULT.STATUS_SUCCESS, result, "SamrCloseHandle returns:{0}.", result);
                Site.Assert.AreEqual(IntPtr.Zero, _groupHandle, "The opened group handle has been closed.");
            }
        }

        [TestMethod]
        [TestCategory("MS-SAMR")]
        [TestCategory("DomainWin2008R2")]
        [TestCategory("ForestWin2008R2")]
        [TestCategory("PDC")]
        [TestCategory("SAMR-Group")]
        [Description("This is to test SamrOpenGroup with DomainHandle.HandleType not equal to Domain.")]
        public void SamrOpenGroup_InvalidHandle()
        {
            ConnectAndOpenDomain(_samrProtocolAdapter.pdcFqdn, _samrProtocolAdapter.PrimaryDomainDnsName, out _serverHandle, out _domainHandle);

            Site.Log.Add(LogEntryKind.TestStep, "SamrOpenGroup: The server MUST return an error if DomainHandle.HandleType is not equal to Domain.");
            HRESULT result = _samrProtocolAdapter.SamrOpenGroup(_serverHandle, (uint)Group_ACCESS_MASK.GROUP_ALL_ACCESS, Utilities.DOMAIN_GROUP_RID_USERS, out _groupHandle);
            Site.Assert.AreNotEqual(HRESULT.STATUS_SUCCESS, result, "SamrOpenGroup returns an error:{0}.", result.ToString("X"));
            Site.Assert.AreEqual(IntPtr.Zero, _groupHandle, "The returned group handle should be zero.");
        }

        [TestMethod]
        [TestCategory("MS-SAMR")]
        [TestCategory("DomainWin2008R2")]
        [TestCategory("ForestWin2008R2")]
        [TestCategory("PDC")]
        [TestCategory("SAMR-Group")]
        [Description("This is to test SamrOpenGroup without required access.")]
        public void SamrOpenGroup_STATUS_ACCESS_DENIED()
        {
            ConnectAndOpenDomain(_samrProtocolAdapter.pdcFqdn, _samrProtocolAdapter.PrimaryDomainDnsName, out _serverHandle, out _domainHandle, Utilities.DOMAIN_READ);

            Site.Log.Add(LogEntryKind.TestStep, "SamrOpenGroup: DomainHandle.GrantedAccess MUST have the required access.");
            HRESULT result = _samrProtocolAdapter.SamrOpenGroup(_domainHandle, (uint)Group_ACCESS_MASK.GROUP_ALL_ACCESS, Utilities.DOMAIN_GROUP_RID_USERS, out _groupHandle);
            Site.Assert.AreEqual(HRESULT.STATUS_ACCESS_DENIED, result, "SamrOpenGroup returns an error:{0}.", result.ToString("X"));
            Site.Assert.AreEqual(IntPtr.Zero, _groupHandle, "The returned group handle should be zero.");
        }

        [TestMethod]
        [TestCategory("MS-SAMR")]
        [TestCategory("DomainWin2008R2")]
        [TestCategory("ForestWin2008R2")]
        [TestCategory("PDC")]
        [TestCategory("SAMR-Group")]
        [Description("This is to test SamrOpenGroup with no such group.")]
        public void SamrOpenGroup_NoSuchGroup()
        {
            ConnectAndOpenDomain(_samrProtocolAdapter.pdcFqdn, _samrProtocolAdapter.PrimaryDomainDnsName, out _serverHandle, out _domainHandle);

            uint invaldRid = 5000;
            Site.Log.Add(LogEntryKind.TestStep, "SamrOpenGroup: If no such object exists, the server MUST return an error code.");
            HRESULT result = _samrProtocolAdapter.SamrOpenGroup(_domainHandle, (uint)Group_ACCESS_MASK.GROUP_ALL_ACCESS, invaldRid, out _groupHandle);
            Site.Assert.AreEqual(HRESULT.STATUS_NO_SUCH_GROUP, result, "SamrOpenGroup returns an error:{0}.", result.ToString("X"));
            Site.Assert.AreEqual(IntPtr.Zero, _groupHandle, "The returned group handle should be zero.");
        }
    }
}
