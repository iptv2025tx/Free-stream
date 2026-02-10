sub init()
    m.top.functionName = "loadPlaylist"
end sub

sub loadPlaylist()
    url = m.top.url
    if url = invalid
        return
    end if
    if url = ""
        return
    end if

    xfer = createObject("roUrlTransfer")
    xfer.setUrl(url)
    xfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.enableHostVerification(false)
    xfer.enablePeerVerification(false)

    response = xfer.getToString()
    if response = invalid
        return
    end if
    if response = ""
        return
    end if

    lines = splitLines(response)
    channels = parseM3U(lines)
    groups = groupChannels(channels)

    rootNode = createObject("roSGNode", "ContentNode")

    allCat = rootNode.createChild("ContentNode")
    allCat.title = "Todos (" + intToStr(channels.count()) + ")"
    for each ch in channels
        addChannelNode(allCat, ch)
    end for

    for each grp in groups
        catNode = rootNode.createChild("ContentNode")
        catNode.title = grp.name + " (" + intToStr(grp.channels.count()) + ")"
        for each ch in grp.channels
            addChannelNode(catNode, ch)
        end for
    end for

    m.top.output = rootNode
end sub

function splitLines(text as string) as object
    result = createObject("roArray", 0, true)
    startPos = 1
    textLen = len(text)
    while startPos <= textLen
        lfPos = instr(startPos, text, chr(10))
        if lfPos = 0
            segment = mid(text, startPos)
            segment = removeCR(segment)
            result.push(segment)
            startPos = textLen + 1
        else
            if lfPos > startPos
                segment = mid(text, startPos, lfPos - startPos)
                segment = removeCR(segment)
                result.push(segment)
            else
                result.push("")
            end if
            startPos = lfPos + 1
        end if
    end while
    return result
end function

function removeCR(s as string) as string
    while len(s) > 0
        if right(s, 1) = chr(13)
            s = left(s, len(s) - 1)
        else
            exit while
        end if
    end while
    while len(s) > 0
        if left(s, 1) = chr(13)
            s = mid(s, 2)
        else
            exit while
        end if
    end while
    return s
end function

function intToStr(num as integer) as string
    s = str(num)
    if left(s, 1) = " "
        s = mid(s, 2)
    end if
    return s
end function

function trimString(s as string) as string
    while len(s) > 0
        if left(s, 1) = " "
            s = mid(s, 2)
        else
            exit while
        end if
    end while
    while len(s) > 0
        if right(s, 1) = " "
            s = left(s, len(s) - 1)
        else
            exit while
        end if
    end while
    return s
end function

sub addChannelNode(parentNode as object, ch as object)
    node = parentNode.createChild("ContentNode")
    node.title = ch.name
    node.url = ch.url
    defaultLogo = "https://raw.githubusercontent.com/tenorioabsgit/images/refs/heads/main/sepulnation.png"
    node.hdPosterUrl = defaultLogo
    node.sdPosterUrl = defaultLogo
    node.description = ch.group
    node.streamFormat = getStreamFormat(ch.url)
end sub

function getStreamFormat(videoUrl as string) as string
    lower = lcase(videoUrl)
    if instr(1, lower, ".m3u8") > 0
        return "hls"
    else if instr(1, lower, ".mpd") > 0
        return "dash"
    else if instr(1, lower, ".mp4") > 0
        return "mp4"
    else if instr(1, lower, ".mkv") > 0
        return "mkv"
    end if
    return "hls"
end function

function parseM3U(lines as object) as object
    channels = createObject("roArray", 0, true)
    i = 0
    total = lines.count()
    while i < total
        txtLine = trimString(lines[i])

        if left(txtLine, 8) = "#EXTINF:"
            chName = ""
            chGroup = ""
            chLogo = ""

            commaPos = 0
            ci = len(txtLine)
            while ci >= 1
                if mid(txtLine, ci, 1) = ","
                    commaPos = ci
                    ci = 0
                end if
                ci = ci - 1
            end while

            if commaPos > 0
                chName = trimString(mid(txtLine, commaPos + 1))
            end if

            chGroup = getAttrValue(txtLine, "group-title")
            chLogo = getAttrValue(txtLine, "tvg-logo")

            chUrl = ""
            j = i + 1
            while j < total
                nextLine = trimString(lines[j])
                if nextLine <> ""
                    if left(nextLine, 1) <> "#"
                        chUrl = nextLine
                        j = total
                    end if
                end if
                j = j + 1
            end while

            if chUrl <> ""
                channel = createObject("roAssociativeArray")
                channel.name = chName
                channel.url = chUrl
                channel.group = chGroup
                channel.logo = chLogo
                channels.push(channel)
            end if
        end if

        i = i + 1
    end while
    return channels
end function

function getAttrValue(txtLine as string, attrName as string) as string
    q = chr(34)
    search = attrName + "=" + q
    foundPos = instr(1, lcase(txtLine), lcase(search))
    if foundPos > 0
        valStart = foundPos + len(search)
        valEnd = instr(valStart, txtLine, q)
        if valEnd > valStart
            return mid(txtLine, valStart, valEnd - valStart)
        end if
    end if
    return ""
end function

function groupChannels(channels as object) as object
    groupMap = createObject("roAssociativeArray")

    for each ch in channels
        gName = ch.group
        if gName = invalid
            gName = "Outros"
        else if gName = ""
            gName = "Outros"
        end if

        if not groupMap.doesExist(gName)
            groupMap[gName] = createObject("roArray", 0, true)
        end if
        groupMap[gName].push(ch)
    end for

    brList = createObject("roArray", 0, true)
    otherList = createObject("roArray", 0, true)

    for each keyName in groupMap
        grpObj = createObject("roAssociativeArray")
        grpObj.name = keyName
        grpObj.channels = groupMap[keyName]
        if left(keyName, 3) = "BR "
            brList.push(grpObj)
        else
            otherList.push(grpObj)
        end if
    end for

    sortByName(brList)
    sortByName(otherList)

    result = createObject("roArray", 0, true)
    for each g in brList
        result.push(g)
    end for
    for each g in otherList
        result.push(g)
    end for

    return result
end function

sub sortByName(arr as object)
    n = arr.count()
    if n < 2
        return
    end if
    for i = 0 to n - 2
        for j = 0 to n - 2 - i
            if arr[j].name > arr[j + 1].name
                temp = arr[j]
                arr[j] = arr[j + 1]
                arr[j + 1] = temp
            end if
        end for
    end for
end sub
