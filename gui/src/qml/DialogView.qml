import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

Item {
    id: dialog
    property alias header: headerLabel.text
    property alias title: titleLabel.text
    property alias buttonText: okButton.text
    property alias buttonEnabled: okButton.enabled
    property alias buttonVisible: okButton.visible
    property Item restoreFocusItem
    default property Item mainItem: null

    signal accepted()
    signal rejected()

    function close() {
        root.closeDialog();
    }

    Keys.onEscapePressed: close()

    Keys.onMenuPressed: {
        if (okButton.enabled)
            okButton.clicked()
    }

    StackView.onDeactivating: {
        restoreFocusItem = Window.window.activeFocusItem;
    }

    StackView.onActivated: {
        if (!restoreFocusItem) {
            let item = mainItem.nextItemInFocusChain();
            if (item)
                item.forceActiveFocus(Qt.TabFocusReason);
        } else {
            restoreFocusItem.forceActiveFocus(Qt.TabFocusReason);
            restoreFocusItem = null;
        }
    }

    onMainItemChanged: {
        if (mainItem) {
            mainItem.parent = contentItem;
            mainItem.anchors.fill = contentItem;
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
                leftMargin: 6
                rightMargin: 12
            }
            spacing: 8

            ToolButton {
                icon.source: "qrc:/icons/a2p-back.svg"
                display: AbstractButton.IconOnly
                focusPolicy: Qt.NoFocus
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: qsTr("Back")
                onClicked: {
                    dialog.rejected();
                    dialog.close();
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    id: titleLabel
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Label {
                    id: headerLabel
                    Layout.fillWidth: true
                    visible: text !== ""
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: root.theme.textMuted
                }
            }

            Button {
                id: okButton
                highlighted: true
                font.pixelSize: 14
                focusPolicy: Qt.NoFocus
                Material.roundedScale: Material.SmallScale
                onClicked: dialog.accepted()
                icon.source: "qrc:/icons/options.svg";
                icon.width: 22
                icon.height: 22
            }
        }
    }

    Item {
        id: contentItem
        anchors {
            top: toolBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
    }
}
