static void SetACLPrivileges();

static bool ReadSacl=false;



#ifndef SFX_MODULE
void ExtractACL20(Archive &Arc,const std::wstring &FileName)
{
  SetACLPrivileges();

  if (Arc.BrokenHeader)
  {
    uiMsg(UIERROR_ACLBROKEN,Arc.FileName,FileName);
    ErrHandler.SetErrorCode(RARX_CRC);
    return;
  }

  if (Arc.EAHead.Method<0x31 || Arc.EAHead.Method>0x35 || Arc.EAHead.UnpVer>VER_PACK)
  {
    uiMsg(UIERROR_ACLUNKNOWN,Arc.FileName,FileName);
    ErrHandler.SetErrorCode(RARX_WARNING);
    return;
  }

  ComprDataIO DataIO;
  Unpack Unpack(&DataIO);
  Unpack.Init(0x10000,false);

  std::vector<byte> UnpData(Arc.EAHead.UnpSize);
  DataIO.SetUnpackToMemory(&UnpData[0],Arc.EAHead.UnpSize);
  DataIO.SetPackedSizeToRead(Arc.EAHead.DataSize);
  DataIO.EnableShowProgress(false);
  DataIO.SetFiles(&Arc,NULL);
  DataIO.UnpHash.Init(HASH_CRC32,1);
  Unpack.SetDestSize(Arc.EAHead.UnpSize);
  Unpack.DoUnpack(Arc.EAHead.UnpVer,false);

  if (Arc.EAHead.EACRC!=DataIO.UnpHash.GetCRC32())
  {
    uiMsg(UIERROR_ACLBROKEN,Arc.FileName,FileName);
    ErrHandler.SetErrorCode(RARX_CRC);
    return;
  }

  SECURITY_INFORMATION  si=OWNER_SECURITY_INFORMATION|GROUP_SECURITY_INFORMATION|
                           DACL_SECURITY_INFORMATION;
  if (ReadSacl)
    si|=SACL_SECURITY_INFORMATION;
  SECURITY_DESCRIPTOR *sd=(SECURITY_DESCRIPTOR *)&UnpData[0];

  int SetCode=SetFileSecurity(FileName.c_str(),si,sd);

  if (!SetCode)
  {
    uiMsg(UIERROR_ACLSET,Arc.FileName,FileName);
    DWORD LastError=GetLastError();
    ErrHandler.SysErrMsg();
    if (LastError==ERROR_ACCESS_DENIED && !IsUserAdmin())
      uiMsg(UIERROR_NEEDADMIN);
    ErrHandler.SetErrorCode(RARX_WARNING);
  }
}
#endif


void ExtractACL(Archive &Arc,const std::wstring &FileName)
{
  std::vector<byte> SubData;
  if (!Arc.ReadSubData(&SubData,NULL,false))
    return;

  SetACLPrivileges();

  SECURITY_INFORMATION si=OWNER_SECURITY_INFORMATION|GROUP_SECURITY_INFORMATION|
                          DACL_SECURITY_INFORMATION;
  if (ReadSacl)
    si|=SACL_SECURITY_INFORMATION;
  SECURITY_DESCRIPTOR *sd=(SECURITY_DESCRIPTOR *)&SubData[0];

  int SetCode=SetFileSecurity(FileName.c_str(),si,sd);
  if (!SetCode)
  {
    std::wstring LongName;
    if (GetWinLongPath(FileName,LongName))
      SetCode=SetFileSecurity(LongName.c_str(),si,sd);
  }

  if (!SetCode)
  {
    uiMsg(UIERROR_ACLSET,Arc.FileName,FileName);
    DWORD LastError=GetLastError();
    ErrHandler.SysErrMsg();
    if (LastError==ERROR_ACCESS_DENIED && !IsUserAdmin())
      uiMsg(UIERROR_NEEDADMIN);
    ErrHandler.SetErrorCode(RARX_WARNING);
  }
}


void SetACLPrivileges()
{
  static bool InitDone=false;
  if (InitDone)
    return;

  if (SetPrivilege(SE_SECURITY_NAME))
    ReadSacl=true;
  SetPrivilege(SE_RESTORE_NAME);

  InitDone=true;
}
