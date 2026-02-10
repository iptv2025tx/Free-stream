sub Init()
    m.top.functionName = "LoadPlaylist"
end sub

sub LoadPlaylist()
    url = m.top.playlistUrl
    if url = invalid or url = "" then return

    ' Download M3U playlist
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnableHostVerification(false)
    xfer.EnablePeerVerification(false)

    print "SepulnationTV: Downloading playlist from " + url

    if not xfer.AsyncGetToString()
        print "SepulnationTV: Failed to start download"
        return
    end if

    ' Wait up to 30 seconds for response
    msg = Wait(30000, port)
    if msg = invalid
        print "SepulnationTV: Download timed out"
        xfer.AsyncCancel()
        return
    end if

    responseCode = msg.GetResponseCode()
    print "SepulnationTV: Response code = " + Str(responseCode)

    if responseCode <> 200
        print "SepulnationTV: HTTP error " + Str(responseCode)
        return
    end if

    response = msg.GetString()
    if response = invalid or response = "" then return

    ' Parse M3U
    lines = SplitLines(response)
    channels = ParseM3U(lines)
    groups = GroupChannels(channels)

    ' Build ContentNode tree
    rootNode = CreateObject("roSGNode", "ContentNode")

    ' "Todos" category
    allCat = rootNode.CreateChild("ContentNode")
    allCat.title = "Todos (" + IntToStr(channels.Count()) + ")"
    for each ch in channels
        AddChannelNode(allCat, ch)
    end for

    ' Per-group categories
    for each grp in groups
        catNode = rootNode.CreateChild("ContentNode")
        catNode.title = grp.name + " (" + IntToStr(grp.channels.Count()) + ")"
        for each ch in grp.channels
            AddChannelNode(catNode, ch)
        end for
    end for

    print "SepulnationTV: Loaded " + IntToStr(channels.Count()) + " channels in " + IntToStr(groups.Count()) + " groups"
    m.top.content = rootNode
end sub

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

            ' Find last comma to extract channel name
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

            ' Find stream URL on next non-empty, non-comment line
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

sub AddChannelNode(parentNode as Object, ch as Object)
    node = parentNode.CreateChild("ContentNode")
    node.title = ch.name
    node.url = ch.url
    node.description = ch.group

    defaultLogo = "https://raw.githubusercontent.com/tenorioabsgit/images/refs/heads/main/sepulnation.png"
    if ch.logo <> invalid and ch.logo <> ""
        node.hdPosterUrl = ch.logo
        node.sdPosterUrl = ch.logo
    else
        node.hdPosterUrl = defaultLogo
        node.sdPosterUrl = defaultLogo
    end if

    node.streamFormat = GetStreamFormat(ch.url)
end sub

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
