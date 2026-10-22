import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.streetpea.chiaking

Pane {
    id: consolePane
    padding: 0

    readonly property var theme: root.theme
    // Controller glyphs only help when a controller is connected.
    readonly property bool showGamepadHints: Chiaki.controllers.length > 0
    // Hidden consoles stay in Chiaki.hosts, so each card keeps its backend index for
    // the actions. The grid always ends with an "add console" card.
    readonly property var cards: Chiaki.hosts
        .map((host, hostIndex) => ({ host: host, hostIndex: hostIndex }))
        .filter(card => card.host.display)
        .concat([{ add: true }])
    readonly property int consoleCount: cards.length - 1

    component GamepadHint: Image {
        property string glyph
        width: 18
        height: 18
        sourceSize: Qt.size(width, height)
        source: glyph
        visible: consolePane.showGamepadHints
    }

    component CardAction: Button {
        property string tip
        property string hint
        property bool cardHighlighted
        Layout.preferredWidth: 44
        flat: true
        display: AbstractButton.IconOnly
        icon.width: 18
        icon.height: 18
        focusPolicy: Qt.NoFocus
        Material.roundedScale: Material.SmallScale
        ToolTip.visible: hovered
        ToolTip.delay: 400
        ToolTip.text: tip

        GamepadHint {
            anchors {
                right: parent.right
                bottom: parent.bottom
                margins: 6
            }
            width: 14
            height: 14
            glyph: parent.hint
            visible: consolePane.showGamepadHints && parent.cardHighlighted && parent.hint !== ""
        }
    }

    StackView.onActivated: {
        forceActiveFocus(Qt.TabFocusReason);
        if(!Chiaki.autoConnect && !root.initialAsk && !Chiaki.window.directStream)
        {
            root.initialAsk = true;
            if(Chiaki.settings.addSteamShortcutAsk && (typeof Chiaki.createSteamShortcut === "function"))
                root.showRemindDialog(qsTr("Official Steam artwork + controller layout"), qsTr("Would you like to either create a new non-Steam game for chiaki-ng\nor update an existing non-Steam game with the official artwork and controller layout?") + "\n\n" + qsTr("(Note: If you select no now and want to do this later, click the button or press R3 from the main menu.)"), false, () => root.showSteamShortcutDialog(true));
            else if(Chiaki.settings.remotePlayAsk)
            {
                if(!Chiaki.settings.psnRefreshToken || !Chiaki.settings.psnAuthToken || !Chiaki.settings.psnAuthTokenExpiry || !Chiaki.settings.psnAccountId)
                    root.showRemindDialog(qsTr("Remote Play via PSN"), qsTr("Would you like to connect to PSN?\nThis enables:\n- Automatic registration\n- Playing outside of your home network without port forwarding?") + "\n\n" + qsTr("(Note: If you select no now and want to do this later, go to the Config section of the settings.)"), true, () => root.showPSNTokenDialog(false));
                else
                    Chiaki.settings.remotePlayAsk = false;
            }
        }
    }
    Keys.onUpPressed: hostsView.moveCurrentIndexUp()
    Keys.onDownPressed: hostsView.moveCurrentIndexDown()
    Keys.onLeftPressed: hostsView.moveCurrentIndexLeft()
    Keys.onRightPressed: hostsView.moveCurrentIndexRight()
    Keys.onMenuPressed: settingsButton.clicked()
    Keys.onReturnPressed: if (hostsView.currentItem) hostsView.currentItem.connectToHost()
    Keys.onYesPressed: if (hostsView.currentItem) hostsView.currentItem.wakeUpHost()
    Keys.onNoPressed: if (hostsView.currentItem) hostsView.currentItem.deleteHost()
    Keys.onEscapePressed: root.showConfirmDialog(qsTr("Quit"), qsTr("Are you sure you want to quit?"), () => Qt.quit())
    Keys.onPressed: (event) => {
        if (event.modifiers)
            return;
        switch (event.key) {
        case Qt.Key_PageUp:
            if (hostsView.currentItem) hostsView.currentItem.setConsolePin();
            event.accepted = true;
            break;
        case Qt.Key_PageDown:
            if (Chiaki.settings.psnAuthToken) Chiaki.refreshPsnToken();
            event.accepted = true;
            break;
        case Qt.Key_F1:
            if (typeof Chiaki.createSteamShortcut === "function") root.showSteamShortcutDialog(false);
            event.accepted = true;
            break;
        case Qt.Key_F2:
            root.showManualHostDialog();
            event.accepted = true;
            break;
        }
    }

    ToolBar {
        id: toolBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 56

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 18
                rightMargin: 8
            }
            spacing: 2

            Label {
                text: "Any<font color=\"%1\">2</font>Play".arg(consolePane.theme.accentLight)
                textFormat: Text.StyledText
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            ToolButton {
                text: qsTr("Refresh PSN")
                icon.source: "qrc:/icons/a2p-refresh.svg"
                font.pixelSize: 13
                rightPadding: consolePane.showGamepadHints ? 34 : 12
                focusPolicy: Qt.NoFocus
                visible: !!Chiaki.settings.psnAuthToken
                onClicked: Chiaki.refreshPsnToken()
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: qsTr("Refresh PSN Hosts")

                GamepadHint {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    glyph: "qrc:/icons/r1.svg"
                }
            }

            ToolButton {
                text: qsTr("Add console")
                icon.source: "qrc:/icons/a2p-plus.svg"
                font.pixelSize: 13
                rightPadding: consolePane.showGamepadHints ? 34 : 12
                focusPolicy: Qt.NoFocus
                onClicked: root.showManualHostDialog()
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: qsTr("Add Manual Host")

                GamepadHint {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    glyph: "qrc:/icons/r3.svg"
                }
            }

            ToolButton {
                icon.source: "qrc:/icons/a2p-steam.svg"
                display: AbstractButton.IconOnly
                rightPadding: consolePane.showGamepadHints ? 30 : 8
                focusPolicy: Qt.NoFocus
                visible: typeof Chiaki.createSteamShortcut === "function"
                onClicked: root.showSteamShortcutDialog(false)
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: qsTr("Create Steam Shortcut")

                GamepadHint {
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    glyph: "qrc:/icons/l3.svg"
                }
            }

            ToolButton {
                id: settingsButton
                icon.source: "qrc:/icons/a2p-settings.svg"
                display: AbstractButton.IconOnly
                focusPolicy: Qt.NoFocus
                onClicked: root.showSettingsDialog()
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: qsTr("Settings")
            }

            ToolButton {
                icon.source: "qrc:/icons/a2p-x.svg"
                display: AbstractButton.IconOnly
                focusPolicy: Qt.NoFocus
                onClicked: Qt.quit()
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: qsTr("Quit")
            }
        }
    }

    GridView {
        id: hostsView
        anchors {
            top: toolBar.bottom
            left: parent.left
            right: parent.right
            bottom: statusBar.top
            leftMargin: 12
            rightMargin: 12
            topMargin: 8
        }
        readonly property int columns: Math.max(1, Math.floor(width / 320))
        cellWidth: Math.floor(width / columns)
        cellHeight: 236
        clip: true
        keyNavigationWraps: true
        boundsBehavior: Flickable.StopAtBounds
        model: consolePane.cards
        ScrollBar.vertical: ScrollBar { }

        header: Item {
            width: hostsView.width
            height: headerColumn.implicitHeight + 10

            ColumnLayout {
                id: headerColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 6
                    leftMargin: 8
                    rightMargin: 8
                }
                spacing: 4

                Label {
                    text: qsTr("Consoles")
                    font.pixelSize: 13
                    color: consolePane.theme.textMuted
                }

                Label {
                    Layout.fillWidth: true
                    visible: consolePane.consoleCount === 0
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                    color: consolePane.theme.textMuted
                    text: Chiaki.discoveryEnabled
                        ? qsTr("Looking for consoles on your network…")
                        : qsTr("Network discovery is off. Turn it on below, or add a console by its address.")
                }
            }
        }

        delegate: Item {
            id: delegate
            width: hostsView.cellWidth
            height: hostsView.cellHeight

            readonly property bool isAddCard: modelData.add === true
            readonly property var host: isAddCard ? ({}) : modelData.host
            readonly property int hostIndex: isAddCard ? -1 : modelData.hostIndex
            readonly property bool highlighted: GridView.isCurrentItem
            readonly property string status: isAddCard ? ""
                : host.duid ? "psn"
                : host.state === "ready" ? "ready"
                : host.state === "standby" ? "standby"
                : "unknown"

            function connectToHost() {
                if (isAddCard)
                    root.showManualHostDialog();
                else if (host.discovered)
                    Chiaki.connectToHost(hostIndex, host.name);
                else
                    Chiaki.connectToHost(hostIndex);
            }

            function wakeUpHost() {
                if (!isAddCard && !host.discovered && !host.duid)
                    Chiaki.wakeUpHost(hostIndex);
            }

            function deleteHost() {
                if (isAddCard)
                    return;
                if (host.manual)
                    root.showConfirmDialog(qsTr("Delete Console"), qsTr("Are you sure you want to delete this console?"), () => {Chiaki.deleteHost(hostIndex)});
                else if (host.discovered && !host.registered)
                    root.showConfirmDialog(qsTr("Hide Console"), qsTr("Are you sure you want to hide this console?") + "\n\n" + qsTr("Note: You can unhide from the Consoles section of the Settings under Hidden Consoles"), () => Chiaki.hideHost(host.mac, host.name));
            }

            function setConsolePin() {
                if (!isAddCard)
                    root.showConsolePinDialog(hostIndex);
            }

            function infoText() {
                if (isAddCard)
                    return "";
                let lines = [];
                if (host.address)
                    lines.push(qsTr("Address: %1").arg(Chiaki.settings.streamerMode ? "hidden" : host.address));
                if (host.mac)
                    lines.push(qsTr("ID: %1 (%2)").arg(Chiaki.settings.streamerMode ? "hidden" : host.mac).arg(host.registered ? qsTr("registered") : qsTr("unregistered")));
                if (host.duid)
                    lines.push(host.discovered ? qsTr("Automatic Registration Available") : qsTr("Remote Connection via PSN"));
                else if (host.discovered)
                    lines.push(host.manual ? qsTr("discovered + manual") : qsTr("discovered"));
                else
                    lines.push(qsTr("manual"));
                if (!host.duid && host.discovered) {
                    if (host.app)
                        lines.push(qsTr("App: %1").arg(host.app));
                    if (host.titleId)
                        lines.push(qsTr("Title ID: %1").arg(host.titleId));
                }
                return lines.join("\n");
            }

            Rectangle {
                id: card
                anchors {
                    fill: parent
                    margins: 6
                }
                radius: 12
                color: delegate.isAddCard ? "transparent" : consolePane.theme.surface
                border.width: delegate.highlighted ? 2 : 1
                border.color: delegate.highlighted ? consolePane.theme.accent
                    : cardMouse.containsMouse ? consolePane.theme.borderHover
                    : consolePane.theme.border

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        hostsView.currentIndex = index;
                        delegate.connectToHost();
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: delegate.isAddCard
                    spacing: 8

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        width: 28
                        height: 28
                        sourceSize: Qt.size(width, height)
                        source: "qrc:/icons/a2p-plus.svg"
                        opacity: 0.6
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Add console by address")
                        font.pixelSize: 13
                        color: consolePane.theme.textMuted
                    }

                    GamepadHint {
                        Layout.alignment: Qt.AlignHCenter
                        glyph: "qrc:/icons/r3.svg"
                    }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 14
                    }
                    visible: !delegate.isAddCard
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56
                            radius: 10
                            color: consolePane.theme.inset

                            Image {
                                anchors.centerIn: parent
                                width: 48
                                height: 48
                                fillMode: Image.PreserveAspectFit
                                sourceSize: Qt.size(width, height)
                                source: delegate.isAddCard ? ""
                                    : "image://svg/console-ps" + (delegate.host.ps5 ? "5" : "4") + (delegate.host.state == "standby" ? "#light_standby" : "#light_on")
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                Layout.fillWidth: true
                                text: delegate.host.name || ""
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                implicitWidth: statusLabel.implicitWidth + 16
                                implicitHeight: statusLabel.implicitHeight + 4
                                radius: height / 2
                                color: delegate.status === "ready" ? consolePane.theme.successBackground
                                    : delegate.status === "standby" ? consolePane.theme.warningBackground
                                    : delegate.status === "psn" ? consolePane.theme.selection
                                    : consolePane.theme.neutralBackground

                                Label {
                                    id: statusLabel
                                    anchors.centerIn: parent
                                    font.pixelSize: 11
                                    text: delegate.status === "psn" ? qsTr("PSN")
                                        : qsTr("State: %1").arg(delegate.host.state || "")
                                    color: delegate.status === "ready" ? consolePane.theme.success
                                        : delegate.status === "standby" ? consolePane.theme.warning
                                        : delegate.status === "psn" ? consolePane.theme.accentLight
                                        : consolePane.theme.textMuted
                                }
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: delegate.infoText()
                        font.pixelSize: 12
                        color: consolePane.theme.textMuted
                        wrapMode: Text.Wrap
                        maximumLineCount: 5
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Button {
                            Layout.fillWidth: true
                            text: delegate.host.registered ? qsTr("Connect") : qsTr("Register")
                            highlighted: true
                            font.pixelSize: 13
                            focusPolicy: Qt.NoFocus
                            Material.roundedScale: Material.SmallScale
                            onClicked: {
                                hostsView.currentIndex = index;
                                delegate.connectToHost();
                            }

                            GamepadHint {
                                anchors {
                                    left: parent.left
                                    leftMargin: 14
                                    verticalCenter: parent.verticalCenter
                                }
                                glyph: root.controllerButton("cross")
                                visible: consolePane.showGamepadHints && delegate.highlighted
                            }
                        }

                        CardAction {
                            icon.source: "qrc:/icons/a2p-power.svg"
                            tip: qsTr("Wake Up")
                            hint: root.controllerButton("pyramid")
                            cardHighlighted: delegate.highlighted
                            visible: !!(delegate.host.registered && !delegate.host.duid && !delegate.host.discovered)
                            onClicked: delegate.wakeUpHost()
                        }

                        CardAction {
                            icon.source: "qrc:/icons/a2p-key.svg"
                            tip: qsTr("Update Console Pin")
                            hint: "qrc:/icons/l1.svg"
                            cardHighlighted: delegate.highlighted
                            visible: !!delegate.host.registered
                            onClicked: delegate.setConsolePin()
                        }

                        CardAction {
                            icon.source: delegate.host.manual ? "qrc:/icons/a2p-trash.svg" : "qrc:/icons/a2p-eye-off.svg"
                            tip: delegate.host.manual ? qsTr("Delete") : qsTr("Hide")
                            hint: root.controllerButton("box")
                            cardHighlighted: delegate.highlighted
                            visible: !!(delegate.host.manual || (delegate.host.discovered && !delegate.host.registered))
                            onClicked: delegate.deleteHost()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: statusBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 44
        color: consolePane.theme.statusBar

        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 1
            color: consolePane.theme.border
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 16
            }
            spacing: 18

            Switch {
                id: discoverySwitch
                text: qsTr("Network discovery")
                font.pixelSize: 12
                topInset: 0
                bottomInset: 0
                focusPolicy: Qt.NoFocus
                checked: Chiaki.discoveryEnabled
                onToggled: {
                    Chiaki.discoveryEnabled = checked;
                    checked = Qt.binding(() => Chiaki.discoveryEnabled);
                }
            }

            RowLayout {
                spacing: 6

                Rectangle {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: Chiaki.settings.psnAuthToken ? consolePane.theme.success : consolePane.theme.textMuted
                }

                Label {
                    text: Chiaki.settings.psnAuthToken ? qsTr("PSN linked") : qsTr("PSN not linked")
                    font.pixelSize: 12
                    color: consolePane.theme.textMuted
                }
            }

            Item { Layout.fillWidth: true }

            Label {
                text: Qt.application.version
                font.pixelSize: 12
                color: consolePane.theme.textMuted
            }
        }
    }
}
