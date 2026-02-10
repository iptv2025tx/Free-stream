' ContentTaskLogic.brs - Async playlist loading
' Based on SceneGraph Master Sample pattern

sub RunContentTask()
    m.contentTask = CreateObject("roSGNode", "PlaylistLoaderTask")
    m.contentTask.ObserveField("content", "OnMainContentLoaded")

    ' Also observe task state for error handling
    m.contentTask.ObserveField("state", "OnTaskStateChange")

    m.contentTask.control = "run"
end sub

sub OnTaskStateChange()
    state = m.contentTask.state
    print "SepulnationTV: Task state = " + state

    if state = "stop"
        ' Task finished - if content was not set, it failed
        if m.allContent = invalid
            print "SepulnationTV: Task finished without content - showing error"
            m.loadingIndicator.visible = false

            ' Show error on GridScreen
            errorLabel = m.gridScreen.FindNode("loadingGroup")
            if errorLabel <> invalid
                spinnerNode = errorLabel.FindNode("spinner")
                if spinnerNode <> invalid then spinnerNode.visible = false
                labelNodes = errorLabel.GetChildren(-1, 0)
                for each child in labelNodes
                    if child.subtype() = "Label"
                        child.text = "Erro ao carregar canais. Reinicie o app."
                        child.color = "0xFF3333FF"
                    end if
                end for
            end if
        end if
    end if
end sub

sub OnMainContentLoaded()
    m.loadingIndicator.visible = false
    m.allContent = m.contentTask.content

    if m.allContent = invalid then return

    print "SepulnationTV: Content loaded, setting on GridScreen"

    ' Build flat channel list for CH+/CH-
    m.allChannels = CreateObject("roArray", 0, true)
    if m.allContent.GetChildCount() > 0
        allCat = m.allContent.GetChild(0)
        for i = 0 to allCat.GetChildCount() - 1
            m.allChannels.Push(allCat.GetChild(i))
        end for
    end if

    ' Set content on GridScreen
    m.gridScreen.content = m.allContent
end sub
