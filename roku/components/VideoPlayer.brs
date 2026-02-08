sub init()
    m.video = m.top.findNode("video")
    m.osdGroup = m.top.findNode("osdGroup")
    m.osdHints = m.top.findNode("osdHints")
    m.osdChannelName = m.top.findNode("osdChannelName")
    m.osdCategory = m.top.findNode("osdCategory")
    m.bufferingGroup = m.top.findNode("bufferingGroup")
    m.errorGroup = m.top.findNode("errorGroup")
    m.errorMessage = m.top.findNode("errorMessage")

    m.currentContent = invalid
    m.osdTimer = invalid
    m.hasError = false

    ' Observe video state
    m.video.observeField("state", "onVideoStateChange")
    m.video.observeField("bufferingStatus", "onBufferingChange")
end sub

sub playVideo(channelNode as object)
    m.currentContent = channelNode
    m.hasError = false
    m.errorGroup.visible = false
    m.bufferingGroup.visible = true

    ' Update OSD
    m.osdChannelName.text = channelNode.title
    if channelNode.description <> invalid and channelNode.description <> ""
        m.osdCategory.text = channelNode.description
    else
        m.osdCategory.text = ""
    end if

    ' Build video content
    videoContent = createObject("roSGNode", "ContentNode")
    videoContent.title = channelNode.title
    videoContent.url = channelNode.url

    if channelNode.streamFormat <> invalid
        if channelNode.streamFormat <> ""
            videoContent.streamFormat = channelNode.streamFormat
        else
            videoContent.streamFormat = "hls"
        end if
    else
        videoContent.streamFormat = "hls"
    end if

    m.video.content = videoContent
    m.video.control = "play"
    m.video.setFocus(true)

    ' Show OSD and start timer to hide it
    showOsd()
end sub

sub onVideoStateChange()
    state = m.video.state

    if state = "playing"
        m.bufferingGroup.visible = false
        m.errorGroup.visible = false
        m.hasError = false
    else if state = "buffering"
        m.bufferingGroup.visible = true
    else if state = "error"
        m.hasError = true
        m.bufferingGroup.visible = false
        m.errorGroup.visible = true
        m.errorMessage.text = "Não foi possível reproduzir este canal"
    else if state = "finished"
        ' Stream ended - try to reconnect
        if m.currentContent <> invalid
            m.video.control = "play"
        end if
    end if
end sub

sub onBufferingChange()
    status = m.video.bufferingStatus
    if status <> invalid
        percentage = status.percentage
        if percentage < 100
            m.bufferingGroup.visible = true
        else
            m.bufferingGroup.visible = false
        end if
    end if
end sub

sub showOsd()
    m.osdGroup.visible = true
    m.osdHints.visible = true

    ' Cancel existing timer
    if m.osdTimer <> invalid
        m.osdTimer.control = "stop"
    end if

    ' Create timer to hide OSD after 3 seconds
    m.osdTimer = createObject("roSGNode", "Timer")
    m.osdTimer.duration = 3
    m.osdTimer.repeat = false
    m.osdTimer.observeField("fire", "hideOsd")
    m.osdTimer.control = "start"
end sub

sub hideOsd()
    m.osdGroup.visible = false
    m.osdHints.visible = false
end sub

sub stopVideo()
    m.video.control = "stop"
    m.top.playerClosed = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    ' Back: close player
    if key = "back"
        stopVideo()
        return true
    end if

    ' OK: play/pause or retry on error
    if key = "OK"
        if m.hasError and m.currentContent <> invalid
            ' Retry
            playVideo(m.currentContent)
            return true
        end if

        ' Toggle play/pause
        if m.video.state = "playing"
            m.video.control = "pause"
            showOsd()
        else if m.video.state = "paused"
            m.video.control = "resume"
            showOsd()
        end if
        return true
    end if

    ' Play/Pause button
    if key = "play"
        if m.video.state = "playing"
            m.video.control = "pause"
            showOsd()
        else if m.video.state = "paused"
            m.video.control = "resume"
            showOsd()
        end if
        return true
    end if

    ' Any key shows OSD
    if key = "up" or key = "down" or key = "left" or key = "right"
        showOsd()
        return true
    end if

    ' CH+/CH- handled by parent (MainScene)
    if key = "channelUp" or key = "channelDown"
        return false ' Let parent handle
    end if

    return false
end function
