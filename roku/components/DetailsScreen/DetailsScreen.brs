' DetailsScreen - channel details view
' Based on DetailsScreen from SceneGraph Master Sample
sub Init()
    m.top.ObserveField("visible", "OnVisibleChange")
    m.top.ObserveField("itemFocused", "OnItemFocusedChanged")
    m.buttons = m.top.FindNode("buttons")
    m.poster = m.top.FindNode("poster")
    m.description = m.top.FindNode("descriptionLabel")
    m.categoryLabel = m.top.FindNode("categoryLabel")
    m.titleLabel = m.top.FindNode("titleLabel")

    ' create buttons
    result = []
    for each button in ["Assistir"]
        result.Push({ title: button })
    end for
    m.buttons.content = ContentListToSimpleNode(result)
end sub

sub OnVisibleChange()
    if m.top.visible = true
        m.buttons.SetFocus(true)
        m.top.itemFocused = m.top.jumpToItem
    end if
end sub

sub SetDetailsContent(content as Object)
    m.poster.uri = content.hdPosterUrl
    m.titleLabel.text = content.title
    if content.description <> invalid
        m.description.text = content.description
    else
        m.description.text = ""
    end if
    fmt = "HLS"
    if content.streamFormat <> invalid and content.streamFormat <> ""
        fmt = UCase(content.streamFormat)
    end if
    m.categoryLabel.text = fmt
end sub

sub OnJumpToItem()
    content = m.top.content
    if content <> invalid and m.top.jumpToItem >= 0 and content.GetChildCount() > m.top.jumpToItem
        m.top.itemFocused = m.top.jumpToItem
    end if
end sub

sub OnItemFocusedChanged(event as Object)
    focusedItem = event.GetData()
    content = m.top.content.GetChild(focusedItem)
    SetDetailsContent(content)
end sub

function OnKeyEvent(key as String, press as Boolean) as Boolean
    result = false
    if press
        currentItem = m.top.itemFocused
        if key = "left"
            m.top.jumpToItem = currentItem - 1
            result = true
        else if key = "right"
            m.top.jumpToItem = currentItem + 1
            result = true
        end if
    end if
    return result
end function
