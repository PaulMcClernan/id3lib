script "id3lib"
------------------------------------------------------
--id3lib
--version: 1.0.2
--author: Mark Smith mark@maseurope.net
--date: 28th May 2007
------------------------------------------------------
-- version: 1.0.3
-- Unfortunately the original author, Mark Smith, died in 2009. Nice work Mark. Rest in peace.
-- I've made some minor changes in an effort to keep his library up to date with
-- newer verions of LiveCode (use 'byte' instead of 'char') and to work around some improperly 
-- encoded ID3 tags (unicode 'year' frames) that I've encountered while using the lib. 
-- There are still some bugs and functionality missing. Writing picture frames is 
-- broken/unfinished as well as failures reading certain pictures. I hope to correct these problems or,
-- failing that, write my own library from scratch at some point. In the mean-time, I've added two "brute-force" 
-- picture extraction functions (extractPNGfromAnyFile and extractJPEGfromAnyFile).
--
-- Paul McClernan
-- date: April 26th 2015
------------------------------------------------------

local sFilePath
local sFileName
local sRawTagHead
local sTagHead
local sTagDataSize
local sTagData
local sFrameArray
local sFrameDataSize
local sFrameNum
local sFrameIndex
local sFrameOffsets
local sPicArray
local sPicNum
local sPicTypes
local sFrameDict
local sUnSync
local sBigEndian
local sBOM
local sError
local sIsUnicode
----

function getFrameArray
  return sFrameArray
end getFrameArray

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--





-------------
--reading
-------------

on i3initLibrary
  put (byte 1 of binaryencode("I",1) is null) into sBigEndian
  if sBigEndian then
    put numtochar(254) & numtochar(255) into sBOM
  else
    put numtochar(255) & numtochar(254) into sBOM
  end if
  put true into sUnSync
  put empty into sFrameOffsets
  put empty into sTagHead
  put empty into sRawTagHead
  put empty into sTagDataSize
  put empty into sTagData
  put empty into sFrameArray
  put empty into sFrameDataSize
  put empty into sFrameIndex
  put 0 into sFrameNum
  put 0 into sPicNum
end i3initLibrary

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

on i3setError pText
  put pText into sError
end i3setError

function id3_getError
  return sError
end id3_getError

on i3clearError
  put empty into sError
end i3clearError

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

function i3getFrameArray pNum,pField
  return sframeArray[pNum,pField]
end i3getFrameArray


--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--


function i3getShortTagType
  return sTagHead["shortType"]
end i3getShortTagType

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

on i3setFile pFile
  i3initLibrary
  
  if not i3isMpegFile(pFile) then return "not mpeg audio file"
   
  put i3getTagType(pFile) into tType
   
  put tType into sTagHead["shortType"]
   
  put pFile into sFilePath
  set the itemdelimiter to "/"
  put item -1 of pFile into sFileName
   
  put the picTypes23 of me into sPicTypes
  split sPicTypes by cr and "="
   
  switch tType
  case 22
    put the frameDictionary22 of me into sFrameDict
    split sFrameDict by cr and "="
    i3readTag22 pFile
    break
  case 23
    put the frameDictionary23 of me into sFrameDict
    split sFrameDict by cr and "="
    i3readTag23 pFile
    break
  case 24
    put the frameDictionary24 of me into sFrameDict
    split sFrameDict by cr and "="
    i3readTag24 pFile
    break
  case 11
    put the frameDictionary23 of me into sFrameDict
    split sFrameDict by cr and "="
    i3readTag11 pFile
    break
  case M4
    put the frameDictionaryM4 of me into sFrameDict
    split sFrameDict by cr and "="
    i3readTagM4 pFile 
    break
  end switch
   
   
  i3makeFrameIndex
  i3calcFrameDataSize
  put the frameDictionary23 of me into sFrameDict
  split sFrameDict by cr and "="
   
end i3setFile

--==--==--==--==--==--==--

function i3isMpegFile pFile
  get i3getFileType(pFile)
  if "MPG" is in it or "MPEG" is in it then return true
  if char -3 to -1 of pFile is among the items of "mp3,mp4,m4a,m4p,m4b" then return true
  return false
end i3isMpegFile

--==--==--==--==--==--==--

on i3makeFrameIndex
  put empty into sFrameIndex
  repeat with n = 1 to sFrameNum
    if sFrameArray[n,"id"] is not empty then
      put n & comma after sFrameIndex[sFrameArray[n,"id"]]
    end if
  end repeat
end i3makeFrameIndex

--==--==--==--==--==--==--

on i3calcFrameDataSize
  repeat with n = 1 to sFrameNum
    add item 1 of sFrameArray[n,"size"] to tTotal
  end repeat
  put tTotal into sFrameDataSize
end i3calcFrameDataSize

--==--==--==--==--==--==--

function i3isInAnotherFrame pOffset
  repeat for each line L in sFrameOffsets
    if pOffset >= item 1 of L and pOffset <= item 2 of L then return true
  end repeat
  return false
end i3isInAnotherFrame

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

function i3getTagType pFile
  put empty into tType
  open file pFile for binary read
  read from file pFile for 20
  put it into tTwenty
  close file pFile
  
  if char 1 to 3 of tTwenty is "ID3" then
    put "ID3v2." & bytetonum(byte 4 of tTwenty) & "." & bytetonum(byte 5 of tTwenty) into sTagHead["type"]
    put 2 & bytetonum(byte 4 of tTwenty) into tType
  else if "M4A" is in tTwenty then
    put "M4A" into sTagHead["type"]
    put "M4" into tType
  end if
  
  if tType is empty then
    open file pFile for binary read
    seek to -128 in file pFile
    read from file pFile for 128
    put it into t128
    close file pFile
    if byte 1 to 3 of t128 is "TAG" then
      put byte 4 to -1 of t128 into sTagData
      put "11" into tType
      put "ID3V1.1" into sTagHead["type"]
      put 125 into sTagHead["size"]
    end if
  end if
  
  if tType is empty then return "notag"
  
  return tType
end i3getTagType

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

on i3readTag11
  put 0 into sFrameNum
  i3readFrame11 byte 1 to 30 of sTagData,"TIT2"
  i3readFrame11 byte 31 to 60 of sTagData,"TPE1"
  i3readFrame11 byte 61 to 90 of sTagData,"TALB"
  i3readFrame11 byte 91 to 94 of sTagData,"TYER"
  i3readFrame11 byte 95 to 124 of sTagData,"COMM"
  i3readFrame11 byte 123 to 124 of sTagData, "TRCK"
  i3readFrame11 byte 125 of sTagData,"TCON"
end i3readTag11

--==--==--==--==--==--==--

on i3readFrame11 pRawContent,pID
   put empty into tContent
   switch pID
      case "TIT2"
      case "TALB"
      case "TPE1"
      case "TYER"
         put pRawContent into tContent
         break
      case "COMM"
         get offset(null,pRawContent)
         if it > 0 then put char 1 to it-1 of pRawContent into tContent
         break
      case "TRCK"
         if char 1 of pRawContent is null then get bytetonum(char 2 of pRawContent)
         if it > 0 then put it into tContent
         break
      case "TCON"
         put id3_numToV1genre(bytetonum(pRawContent)) into tContent
   end switch
   
   replace null with empty in tContent
   put length(tContent) into tSize
   if tSize > 0 then
      add 1 to sFrameNum
      put pID into sFrameArray[sFrameNum,"id"]
      put tSize into sFrameArray[sFrameNum,"size"]
      put tContent into sFrameArray[sFrameNum,"content"]
   end if
end i3readFrame11

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

on i3readTag22 pFile
  open file pFile for binary read
  read from file pFile for 5
  put it into sRawTagHead
  read from file pFile for 1
  put i3getFlags(it) into sTagHead["flags"]
  put it after sRawTagHead
  read from file pFile for 4
  put i3readSyncSafeNum(it) into sTagHead["size"]
  put it after sRawTagHead
  put sTagHead["size"] into sTagDataSize
  
  read from file pFile for sTagDataSize
  put it into sTagData
  close file pFile
  
  i3getFrames22
end i3readTag22

--==--==--==--==--==--==--

on i3getFrames22
  put 0 into sFrameNum
  put the keys of sFrameDict into tKeys
  sort tKeys
  repeat for each line tID in tKeys
     
    if item 1 of sFrameDict[tID] then -- only one frame of this kind is allowed, so we take the first one found
      get offset(tID,sTagData)
      if it > 0 and not i3isInAnotherFrame(it) then
        i3getOneFrame22 it
      end if
    else
      put 0 into tOffset
      repeat
        get offset(tID,sTagData,tOffset)
        if it > 0 then
          add it to tOffset
          if not i3isInAnotherFrame(tOffset) then 
            i3getOneFrame22 tOffset
          end if
        else
          exit repeat
        end if
      end repeat
    end if
  end repeat
   
end i3getFrames22

--==--==--==--==--==--==--

on i3getOneFrame22 pOffset
  put char pOffset to pOffset + 2 of sTagData into tID
  put i3translateTo23(tID) into tID
  
  put i3getUint(char pOffset + 3 to pOffset + 5 of sTagData) into tSize
  
  if tSize > 0 and tSize + 5 + pOffset <= sTagDataSize then
    add 1 to sFrameNum
    put pOffset into sFrameArray[sFrameNum,"offset"]
    
    put tID into sFrameArray[sFrameNum,"id"]
    put tSize into sFrameArray[sFrameNum,"size"]
     
    put char pOffset + 6 to pOffset + tSize + 5 of sTagData into tRawContent
    if char 1 of sTagHead["flags"] is "1" then put i3unUnSync(tRawContent) into tRawContent
    
    put i3decodeContent23(tRawContent,tID) into sFrameArray[sFrameNum,"content"]
  end if
  
  return tSize
end i3getOneFrame22

--==--==--==--==--==--==--

function i3translateTo23 pID
  get item 2 of sFrameDict[pID]
  if it is empty then return pID
  return it
end i3translateTo23

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

on i3readTag23 pFile
   open file pFile for binary read
   get the result
   if it is not empty then i3setError "i3readTag23 : file error : " & it
   
   -- we've already dealt with the tag type
   read from file pFile for 5
   put it into sRawTagHead
   
   -- get the header flags
   read from file pFile for 1
   put i3getFlags(it) into sTagHead["flags"]
   put it after sRawTagHead
   
   -- get the tag size
   read from file pFile for 4
   put i3readSyncSafeNum(it) into sTagHead["size"]
   put it after sRawTagHead
   
   -- if extended header present
   if char 2 of sTagHead["flags"] is "1" then
      
      -- get size of extended header - should be 6 or 10
      read from file pFile for 4
      put i3readSyncSafeNum(it) into tExtendedSize
      read from file pFile for tExtendedSize
      
      -- calculate size of all frame data + padding
      put sTagHead["size"] - tExtendedSize into sTagDataSize
   else
      put sTagHead["size"] into sTagDataSize
   end if
   
   -- store all frame data and padding
   read from file pFile for sTagDataSize
   put it into sTagData
   
   close file pFile
   i3clearError
   i3getFrames23
end i3readTag23

--==--==--==--==--==--==--

on i3getFrames23
  put 0 into sFrameNum
  put the keys of sFrameDict into tKeys
  sort tKeys
  repeat for each line tID in tKeys
    
    if item 1 of sFrameDict[tID] then -- only one frame of this kind is allowed, so we take the first one found
      get offset(tID,sTagData)
      if it > 0 and not i3isInAnotherFrame(it) then
        i3getOneFrame23 it
      end if
    else
      put 0 into tOffset
      repeat
        get offset(tID,sTagData,tOffset)
        if it > 0 then
          add it to tOffset
          if not i3isInAnotherFrame(tOffset) then
            i3getOneFrame23 tOffset
          end if
        else
          exit repeat
        end if
      end repeat
    end if
  end repeat
   
end i3getFrames23

--==--==--==--==--==--==--

on i3getOneFrame23 pOffset
  put char pOffset to pOffset + 3 of sTagData into tID
  
  put (i3getShortTagType() = 24) into t24
  if t24 then put i3translateTo23(tID) into tID
  
  
  put i3readSyncSafeNum(char pOffset + 4 to pOffset + 7 of sTagData) into tSize
  if t24 then put i3checkSyncSafeSize(pOffset,tSize) into tSize -- this is to cope with iTunes imbecilic implementation of 2.4
  
  put pOffset & comma & pOffset + tSize + 9 & cr after sFrameOffsets
  
  if tSize > 0 and tSize + 9 + pOffset <= sTagDataSize then
    add 1 to sFrameNum
    put pOffset into sFrameArray[sFrameNum,"offset"]
    put i3getFlags(char pOffset + 8 to pOffset + 9 of sTagData) into tFlags
    
    put tID into sFrameArray[sFrameNum,"id"]
    put tSize into sFrameArray[sFrameNum,"size"]
    put tFlags into sFrameArray[sFrameNum,"flags"]
    
    put char pOffset + 10 to pOffset + tSize + 9 of sTagData into tRawContent
     
    if t24 then
      if char 1 of sTagHead["flags"] is "1" or char 15 of tFlags is "1" then
        put i3unUnSync(tRawContent) into tRawContent
      end if
    else
      if char 1 of sTagHead["flags"] is "1" then put i3unUnSync(tRawContent) into tRawContent
      if char 9 of tFlags is "1" then
        put tRawContent into sFrameArray[sFrameNum,"compressedContent"]
        put "compressed data:" & tRawContent into tContent
      end if
    end if
     
    if char 10 of tFlags is "1" then
      put tRawContent into sFrameArray[sFrameNum,"encryptedContent"]
      put "encrypted data:" & tRawContent into tContent
    end if
     
    if char 9 to 10 of tFlags is "00" then
      put i3decodeContent23(tRawContent,tID) into tContent
    end if
     
    if tContent is "!<discard>!" or tContent is empty then 
      id3_deleteFrame sFrameNum
      subtract 1 from sFrameNum
    else
      put tContent into sFrameArray[sFrameNum,"content"]
      put sFrameNum & comma after sFrameIndex[tID]
    end if
     
  end if
end i3getOneFrame23

--==--==--==--==--==--==--

function i3checkSyncSafeSize pOffset,pSize
  put pOffset + 10 + pSize into stChar
  put byte stChar to stChar + 3 of sTagData into tNextID
  if tNextID is in the frameDictionary24 of me then return pSize
  if byte 1 of tNextID is null then return pSize
  return i3getUint(byte pOffset+4 to pOffset+7 of sTagData)
end i3checkSyncSafeSize

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

on i3readTag24 pFile
  open file pFile for binary read
  
  read from file pFile for 5
  put it into sRawTagHead
  
  read from file pFile for 1
  put i3getFlags(it) into sTagHead["flags"]
  put it after sRawTagHead
  
  read from file pFile for 4
  put i3readSyncSafeNum(it) into sTagHead["size"]
  put it after sRawTagHead
  
  if byte 2 of sTagHead["flags"] is "1" then
    
    read from file pFile for 4
    put i3readSyncSafeNum(it) into tExtendedSize
    read from file pFile for tExtendedSize
    
    put sTagHead["size"] - tExtendedSize into sTagDataSize
  else
    put sTagHead["size"] into sTagDataSize
  end if
  
  read from file pFile for sTagDataSize
  put it into sTagData
  
  close file pFile
  i3getFrames24
end i3readTag24

--==--==--==--==--==--==--

on i3getFrames24
  put 0 into sFrameNum
  put the keys of sFrameDict into tKeys
  sort tKeys
  repeat for each line tID in tKeys
    
    if item 1 of sFrameDict[tID] then -- only one frame of this kind is allowed, so we take the first one found
      get offset(tID,sTagData)
      if it > 0 and not i3isInAnotherFrame(it) then
        i3getOneFrame23 it
      end if
    else
      put 0 into tOffset
      repeat
        get offset(tID,sTagData,tOffset)
        if it > 0 then
          add it to tOffset
          if not i3isInAnotherFrame(tOffset) then
            i3getOneFrame23 tOffset
          end if
        else
          exit repeat
        end if
      end repeat
    end if
  end repeat
   
end i3getFrames24

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

function i3decodeContent23 pRawContent, pID
  
  switch pID
  case "USLT"
    return i3readUsltFrameXX(pRawContent)
    break
  case "PCNT"
    return i3getUint(pRawContent)
    break
  case "TCON"
    return i3readTconFrameXX(pRawContent)
    break
  case "TLAN"
    return i3readTlanFrameXX(pRawContent)
    break
  case "APIC"
    return i3readApicFrameXX(pRawContent)
    break
  case "COMM"
    return i3readCommFrameXX(pRawContent)
    break
  case "IPLS"
  case "TIPL"
  case "TMCL"
    return i3readIplsFrameXX(pRawContent)
    break
  end switch
  
  if byte 1 of pID is in "TW" then
    if pID is among the items of "TXXX,WXXX" then
      return i3readTxxxFrameXX(pRawContent, pID)
    else
      return i3readTextFrameXX(pRawContent, pID)
    end if
  end if
  
  return pRawContent
end i3decodeContent23

--==--==--==--==--==--==--

function i3readTextFrameXX pContent
  put 1 into curPos
  put 0 into tEncoding
  get bytetonum(byte curPos of pContent)
  if it < 5 then
    put it into tEncoding
    add 1 to curPos
  end if
  put tEncoding into sFrameArray[sFrameNum,"encoding"]
  return i3readFrameText(byte curPos to -1 of pContent, tEncoding)
end i3readTextFrameXX

--==--==--==--==--==--==--

function i3readTxxxFrameXX pContent, pID
  put 1 into curPos
  put 0 into tEncoding
  get bytetonum(byte curPos of pContent)
  if it < 5 then
    put it into tEncoding
    add 1 to curPos
  end if
  if pID is "WXXX" then put 0 into tEncoding
  
  put i3upToNull(pContent, curPos, tEncoding) into curEnd
  if curEnd >= pEnd or curEnd = curPos then
    put PT_U8("no description " & sFrameNum) into tDesc
  else
    put i3readFrameText(byte curPos to curEnd of pContent) into tDesc
  end if
  
  put curEnd into curPos
  put i3readFrameText(byte curPos to -1 of pContent) into tText
  
  put tDesc into  sFrameArray[sFrameNum,"description"]
  put tText into sFrameArray[sFrameNum,"text"]
  put tEncoding into sFrameArray[sFrameNum,"encoding"]
  
  return tDesc & ":" & tText
end i3readTxxxFrameXX

--==--==--==--==--==--==--

function i3readApicFrameXX pContent
  put 1 into curPos
  put bytetonum(byte curPos of pContent) into tEncoding
  add 1 to curPos
  
  put i3upToNull(pContent, curPos, 0) into curEnd
  put i3readFrameText(byte curPos to curEnd of pContent, 0) into tMimeType
  replace "jpg" with "jpeg" in tMimeType
  put curEnd + 1 into curPos
  
  put bytetonum(byte curPos of pContent) into tPicType
  add 1 to curPos
  
  put i3upToNull(pContent, curPos, tEncoding) into curEnd
  put i3readFrameText(byte curPos to curEnd of pContent, tEncoding) into tDesc
  put curEnd + 1 into curPos
  
  put byte curPos to -1 of pContent into tPicData
  
  put tEncoding into sFrameArray[sFrameNum,"encoding"]
  put tMimeType into sFrameArray[sFrameNum,"mimetype"]
  put tPicType into sFrameArray[sFrameNum,"pictype"]
  put tDesc into sFrameArray[sFrameNum,"description"]
  put tPicData into sFrameArray[sFrameNum,"picdata"]
  i3checkPic
  
  return tMimeType & ":" & tPicType & " - " & tPicType & ":" & tDesc
end i3readApicFrameXX

--==--==--==--==--==--==--

on i3checkPic
   
   put empty into tEndString
   if "jpeg" is in sFrameArray[sFrameNum,"mimetype"] then
      if byte -2 to -1 of sFrameArray[sFrameNum,"picdata"] is not the jfifEnd of me then 
         put the jfifEnd of me into tEndString
         put the jfifStart of me into tStartString
      end if
   else if "png" is in sFrameArray[sFrameNum,"mimetype"] then
      if byte -8 to -1 of sFrameArray[sFrameNum,"picdata"] is not the pngEnd of me then 
         put the pngEnd of me into tEndString
         put the pngStart of me into tStartString
      end if
   end if
   
   if tEndString is empty then exit i3checkPic
   
   put sFrameArray[sFrameNum,"offset"] into curPos
   get offset(tStartString, sTagData, curPos)
   if it = 0 then exit i3checkPic
   put curPos + it into tStart
   
   get offset(tEndString, sTagData, curPos)
   if it = 0 then exit i3checkPic
   put it + curPos + length(tEndString) - 1 into tEnd
   put byte tStart to tEnd of sTagData into tPicData
   
   if byte 1 of sTagHead["flags"] is "1" then put i3unUnSync(tPicData) into tPicData
   put tPicData into sFrameArray[sFrameNum,"picdata"]
   get offset(tStartString, tPicData)
   if it > 1 then delete byte 1 to it -1 of tPicData
   
   put length(tPicData) & ",>>" before sFrameArray[sFrameNum,"size"]
end i3checkPic  

--==--==--==--==--==--==--

function i3readCommFrameXX pContent
  put 1 into curPos
  put bytetonum(byte curPos of pContent) into tEncoding
  add 1 to curPos
  
  put byte curPos to curPos + 2 of pContent into tl
  if id3_isoToLang(tl) is not empty then
    put tl into tLang
    add 3 to curPos
  else
    put "XXX" into tLang
  end if
  
  put i3upToNull(pContent, curPos, tEncoding) into curEnd
  put i3readFrameText(byte curPos to curEnd of pContent, tEncoding) into tDesc
  
  put curEnd + 1 into curPos
  put i3readFrameText(byte curPos to -1 of pContent, tEncoding) into tComment
  
  if "iTunSMPB" is in tDesc then return "!<discard>!"
  if not i3commIsUnique(tLang,tDesc) then return "!<discard>!"
  
  put tEncoding into sFrameArray[sFrameNum,"encoding"]
  put tLang into sFrameArray[sFrameNum,"language"]
  put tDesc into sFrameArray[sFrameNum,"description"]
  put tComment into sFrameArray[sFrameNum,"data"]
  return tLang & ":" & tDesc & ":" & tComment
end i3readCommFrameXX

--==--==--==--==--==--==--

function i3readTconFrameXX pContent
  put i3readTextFrameXX(pContent) into tContent
  
  replace "(" with numtochar(4) in tContent
  replace ")" with numtochar(4) in tContent
  set the itemdelimiter to numtochar(4)
  repeat with n = 2 to the number of items in tContent
    if item n of tContent is an integer then
      put id3_numToV1genre(item n of tContent) into item n of tContent
    end if
  end repeat
  replace numtochar(4) with comma in tContent
  if byte 1 of tContent is comma then delete byte 1 of tContent
  if byte -1 of tContent is comma then delete byte -1 of tContent
  
  split tContent by comma and numtochar(4)
  put the keys of tContent into tList
  replace cr with comma in tList
  
  return tList
end i3readTconFrameXX

--==--==--==--==--==--==--

function i3readIplsFrameXX pContent
  put 1 into curPos
  get bytetonum(byte curPos of pContent)
  if it < 5 then
    put it into tEncoding
    add 1 to curPos
  else
    put 0 into tEncoding
  end if
  
  put byte curPos to -1 of pContent into tContent
  
  if tEncoding = 0 or tEncoding = 3 then
    replace null with cr in tContent
  else
    replace null & null with cr in tContent
  end if
  filter tContent without empty
  repeat with n = 1 to the number of lines in tContent step 2
    if line n of tContent is not empty then
      put i3readFrameText(line n of tContent, tEncoding) & "=" after tList
      put i3readFrameText(line n+1 of tContent, tEncoding) & cr after tList
    end if
  end repeat
  delete byte -1 of tList
  return tList
end i3readIplsFrameXX

--==--==--==--==--==--==--

function i3readUfidFrameXX pContent
  put 1 into curPos
  put i3upToNull(pContent, curPos, 0) into curEnd
  put i3readFrameText(byte curPos to curEnd of pContent) into ownerID
  put curEnd + 1 into curPos
  put byte curPos  to -1 of pContent into tIdentifier
  
  put ownerID into sFrameArray[sFrameNum,"ownerIdentifier"]
  put tIdentifier into sFrameArray[sFrameNum,"identifier"]
  
  return ownerID & ":" & tIdentifier
end i3readUfidFrameXX

--==--==--==--==--==--==--

function i3readTlanFrameXX pContent
  put 1 into curPos
  put byte curPos to -1 of pContent into tContent
  replace null with comma in tContent
  repeat for each item i in tContent
    if i is empty then next repeat
    put i & comma after tLanguages
  end repeat
  if byte -1 of tLanguages is comma then delete byte -1 of tLanguages
  return tLanguages
end i3readTlanFrameXX

--==--==--==--==--==--==--

function i3readUsltFrameXX pContent
  put 1 into curPos
  put bytetonum(byte curPos of pContent) into tEncoding
  add 1 to curPos
  
  put byte curPos to curPos + 2 of pContent into tl
  if id3_isoToLang(tl) is not empty then
    put tl into tLang
    add 3 to curPos
  else
    put "XXX" into tLang
  end if
  
  put i3upToNull(pContent, curPos, tEncoding) into curEnd
  put i3readFrameText(byte curPos to curEnd of pContent, tEncoding) into tDesc
  
  put curEnd + 1 into curPos
  put i3readFrameText(byte curPos to -1 of pContent, tEncoding) into tLyric
  
  put tEncoding into sFrameArray[sFrameNum,"encoding"]
  put tLang into sFrameArray[sFrameNum,"language"]
  put tDesc into sFrameArray[sFrameNum,"description"]
  put tLyric into sFrameArray[sFrameNum,"data"]
  return tLang & ":" & tDesc & ":" & byte 1 to 21 of tLyric & "..."
end i3readUsltFrameXX

--==--==--==--==--==--==--

function i3upToNull @pContent, pStart, pEncoding
  if byte pStart of pContent is null then return pStart
  if pEncoding is empty or pEncoding is 0 or pEncoding is 3 then
    
    get offset(null, pContent, pStart)
    put it + pStart into tEnd
  else
    get offset(null & null, pContent, pStart)
    put it + 1 + pStart into tEnd
    if byte tEnd + 1 of pContent is null then add 1 to tEnd
  end if
  return tEnd
end i3upToNull

--==--==--==--==--==--==--

function i3readFrameText pRawText, pEncoding
  switch pEncoding
  case 4 -- UTF16LE
    put U16_U8(pRawText,"LE") into tText
    break
  case 3 --UTF8
    replace null with empty in pRawText
    put pRawText into tText
    break
  case 1 -- UTF16 with BOM
    put U16_U8(pRawText,"BOM") into tText
    break
  case 2 -- UTF16BE
    put U16_U8(pRawText,"BE") into tText
    break
  case 0 -- ISO-8859-1
  default -- no encoding, assume ISO-8859-1
    if the platform is "MacOS" then put isotomac(pRawText) into pRawText
    replace null with empty in pRawText
    put PT_U8(pRawText) into tText
    break
  end switch
  
  return tText
end i3readFrameText

--==--==--==--==--==--==--

function i3commIsUnique pLang,pDesc,pFrameNum
  if pFrameNum is empty then put sFrameNum into pFrameNum
  repeat for each item i in sFrameIndex["COMM"]
    if i >= pFrameNum then exit repeat
    if sFrameArray[i,"language"] is pLang and sFrameArray[i,"description"] is pDesc then return false
  end repeat
  return true
end i3commIsUnique

--==--==--==--==--==--==--

function i3txxxIsUnique pDesc
  repeat for each item i in sFrameIndex["TXXX"]
    if sFrameArray[i,"description"] is pDesc then return i
  end repeat
  return 0
end i3txxxIsUnique

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

on i3readTagM4 pFile
  open file pFile for binary read
  read from file pFile until "meta"
  read from file pFile until "mdat"
  put it into sTagData
  close file pFile
  put length(sTagData) into sTagDataSize
  put sTagDataSize into sTagHead["size"]
   
  repeat for each line L in the keys of sFrameDict
    get offset(L,sTagData)
    if it > 0 then i3getOneFrameM4 it
  end repeat
end i3readTagM4

--==--==--==--==--==--==--

on i3getOneFrameM4 pOffset
  add 1 to sFrameNum
  
  put byte pOffset to pOffset + 3 of sTagData into tID
  put i3getUint(byte pOffset + 4 to pOffset + 7 of sTagData) into tSize
  put pOffset & comma & pOffset + tSize + 7 & cr after sFrameOffsets
  
  put i3decodeM4(byte pOffset + 20 to pOffset + 4 + tSize -1 of sTagData,tID) into tContent
  put i3translateTo23(tID) into sFrameArray[sFrameNum,"id"]
  put tSize into sFrameArray[sFrameNum,"size"]
  put tContent into sFrameArray[sFrameNum,"content"]
  put pOffset into sFrameArray[sFrameNum,"offset"]
end i3getOneFrameM4

--==--==--==--==--==--==--

function i3decodeM4 pContent,pID
  switch pID
  case "covr"
    return i3readCovrFrameM4(pContent)
    break
  case "tmpo"
    get i3getUint(pContent)
    if it > 0 then return it
    return empty
    break
  case "gnre"
    return id3_numToV1genre(i3getUint(byte 1 to 4 of pContent) - 1)
    break
  case "trkn"
  case "disk"
    put byte 1 to 4 of pContent into num1
    put byte 5 to 6 of pContent into num2
    return i3getUint(num1)  & "/" & i3getUint(num2)
    break
  case "©lyr"
    if "Mac" is in the platform then replace numtochar(13) with cr in pContent
    put pContent into sFrameArray[sFrameNum,"text"]
    put "?" into sFrameArray[sFrameNum,"language"]
    return "?" & ":" & byte 1 to 21 of pContent & "..."
    break
  case "©cmt"
    put "?" into sFrameArray[sFrameNum,"language"]
    put empty into sFrameArray[sFrameNum,"description"]
    put pContent into sFrameArray[sFrameNum,"comment"]
    return "?::" & pContent
    break
  default
    return pContent
    break
  end switch
end i3decodeM4

--==--==--==--==--==--==--

function i3readCovrFrameM4 @pContent
   put byte 1 to 64 of pContent into p64 -- put char 1 to 256 of pContent into p64 -- this function is not finding some images
   if the jfifStart of me is in p64 or "JFIF" is in p64 or "Exif" is in p64 then -- or "ÿØÿè" is in p64 then --  ÿØÿè = the 'magic number'
      put "image/jpeg" into tMimeType
   else if the pngStart of me is in p64 or "PNG" is in p64 then
      put "image/png" into tMimeType
   else
      put "image/?" into tMimeType
   end if
   
   put "cover art" into sFrameArray[sFrameNum,"description"]
   put 3 into sFrameArray[sFrameNum,"pictype"]
   put tMimeType into sFrameArray[sFrameNum,"mimetype"]
   put pContent into sFrameArray[sFrameNum,"picdata"]
   return tMimeType & ":3-" & id3_numToPicType(3) &  ":cover art"
end i3readCovrFrameM4


--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

--------------------------------------
-- encodings--------------------------
--------------------------------------

function U16_U8 pString, pBOM
  if length(pString) mod 2 <> 0 and byte -1 of pString is null then delete byte -1 of pString
  if byte -2 to -1 of pString is null & null then delete byte -2 to -1 of pString
   
  put pBOM into tByteOrder
  if pBOM is "BOM" then
    put bytetonum(byte 1 of pString) into c1
    put bytetonum(byte 2 of pString) into c2
    if c1 + c2 = 509 then  -- if not 509, there's no BOM
      if c1 > c2 then
        put "LE" into tByteOrder
      else
        put "BE" into tByteOrder
      end if
      delete byte 1 to 2 of pString
    else
      put "BE" into tByteOrder -- assume unicode string is big-endian
    end if
  end if
   
  if (tByteOrder is "LE" and sBigEndian) or (tByteOrder is "BE" and not sBigEndian) then
    put i3reverseUnicode(pString) into pString
  end if
   
  return unidecode(pString,"UTF8")
end U16_U8

--==--==--==--==--==--==--

function i3reverseUnicode pString
  repeat with n = 1 to length(pString) step 2
    put byte n+1 of pString & byte n of pString after newString
  end repeat
  return newString
end i3reverseUnicode

--==--==--==--==--==--==--

function U8_U16 tU8str
  return uniencode(tU8str,"UTF8")
end U8_U16

--==--==--==--==--==--==--

function PT_U8 pString
  return unidecode(uniencode(pString),"UTF8")
end PT_U8

--==--==--==--==--==--==--

function U8_PT pString
  return unidecode(uniencode(pString,"UTF8"))
end U8_PT

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

---------------------------------
-- www.id3.org sync safe numbers
---------------------------------

function i3readSyncSafeNum fourBytes
  repeat 4 - length(fourbytes)
    put null before fourBytes
  end repeat
  
  put empty into tBits
  get binarydecode("B*",fourBytes,tBits)
  if byte 25 of tBits is "0" then
     
    delete byte 25 of tBits
    delete char 17 of tBits
    delete char 9 of tBits
    delete char 1 of tBits
  end if
  return baseconvert(tBits,2,10)
end i3readSyncSafeNum

--==--==--==--==--==--==--

function i3makeSyncSafeNum pNum, pLength
  if pLength is empty then put 4 into pLength
  put baseconvert(pNum,10,2) into tBits
  repeat 28 - length(tBits)
    put "0" before tBits
  end repeat
  put "0" before tBits
  put "0" after char 8 of tBits
  put "0" after char 16 of tBits
  put "0" after char 24 of tBits  
  
  put binaryencode("B*",tBits) into tNum
  return char (0-pLength) to -1 of tNum
end i3makeSyncSafeNum

--==--==--==--==--==--==--

function i3getUint pBytes
  put empty into tBits
  get binarydecode("B*",pBytes,tBits)
  
  if length(tBits) > 32 then
    put baseconvert(char -32 to -1 of tBits,2,10) into tLitNum
    put baseconvert(char 1 to 32 of tBits,2,10) into tBigNum
    return tLitNum * (tBigNum + 1)
  else
    return baseconvert(tBits,2,10)
  end if
end i3getUint

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

----------------------------------------
-- www.id3.org unSynchronisation scheme
----------------------------------------

function i3unSync pBytes
  put "a" into pChar
  repeat for each byte c in pBytes
    add 1 to cc
    if bytetonum(pChar) = 255 and (bytetonum(c) >= 224 or c is null) then put null after newBytes
    put c after newBytes
    put c into pChar
  end repeat
  if bytetonum(char -1 of newBytes) = 255 then put null after newBytes
  return newBytes
end i3unSync

--==--==--==--==--==--==--

function i3unUnSync pBytes
  replace numtochar(255) & numtochar(0) with numtochar(255) in pBytes
  return pBytes
end i3unUnSync

--==--==--==--==--==--==--

function i3makeTagFlags pUnSync, pExtendHead, pExperiment
  put "00000000" into tFlags
  if pUnSync then put "1" into char 1 of tFlags
  if pExtendHead then put "1" into char 2 of tFlags
  if pExperiment then put "1" into char 3 of tFlags
  return numtochar(baseconvert(tFlags,2,10))
end i3makeTagFlags

--==--==--==--==--==--==--

function i3getFlags pBytes
  put empty into tBits
  get binarydecode("B*",pBytes,tBits)
  return tBits
end i3getFlags

--==--==--==--==--==--==--

function i3getFrameFlags pFrameNum
  return sFrameArray[pFrameNum,"flags"]
end i3getFrameFlags

--==--==--==--==--==--==--

function i3getTagFlags
  return sTagHead["flags"]
end i3getTagFlags

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

-----------
-- lookups
-----------

--iso language codes

function id3_isoToLang pIsoCode
  put the isoLanguageCodes of me into tCodes
  split tCodes by cr and "="
  get tCodes[pIsoCode]
  if it is empty then
    return "XXX"
  else
    return it
  end if
end id3_isoToLang

--==--==--==--==--==--==--

function id3_langToIso pLang
  set the itemdelimiter to "="
  repeat for each line L in the isoLanguageCodes of me
    if pLang is item 2 of L then return item 1 of L
  end repeat
  return "XXX"
end id3_langToIso

--==--==--==--==--==--==--

function id3_getIsoLanguageCodes
  return the isoLanguageCodes of me
end id3_getIsoLanguageCodes

--==--==--==--==--==--==--

--genres

function id3_numToV1genre pNum
  set the itemdelimiter to "="
  return PT_U8(item 2 of line pNum + 1 of the v1Genres of me)
end id3_numToV1genre

--==--==--==--==--==--==--

function id3_v1GenreToNum pGenre
  set the itemdelimiter to "="
  repeat for each line L in the v1Genres of me
    if item 2 of L is pGenre then return item 1 of L
  end repeat
  return empty
end id3_v1GenreToNum

--==--==--==--==--==--==--

function id3_getGenreList
  set the itemdelimiter to "="
  repeat for each line L in the v1Genres of me
    put item 2 of L & cr after tList
  end repeat
  return byte 1 to -2 of tList
end id3_getGenreList

--==--==--==--==--==--==--

--picture types

function id3_numToPicType pNum
  return sPicTypes[pNum]
end id3_numToPicType

--==--==--==--==--==--==--

function id3_getPicTypes
  repeat with n = 0 to 21
    put sPicTypes[n] & cr after tTypes
  end repeat
  replace ",true" with empty in tTypes
  return byte 1 to -2 of tTypes
end id3_getPicTypes

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

--==--==--==--==--==--==--
--writing
--==--==--==--==--==--==--

on i3writeTag23
  if i3getShortTagType() is "M4" then return "can't write id3 tag to mp4 file"
  
  put i3orderFramesForWrite() into tFrameList
  
  repeat for each item n in tFrameList
    put sFrameArray[n,"id"] into tID
    if tID is empty then next repeat
    
    put i3makeFrameContent23(n) into tContent
    if tContent is empty or tContent is null or tContent is null & null then next repeat
    if sUnSync then put i3unSync(tContent) into tContent
     
    put i3makeSyncSafeNum(length(tContent)) into tSize
    put sFrameArray[n,"flags"] into tBFlags
    if tBFlags is empty then put "0000000000000000" into tBFlags
    put numtochar(baseconvert(byte 1 to 8 of tBFlags,2,10)) & numtochar(baseconvert(byte 9 to 16 of tBFlags,2,10)) into tFlags
    
    put tID & tSize & tFlags & tContent after tTag
  end repeat
  
  put length(tTag) + 10 into tTagSize
  put sTagHead["size"] + 10 into tTargetSize
  
  put 2048 into tPadSize
  put tTargetSize - tTagSize into tDiff
  if tDiff > 255 then put tDiff into tPadSize
  
  repeat tPadSize
    put null after tTag
  end repeat
  
  put i3makeSyncSafeNum(length(tTag)) into tTagSize
  put "00000000" into tTagBFlags
  if sUnSync then
    put "1" into char 1 of tTagBFlags
  else
    put "0" into char 1 of tTagBFlags
  end if
  put numtochar(baseconvert(tTagBFlags,2,10)) into tTagFlags
  
  put "ID3" & numtochar(3) & numtochar(0) & tTagFlags & tTagSize before tTag
  
  if length(tTag) > tTargetSize then
    i3writeFileComplete tTag,tTargetSize
  else
    i3writeFileTagOnly tTag
  end if
end i3writeTag23

--==--==--==--==--==--==--

function i3orderFramesForWrite
  put the frameDictionary23 of me into tDict
  set the itemdelimiter to "="
  repeat for each line L in tDict
    put item 1 of L & cr after tFrameList
  end repeat
  delete byte -1 of tFrameList
  set the itemdelimiter to ","
   
  put "UFID,TIT2,TIT1,TIT3,TALB,TPE1,TRCK,TYER,TPE2,TPE3,TPE4,IPLS," into tList1
  put "APIC,GEOB," into tList3
  
  repeat for each line L in tFrameList
    if (L is not among the items of tList1) and (L is not among the items of tList3) then
      put L & comma after tList2
    end if
  end repeat
  
  put tList1 & tList2 & tList3 into tFrameOrder
  
  repeat for each item i in tFrameOrder
    get sFrameIndex[i]
    if it is not empty then put it after tFrameNums
  end repeat
  
  return byte 1 to -2 of tFrameNums
end i3orderFramesForWrite

--==--==--==--==--==--==--

function i3padNullsAtEnd pString, pLength
  repeat pLength - length(pString)
    put null after pString
  end repeat
  return pString
end i3padNullsAtEnd

--==--==--==--==--==--==--

on i3writeFileComplete pTag,pTargetSize
  set the filetype to "hookMPG3"
  put URL ("binfile:" & sFilePath) into tFileData
  delete byte 1 to pTargetSize of tFileData
  put pTag & tFileData into URL ("binfile:" & sFilePath)
end i3writeFileComplete

--==--==--==--==--==--==--

on i3writeFileTagOnly pTag
  set the filetype to "hookMPG3"
  open file sFilePath for binary update
  write pTag to file sFilePath
  close file sFilePath
end i3writeFileTagOnly

--==--==--==--==--==--==--

on i3deleteV1tag
  set the filetype to "hookMPG3"
  put URL ("binfile:" & sFilePath) into tFileData
  delete byte -128 to -1 of tFileData
  put tFileData into URL ("binfile:" & sFilePath)
end i3deleteV1tag

--==--==--==--==--==--==--

function i3makeFrameContent23 pFrameNum
  put sFrameArray[pFrameNum,"id"] into tID
  switch tID
  case "APIC"
    return i3makeApicFrame23(pFrameNum)
    break
  case "COMM"
  case "USLT"
    return i3makeCommFrame23(pFrameNum)
    break
  case "IPLS"
    return i3makeIplsFrame23(pFrameNum)
    break
  end switch
  
  if char 1 of tID is in "TW" then
    if tID is among the items of "TXXX,WXXX" then
      return i3makeTxxxFrame23(pFrameNum,tID)
    else
      return i3makeTextFrame23(pFrameNum)
    end if
  end if
  
  return sFrameArray[pFrameNum,"content"]
end i3makeFrameContent23

--==--==--==--==--==--==--

function i3makeTextFrame23 pFrameNum
  return numtochar(sFrameArray[pFrameNum,"encoding"]) & i3encodeString(sFrameArray[pFrameNum,"content"],sFrameArray[pFrameNum,"encoding"])
end i3makeTextFrame23

--==--==--==--==--==--==--

function i3makeTxxxFrame23 pFrameNum, pID
  put sFrameArray[pFrameNum,"description"] into tDesc
  put sFrameArray[pFrameNum,"text"] into tText
  if tText is empty then return empty
  
  put sFrameArray[pFrameNum,"encoding"] into tEncoding
  put numtochar(tEncoding) into tFrame
  put i3encodeString(tDesc,tEncoding) after tFrame
  if pID is "TXXX" then
    put i3encodeString(tText,tEncoding) after tFrame
  else
    put i3encodeString(tText,0) after tFrame
  end if
   
  return tFrame
end i3makeTxxxFrame23

--==--==--==--==--==--==--

function i3makeCommFrame23 pFrameNum
  get sFrameArray[pFrameNum,"content"] 
  if it is empty then return empty
  if "<private>" is in it then return sFrameArray[pFrameNum,"data"]
  
  put sFrameArray[pFrameNum,"language"] into tLang
  put sFrameArray[pFrameNum,"description"] into tDesc
  put sFrameArray[pFrameNum,"data"] into tData
  if tData is empty then return empty
  if not i3commIsUnique(tLang,tDesc,pFrameNum) then return empty
  
  get sFrameArray[pFrameNum,"encoding"]
  if it = 0 or it is empty then
    put null & tLang & i3encodeString(tDesc,0) & i3encodeString(tData,0) into tFrame
  else
    put numtochar(1) & tLang into tFrame
    put i3encodeString(tDesc,1) & i3encodeString(tData,1) after tFrame
  end if
  return tFrame
end i3makeCommFrame23

--==--==--==--==--==--==--

function i3makeApicFrame23 pFrameNum
  put sFrameArray[pFrameNum,"encoding"] into tEncoding
  
  put i3encodeString(sFrameArray[pFrameNum,"mimetype"],0) into tMimeType
  if tMimeType is empty then put "image/" into tMimeType
  
  put numtochar(sFrameArray[pFrameNum,"pictype"]) into tPicType
  if tPictype is empty then put null into tPicType
  
  put i3encodeString(sFrameArray[pFrameNum,"description"],tEncoding) into tDescription
  
  put numtochar(tEncoding) & tMimeType & null & tPicType & tDescription into tFrame
  put sFrameArray[pFrameNum,"picdata"] after tFrame
  return tFrame
end i3makeApicFrame23

--==--==--==--==--==--==--

function i3makeIplsFrame23 pFrameNum
  put sFrameArray[pFrameNum,"content"] into tContent
  put sFrameArray[pFrameNum,"encoding"] into tEncoding
  put numtochar(tEncoding) into tFrame
  set the itemdelimiter to "="
  repeat for each line L in tContent
    repeat for each item i in L
      put i3encodeString(i,tEncoding) after tFrame
    end repeat
  end repeat
  return tFrame
end i3makeIplsFrame23

--==--==--==--==--==--==--

function i3encodeString pString, pEncoding
  switch pEncoding
  case 0
  case empty
    put U8_PT(pString) into tString
    if "Mac" is in the platform then put mactoiso(tString) into tString
    return tString & null
    break
  case 1
    put uniencode(pString,"UTF8") into tStr
    put sBOM & tStr & null & null into tString
    break
  case 2
  case 4
    put uniencode(pString,"UTF8") & null & null into tString
    break
  case 3
    put pString & null into tString
    break
  end switch
  return tString
end i3encodeString

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

-------------
-- interface
-------------

--defaults to using unSync

on id3_useUnSync
  put true into sUnSync
end id3_useUnSync

on id3_dontUseUnSync
  put false into sUnSync
end id3_dontUseUnSync

function id3_usingUnSync
  return sUnSync
end id3_usingUnSync

--==--==--==--==--==--==--

function i3createFrame pID
  if sFrameIndex[pID] is not empty and item 1 of sFrameDict[pID] then
    return item 1 of sFrameIndex[pID]
  else
    add 1 to sFrameNum
    put pID into sFrameArray[sFrameNum,"id"]
    put "0000000000000000" into sFrameArray[sFrameNum,"flags"]
    put sFrameNum & comma after sFrameIndex[pID]
    return sFrameNum
  end if
end i3createFrame

function i3CreateApicFrame pType --- <-- did Mark not finish routines for writing picture data?
   --  ??? --
end i3CreateApicFrame

--==--==--==--==--==--==--
--> interface


on id3_setFile pFile
  if pFile is empty then return "no file specified"
  i3setFile pFile
  return the result
end id3_setFile

on id3_updateFile
  i3writeTag23
end id3_updateFile

--==--==--==--==--==--==--

function id3_IsUnicode
  return sIsUnicode
end id3_IsUnicode

--==--==--==--==--==--==--

function i3getSimpleFrame pID
  put item 1 of sFrameIndex[pID] into tFrameNum
  get sFrameArray[tFrameNum,"content"]
  if sFrameArray[tFrameNum,"encoding"] = 1 then
    put true into sIsUnicode
    return U8_U16(it)
  else
    put false into sisUnicode
    return U8_PT(it)
  end if
end i3getSimpleFrame

--==--==--==--==--==--==--

function id3_getTextFrame pFrameID
  return i3getSimpleFrame(pFrameID)
end id3_getTextFrame

on id3_setTextFrame pFrameID, pText, pUnicode
  put i3createFrame(pFrameID) into tFrameNum
  if pUnicode then
    put 1 into sFrameArray[tFrameNum,"encoding"]
    put U16_U8(pText) into sFrameArray[tFrameNum,"content"]
  else
    put 0 into sFrameArray[tFrameNum,"encoding"]
    put PT_U8(pText) into sFrameArray[tFrameNum,"content"]
  end if
end id3_setTextFrame

--==--==--==--==--==--==--

function id3_getTitle
  return i3getSimpleFrame("TIT2")
end id3_getTitle

on id3_setTitle pString, pUnicode
  id3_setTextFrame "TIT2", pString, pUnicode
end id3_setTitle

--==--==--==--==--==--==--

function id3_getGrouping
  return i3getSimpleFrame("TIT1")
end id3_getGrouping

on id3_setGrouping pString, pUnicode
  id3_setTextFrame "TIT1", pString, pUnicode
end id3_setGrouping

--==--==--==--==--==--==--

function id3_getAlbum
  return i3getSimpleFrame("TALB")
end id3_getAlbum

on id3_setAlbum pString, pUnicode
  id3_setTextFrame "TALB", pString, pUnicode
end id3_setAlbum

--==--==--==--==--==--==--

function id3_getArtist
  return i3getSimpleFrame("TPE1")
end id3_getArtist

on id3_setArtist pString
  id3_setTextFrame "TPE1", pString, pUnicode
end id3_setArtist

--==--==--==--==--==--==--

function id3_getTrackNumber
  return i3getSimpleFrame("TRCK")
end id3_getTrackNumber

on id3_setTrackNumber pString
  put i3createFrame("TRCK") into tFrameNum
  put PT_U8(pString) into sFrameArray[tFrameNum,"content"]
end id3_setTrackNumber

--==--==--==--==--==--==--

function id3_getDiskNumber
 return i3getSimpleFrame("TPOS")
end id3_getDiskNumber

function id3_getDiscNumber
  return i3getSimpleFrame("TPOS")
end id3_getDiscNumber

on id3_setDiskNumber pString
  id3_setDiscNumber pString
end id3_setDiskNumber

on id3_setDiscNumber pString
  put i3createFrame("TPOS") into tFrameNum
  put PT_U8(pString) into sFrameArray[tFrameNum,"content"]
end id3_setDiscNumber

--==--==--==--==--==--==--

function id3_getDate
  if i3getShortTagType() is "24" then
    return byte 1 to 4 of i3getSimpleFrame("TDRC")
  else
    return i3getSimpleFrame("TYER")
  end if
end id3_getDate

function id3_getYear
     return char 1 to 8 of id3_getDate() -- Unicode Fix!
  -- return char 1 to 4 of id3_getDate()
end id3_getYear

on id3_setDate pString
  put i3createFrame("TYER") into tFrameNum
  put PT_U8(pString) into sFrameArray[tFrameNum,"content"]
end id3_setDate

on id3_setYear pString
  id3_setDate pString
end id3_setYear

--==--==--==--==--==--==--

function id3_getGenre
  return i3getSimpleFrame("TCON")
end id3_getGenre

on id3_setGenre pData
  get id3_v1GenreToNum(pData)
  if it is not empty then put "(" & it & ")" into pData
  put i3createFrame("TCON") into tFrameNum
  put PT_U8(pData) into sFrameArray[tFrameNum,"content"]
end id3_setGenre

--==--==--==--==--==--==--

function id3_getComposer
 return i3getSimpleFrame("TCOM")
end id3_getComposer

on id3_setComposer pString, pUnicode
  id3_setTextFrame "TCOM", pString, pUnicode
end id3_setComposer

--==--==--==--==--==--==--

function id3_getLyricist
  return i3getSimpleFrame("TEXT")
end id3_getLyricist

on id3_setLyricist pString, pUnicode
  id3_setTextFrame "TEXT", pString, pUnicode
end id3_setLyricist

--==--==--==--==--==--==--

function id3_getLyric
  put item 1 of sFrameIndex["USLT"] into tFrameNum
  
  put sFrameArray[tFrameNum,"language"] & cr into tContent
  put sFrameArray[tFrameNum,"description"] & cr after tContent
  put sFrameArray[tFrameNum,"data"] after tContent
  return tContent
end id3_getLyric

on id3_setLyric pLang, pDesc, pLyric
  put i3createFrame("USLT") into tFrameNum
  put pLang into sFrameArray[tFrameNum,"language"]
  put pDesc into sFrameArray[tFrameNum,"description"]
  replace numtochar(13) with numtochar(10) in pLyric
  put pLyric into sFrameArray[tFrameNum,"data"]
  put pLang & ":" & pDesc & ":" & line 1 of pLyric into sFrameArray[tFrameNum,"content"]
end id3_setLyric

--==--==--==--==--==--==--

function id3_getPictureFrameNums
  return byte 1 to -2 of sFrameIndex["APIC"]
end id3_getPictureFrameNums

function id3_getNumberOfPictures
  return the number of items in byte 1 to -2 of sFrameIndex["APIC"]
end id3_getNumberOfPictures

function id3_getPictureData pPicNum
  put item pPicNum of sFrameIndex["APIC"] into pFrameNum
  return sFrameArray[pFrameNum,"picdata"]
end id3_getPictureData

function id3_getPictureFormat pPicNum
  put item pPicNum of sFrameIndex["APIC"] into pFrameNum
  return sFrameArray[pFrameNum,"mimetype"]
end id3_getPictureFormat

function id3_getPictureID3Type pPicNum
  put item pPicNum of sFrameIndex["APIC"] into pFrameNum
  get sFrameArray[pFrameNum,"pictype"]
  if it is empty then get 0
  return id3_numToPicType(it)
end id3_getPictureID3Type

function id3_getPictureDataByType pType
    repeat for each item i in sFrameIndex["APIC"]
        if sFrameArray[i,"pictype"] = pType then return sFrameArray[i,"picdata"] 
    end repeat
    return empty
end id3_getPictureDataByType


on id3_setPictureFromImageText pImageText, pId3Type, pDesc, pMimeType
   if byte 1 to 2 of tImageText is the jfifStart of me then put "jpeg" into pMimeType
   if byte 1 to 8 of tImageText is the pngStart of me then put "png" into pMimeType
end id3_setPictureFromImageText

on id3_setPictureFromFile pImageFile, pId3Type, pDesc, pMimeType
   if there is no file pImageFile then 
      return "file doesn't exist"
   else
      put URL ("binfile:" & pImageFile) into tImageText
      id3_setPictureFromImageText tImageText, pId3Type, pDesc, pMimeType
   end if
end id3_setPictureFromFile

on id3_setPictureFromImageID pImageID, pId3Type, pDesc, pMimeType
   -- put the imageData of image pImageID into tImageText
   put the text of image pImageID into tImageText
   id3_setPictureFromImageText tImageText, pId3Type, pDesc, pMimeType
end id3_setPictureFromImageID

--==--==--==--==--==--==--

function id3_getCommentList
  return byte 1 to -2 of sFrameIndex["COMM"]
end id3_getCommentList

function id3_getAllCommentData
  repeat for each item i in id3_getCommentList()
    add 1 to tCount
    put sFrameArray[i,"language"] into tCommentArray[i,"language"]
    put sFrameArray[i,"description"] into tCommentArray[i,"description"]
    put sFrameArray[i,"data"] into tCommentArray[i,"data"]
  end repeat
  return tCommentArray
end id3_getAllCommentData

function id3_getComment pFrameNum, pField
  if pFrameNum is empty then put item 1 of sFrameIndex["COMM"] into pFrameNum
  if pField is not empty then
    return sFrameArray[pFrameNum,pField]
  else
    put sFrameArray[pFrameNum,"language"] into tCommentArray["language"]
    put sFrameArray[pFrameNum,"description"] into tCommentArray["description"]
    put sFrameArray[pFrameNum,"data"]into tCommentArray["data"]
    return tCommentArray
  end if
end id3_getComment

on id3_setComment pLang, pDesc, pComment, pFrameNum
  if pLang is empty then put "XXX" into pLang
  if pDesc is empty then put "no description" & pFrameNum into pDesc
  if pComment is empty then
    i3setError "comment text empty"
    exit id3_setComment
  end if
  if pFrameNum is empty then put i3createFrame("COMM") into pFrameNum
  
  put pLang into sFrameArray[pFrameNum,"language"]
  put pDesc into sFrameArray[pFrameNum,"description"]
  put pComment into sFrameArray[pFrameNum,"data"]
  put pLang & ":" & pDesc & ":" & pComment into sFrameArray[pFrameNum,"content"]
  i3clearError
end id3_setComment

--==--==--==--==--==--==--

function id3_getTXXX pFrameNum
  if pFrameNum is empty then put item 1 of sFrameIndex["TXXX"] into pFrameNum
  put getFrameContent(pFrameNum) into tContent
  replace ":" with cr in tContent
  return tContent
end id3_getTXXX

on id3_setTXXX pText, pDesc
  put pDesc into tDesc
  put pText into tText
  put i3txxxIsUnique(tDesc) into tfn
  if tfn = 0 then put i3createFrame("TXXX") into tfn
  put tDesc into sFrameArray[tfn,"description"]
  put tText into sFrameArray[tfn,"text"]
  put pDesc & ":" & tText into sFrameArray[tfn,"content"]
end id3_setTXXX

--==--==--==--==--==--==--

function id3_getInvolvedPeople pUseUnicode
  return i3getSimpleFrame("IPLS", pUseUnicode)
end id3_getInvolvedPeople

on id3_setInvolvedPeople pContent
  put i3createFrame("IPLS") into tfn
  put pContent into sFrameArray[tfn,"content"]
end id3_setInvolvedPeople

--==--==--==--==--==--==--

function id3_getFrameList pFrameID
  if pFrameID is empty then put "all" into pFrameID
  repeat with n = 1 to sFrameNum
    if sFrameArray[n,"id"] is empty then next repeat
    if sFrameArray[n,"id"] is pFrameID or pFrameID is "all" then
      put n & comma  after tList
    end if
  end repeat
  return byte 1 to -2 of tList
end id3_getFrameList

function id3_getFrameNumberList
  repeat with n = 1 to sFrameNum
    if sFrameArray[n,"id"] is empty then next repeat
    put n & cr after tList
  end repeat
  return byte 1 to -2 of tList
end id3_getFrameNumberList

--==--==--==--==--==--==--

on id3_deleteFrame pFrameNum
  put the keys of sFrameArray into tKeys
  filter tKeys with pFrameNum & ",*"
  repeat for each line L in tKeys
    delete variable sFrameArray[L]
  end repeat
  i3makeFrameIndex
end id3_deleteFrame


function id3_getFrameID pNum
    return sFrameArray[pNum,"id"]
end id3_getFrameID

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
--> utilities

function extractJPEGfromAnyFile pTheFile --takes filepath & returns image data of the first JPEG image found embedded in the file (if any)
  if there is a file pTheFile then
    open file pTheFile for binary read
    read from file pTheFile until (numtochar(255) & numtochar(216))
    read from file pTheFile until (numtochar(255) & numtochar(217))
    put (numtochar(255) & numtochar(216)) & it & numtochar(255) & numtochar(217) into tJPEGData
    --    set the text of image "Extracted Image" to tJPEGData
    close file pTheFile 
    if tJPEGData is not empty then
      return tJPEGData
    else
      return "No JPEG data found in file"
    end if
  else
    return "Error: file not found!"
  end if
end extractJPEGfromAnyFile

function extractPNGfromAnyFile pTheFile --takes filepath & returns image data of the first PNG image found embedded in the file (if any)
  if there is a file pTheFile then
    open file pTheFile for binary read
    read from file pTheFile until "âPNG"
    read from file pTheFile until "IENDÆB`Ç"
    put "âPNG" &  it & "IENDÆB`Ç" into tPNGData
    --    set the text of image "Extracted Image" to tJPEGData
    close file pTheFile 
    if tPNGData is not empty then
      return tPNGData
    else
      return "No JPEG data found in file"
    end if
  else
    return "Error: file not found!"
  end if
end extractPNGfromAnyFile

function i3getFileType pFileName
    put i3getPathWithoutFileName(pFileName) into tFolderName
    put i3getFileNameFromPath(pFileName) into tFileName
    put the directory into tOldFolder
    set the directory to tFolderName
    put urldecode(the detailed files) into tFileList
     
    get lineoffset(tFileName,tFileList)
    put line it of tFileList into tInfo
     
    put item 1 of tInfo into tFileInfo["fileName"]
    put item 2 of tInfo into tFileInfo["fileSize"]
    put item 3 of tInfo into tFileInfo["resourceSize"]
    put item 4 of tInfo into tFileInfo["created"]
    put item 5 of tInfo into tFileInfo["lastModified"]
    put item 6 of tInfo into tFileInfo["lastAccessed"]
    put item 7 of tInfo into tFileInfo["lastBackedUp"]
    put item 8 of tInfo into tFileInfo["Owner"]
    put item 9 of tInfo into tFileInfo["GroupOwner"]
    put item 10 of tInfo into tFileInfo["Permissions"]
    put item 11 of tInfo into tFileInfo["fileType"]
     
    set the directory to tOldFolder
    return tFileInfo["fileType"]
end i3getFileType

function i3getFileNameFromPath aPath
  set the itemdelimiter to "/"
  return item -1 of aPath
end i3getFileNameFromPath


function i3getPathWithoutFileName aPath
  set the itemdelimiter to "/"
  return item 1 to -2 of aPath & "/"
end i3getPathWithoutFileName
