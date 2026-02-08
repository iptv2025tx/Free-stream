sub init()
    m.categoryList = m.top.findNode("categoryList")
    m.channelGrid = m.top.findNode("channelGrid")
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.loadingGroup = m.top.findNode("loadingGroup")
    m.categoryPanel = m.top.findNode("categoryPanel")
    m.gridPanel = m.top.findNode("gridPanel")
    m.gridTitle = m.top.findNode("gridTitle")
    m.channelCount = m.top.findNode("channelCount")

    ' Store all content and current state
    m.allContent = invalid
    m.currentCategoryIndex = 0
    m.focusOnGrid = false
    m.isPlayerVisible = false

    ' All channels list for CH+/CH- navigation
    m.allChannels = createObject("roArray", 0, true)
    m.currentChannelIndex = -1

    ' Start loading playlist
    m.playlistTask = createObject("roSGNode", "PlaylistTask")
    m.playlistTask.observeField("output", "onPlaylistLoaded")
    m.playlistTask.control = "run"

    ' Observe category selection
    m.categoryList.observeField("itemFocused", "onCategoryFocused")

    ' Observe grid selection
    m.channelGrid.observeField("itemSelected", "onChannelSelected")

    ' Observe video player events
    m.videoPlayer.observeField("playerClosed", "onPlayerClosed")

    m.categoryList.setFocus(true)
end sub

sub onPlaylistLoaded()
    content = m.playlistTask.output
    if content = invalid then return

    m.allContent = content
    m.loadingGroup.visible = false
    m.categoryPanel.visible = true
    m.gridPanel.visible = true

    ' Build flat channel list for CH+/CH- navigation
    m.allChannels = createObject("roArray", 0, true)
    if content.getChildCount() > 0
        ' First category is "Todos" - use it for all channels
        allCat = content.getChild(0)
        for i = 0 to allCat.getChildCount() - 1
            m.allChannels.push(allCat.getChild(i))
        end for
    end if

    ' Build category list content
    catContent = createObject("roSGNode", "ContentNode")
    for i = 0 to content.getChildCount() - 1
        catItem = catContent.createChild("ContentNode")
        catItem.title = content.getChild(i).title
    end for
    m.categoryList.content = catContent

    totalChannels = 0
    if m.allChannels.count() > 0
        totalChannels = m.allChannels.count()
    end if
    countStr = str(totalChannels)
    if left(countStr, 1) = " "
        countStr = mid(countStr, 2)
    end if
    m.channelCount.text = countStr + " canais"

    ' Show first category channels
    showCategoryChannels(0)

    m.categoryList.setFocus(true)
end sub

sub onCategoryFocused()
    index = m.categoryList.itemFocused
    if index >= 0
        showCategoryChannels(index)
    end if
end sub

sub showCategoryChannels(catIndex as integer)
    if m.allContent = invalid then return
    if catIndex < 0 or catIndex >= m.allContent.getChildCount() then return

    m.currentCategoryIndex = catIndex
    catNode = m.allContent.getChild(catIndex)

    ' Update title
    m.gridTitle.text = catNode.title

    ' Build grid content
    gridContent = createObject("roSGNode", "ContentNode")
    for i = 0 to catNode.getChildCount() - 1
        ch = catNode.getChild(i)
        item = gridContent.createChild("ContentNode")
        item.title = ch.title
        item.hdPosterUrl = ch.hdPosterUrl
        item.sdPosterUrl = ch.sdPosterUrl
        item.url = ch.url
        item.description = ch.description
        item.shortDescriptionLine1 = ch.title
        item.streamFormat = ch.streamFormat
    end for

    m.channelGrid.content = gridContent
end sub

sub onChannelSelected()
    index = m.channelGrid.itemSelected
    if index < 0 then return

    catNode = m.allContent.getChild(m.currentCategoryIndex)
    if catNode = invalid then return

    channelNode = catNode.getChild(index)
    if channelNode = invalid then return

    ' Find index in all channels list
    for i = 0 to m.allChannels.count() - 1
        if m.allChannels[i].url = channelNode.url
            m.currentChannelIndex = i
            exit for
        end if
    end for

    playChannel(channelNode)
end sub

sub playChannel(channelNode as object)
    m.isPlayerVisible = true
    m.videoPlayer.visible = true
    m.categoryPanel.visible = false
    m.gridPanel.visible = false

    m.videoPlayer.callFunc("playVideo", channelNode)
    m.videoPlayer.setFocus(true)
end sub

sub onPlayerClosed()
    m.isPlayerVisible = false
    m.videoPlayer.visible = false
    m.categoryPanel.visible = true
    m.gridPanel.visible = true

    if m.focusOnGrid
        m.channelGrid.setFocus(true)
    else
        m.categoryList.setFocus(true)
    end if
end sub

sub playNextChannel()
    if m.allChannels.count() = 0 then return
    m.currentChannelIndex = m.currentChannelIndex + 1
    if m.currentChannelIndex >= m.allChannels.count()
        m.currentChannelIndex = 0
    end if
    playChannel(m.allChannels[m.currentChannelIndex])
end sub

sub playPreviousChannel()
    if m.allChannels.count() = 0 then return
    m.currentChannelIndex = m.currentChannelIndex - 1
    if m.currentChannelIndex < 0
        m.currentChannelIndex = m.allChannels.count() - 1
    end if
    playChannel(m.allChannels[m.currentChannelIndex])
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    if m.isPlayerVisible
        ' Player is visible - handle CH+/CH-
        if key = "channelUp" or key = "fastforward"
            playNextChannel()
            return true
        else if key = "channelDown" or key = "rewind"
            playPreviousChannel()
            return true
        end if
        return false
    end if

    ' Navigate between category list and grid
    if key = "right" and not m.focusOnGrid
        m.focusOnGrid = true
        m.channelGrid.setFocus(true)
        return true
    else if key = "left" and m.focusOnGrid
        m.focusOnGrid = false
        m.categoryList.setFocus(true)
        return true
    end if

    ' CH+/CH- while browsing (if channel is playing)
    if key = "channelUp"
        playNextChannel()
        return true
    else if key = "channelDown"
        playPreviousChannel()
        return true
    end if

    return false
end function
