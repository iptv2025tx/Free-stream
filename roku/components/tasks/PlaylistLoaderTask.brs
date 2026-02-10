' PlaylistLoaderTask - loads and parses M3U playlist
' Based on MainLoaderTask pattern from SceneGraph Master Sample
sub Init()
    m.top.functionName = "GetContent"
end sub

sub GetContent()
    url = m.top.playlistUrl
    if url = invalid or url = "" then return

    ' request the playlist from the API
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.SetUrl(url)

    if not xfer.AsyncGetToString()
        print "SepulnationTV: Failed to start download"
        return
    end if

    msg = Wait(30000, port)
    if msg = invalid
        print "SepulnationTV: Download timed out"
        xfer.AsyncCancel()
        return
    end if

    if msg.GetResponseCode() <> 200
        print "SepulnationTV: HTTP error " + Str(msg.GetResponseCode())
        return
    end if

    response = msg.GetString()
    if response = invalid or response = "" then return

    ' parse the M3U and build a tree of ContentNodes to populate the GridScreen
    lines = SplitLines(response)
    channels = ParseM3U(lines)
    groups = GroupChannels(channels)

    rootChildren = []

    ' first row: all channels
    allRow = {}
    allRow.title = "Todos (" + IntToStr(channels.Count()) + ")"
    allRow.children = []
    for each ch in channels
        allRow.children.Push(GetChannelData(ch))
    end for
    rootChildren.Push(allRow)

    ' per-group rows
    for each grp in groups
        row = {}
        row.title = grp.name + " (" + IntToStr(grp.channels.Count()) + ")"
        row.children = []
        for each ch in grp.channels
            row.children.Push(GetChannelData(ch))
        end for
        rootChildren.Push(row)
    end for

    ' set up root ContentNode to represent rowList on GridScreen
    contentNode = CreateObject("roSGNode", "ContentNode")
    contentNode.Update({ children: rootChildren }, true)

    print "SepulnationTV: Loaded " + IntToStr(channels.Count()) + " channels"
    ' populate content field - observer is invoked at that moment
    m.top.content = contentNode
end sub

function GetChannelData(ch as Object) as Object
    item = {}
    item.title = ch.name
    item.description = ch.group
    item.url = ch.url
    item.streamFormat = GetStreamFormat(ch.url)

    defaultLogo = "https://raw.githubusercontent.com/tenorioabsgit/images/refs/heads/main/sepulnation.png"
    if ch.logo <> invalid and ch.logo <> ""
        item.hdPosterUrl = ch.logo
    else
        item.hdPosterUrl = defaultLogo
    end if

    return item
end function

function ParseM3U(lines as Object) as Object
    channels = CreateObject("roArray", 0, true)
    i = 0
    total = lines.Count()

    while i < total
        txtLine = TrimStr(lines[i])

        if Left(txtLine, 8) = "#EXTINF:"
            chName = ""
            chGroup = ""
            chLogo = ""

            ' find last comma to extract channel name
            commaPos = 0
            ci = Len(txtLine)
            while ci >= 1
                if Mid(txtLine, ci, 1) = ","
                    commaPos = ci
                    ci = 0
                end if
                ci = ci - 1
            end while

            if commaPos > 0
                chName = TrimStr(Mid(txtLine, commaPos + 1))
            end if

            chGroup = GetAttrValue(txtLine, "group-title")
            chLogo = GetAttrValue(txtLine, "tvg-logo")

            ' find stream URL on next non-empty, non-comment line
            chUrl = ""
            j = i + 1
            while j < total
                nextLine = TrimStr(lines[j])
                if nextLine <> ""
                    if Left(nextLine, 1) <> "#"
                        chUrl = nextLine
                        j = total
                    end if
                end if
                j = j + 1
            end while

            if chUrl <> ""
                channel = CreateObject("roAssociativeArray")
                channel.name = chName
                channel.url = chUrl
                channel.group = chGroup
                channel.logo = chLogo
                channels.Push(channel)
            end if
        end if

        i = i + 1
    end while

    return channels
end function

function GroupChannels(channels as Object) as Object
    groupMap = CreateObject("roAssociativeArray")

    for each ch in channels
        gName = ch.group
        if gName = invalid or gName = "" then gName = "Outros"
        if not groupMap.DoesExist(gName)
            groupMap[gName] = CreateObject("roArray", 0, true)
        end if
        groupMap[gName].Push(ch)
    end for

    brList = CreateObject("roArray", 0, true)
    otherList = CreateObject("roArray", 0, true)

    for each keyName in groupMap
        grpObj = CreateObject("roAssociativeArray")
        grpObj.name = keyName
        grpObj.channels = groupMap[keyName]
        if Left(keyName, 3) = "BR "
            brList.Push(grpObj)
        else
            otherList.Push(grpObj)
        end if
    end for

    SortByName(brList)
    SortByName(otherList)

    result = CreateObject("roArray", 0, true)
    for each g in brList
        result.Push(g)
    end for
    for each g in otherList
        result.Push(g)
    end for

    return result
end function
