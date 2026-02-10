' VideoPlayerLogic - from SceneGraph Master Sample
' Uses built-in Video node directly (no custom VideoScreen)

sub ShowVideoScreen(rowContent as Object, selectedItem as Integer)
    m.videoPlayer = CreateObject("roSGNode", "Video")
    m.selectedIndex[1] = selectedItem

    if selectedItem <> 0
        numOfChildren = rowContent.GetChildCount()
        children = rowContent.GetChildren(numOfChildren - selectedItem, selectedItem)
        childrenClone = []
        for each child in children
            childrenClone.Push(child.Clone(false))
        end for
        rowNode = CreateObject("roSGNode", "ContentNode")
        rowNode.Update({ children: childrenClone }, true)
        m.videoPlayer.content = rowNode
    else
        m.videoPlayer.content = rowContent.Clone(true)
    end if

    m.videoPlayer.contentIsPlaylist = true
    ShowScreen(m.videoPlayer)
    m.videoPlayer.control = "play"
    m.videoPlayer.ObserveField("state", "OnVideoPlayerStateChange")
    m.videoPlayer.ObserveField("visible", "OnVideoVisibleChange")
end sub

sub OnVideoPlayerStateChange()
    state = m.videoPlayer.state
    if state = "error" or state = "finished"
        CloseScreen(m.videoPlayer)
    end if
end sub

sub OnVideoVisibleChange()
    if m.videoPlayer.visible = false and m.top.visible = true
        currentIndex = m.videoPlayer.contentIndex
        m.videoPlayer.control = "stop"
        m.videoPlayer.content = invalid
        screen = GetCurrentScreen()
        screen.SetFocus(true)
        screen.jumpToItem = currentIndex + m.selectedIndex[1]
    end if
end sub
